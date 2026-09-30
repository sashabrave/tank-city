extends Node
var checks=0
func check(ok,msg):
	checks+=1
	if not ok:push_error(msg);get_tree().quit(1)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var policy=load("res://scripts/recipe_extraction.gd");var rng=RandomNumberGenerator.new();rng.seed=420
	var recipes=[{"category":"research","id":"rescue"}]
	check(policy.survivors(recipes,false,0,rng).is_empty(),"zero rescue loses on escape")
	check(policy.survivors(recipes,true,0,rng).size()==1,"safe extraction saves")
	var saved=0
	for i in range(10000):saved+=policy.survivors(recipes,false,10,rng).size()
	check(saved>5700 and saved<6300,"60 percent independent chance")
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat";arena.player.set_physics_process(false)
	arena.pending_recipes=recipes.duplicate(true);arena.resolve_recipes_on_return();check(not "rescue" in Game.research_unlocks,"escape integration")
	arena.room_cleared=true;arena.pending_recipes=recipes.duplicate(true);arena.resolve_recipes_on_return();check("rescue" in Game.research_unlocks,"safe integration")
	arena.summon_comrade(.5,0)
	var buddy=arena.actors.back();buddy.set_physics_process(false)
	check(buddy.companion and buddy.allied and buddy.max_hp==maxf(1,arena.soldier_max_hp*.5),"companion half HP")
	check(buddy.companion_weapon in arena.LOOT.WEAPONS,"random valid gun")
	arena.comrade_step(buddy,3.1);check(buddy.parachute_left==0 and buddy.model.position.y==0,"parachute lands")
	arena.fire_comrade_weapon(buddy);check(not arena.projectiles.is_empty(),"companion fires")
	for actor in arena.actors:check(not actor.model.has_method("kick"),"legacy models active")
	arena.queue_free();await get_tree().process_frame
	print("STABILITY09: ",checks," checks; rescue ",saved," / 10000")
	get_tree().quit()
