extends Node
var checks=0
var failures=0
func check(ok,msg):
	checks+=1
	if not ok:push_error(msg);failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var policy=load("res://scripts/recipe_extraction.gd");var rng=RandomNumberGenerator.new();rng.seed=420
	var recipes=[{"category":"weapon","id":"smg"}]  # building blueprints always survive (0.8), weapons follow the rescue rules
	check(policy.survivors(recipes,false,0,rng).is_empty(),"zero rescue loses on escape")
	check(policy.survivors(recipes,true,0,rng).size()==1,"safe extraction saves")
	var saved=0
	for i in range(10000):saved+=policy.survivors(recipes,false,10,rng).size()
	check(saved>5700 and saved<6300,"60 percent independent chance")
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat";arena.player.set_physics_process(false)
	# Voluntary extraction banks the whole backpack now (0.8): only the «safe» case is integrated here.
	arena.room_cleared=true;arena.pending_recipes=recipes.duplicate(true);arena.resolve_recipes_on_return();check("smg" in Game.weapon_unlocks,"safe integration")
	arena.summon_comrade(.5,0)
	var buddy=arena.actors.back();buddy.set_physics_process(false)
	check(buddy.companion and buddy.allied and buddy.max_hp==maxf(1,arena.soldier_max_hp*.5),"companion half HP")
	check(buddy.companion_weapon in arena.LOOT.WEAPONS,"random valid gun")
	arena.comrade_step(buddy,3.1);check(buddy.parachute_left==0 and buddy.model.position.y==0,"parachute lands")
	arena.fire_comrade_weapon(buddy);check(not arena.projectiles.is_empty(),"companion fires")
	# T-167: the nearest enemy is diagonal (no shot), another one stands in line — the comrade shoots that one.
	for actor in arena.actors.duplicate():
		if actor!=buddy and actor!=arena.player and not actor.allied:arena.actors.erase(actor);actor.queue_free()
	arena.projectiles.clear();buddy.fire_cooldown=0;buddy.brain_cooldown=0;buddy.moving=false
	var near=arena.spawn_actor("soldier",buddy.cell+Vector2i(1,1),false);near.set_physics_process(false)
	var lined=null
	for dir in [Vector2i(0,-3),Vector2i(0,3),Vector2i(3,0),Vector2i(-3,0)]:
		var c=buddy.cell+dir
		if arena.can_enter(c,near) and arena.clear_line(buddy.cell,c):lined=arena.spawn_actor("soldier",c,false);break
	if lined:
		lined.set_physics_process(false)
		arena.comrade_step(buddy,.05)
		check(buddy.fire_cooldown>0 and buddy.facing==arena.aligned_direction(buddy.cell,lined.cell),"comrade shoots a lined-up enemy, not only the nearest one")
	arena.queue_free();await get_tree().process_frame
	print("STABILITY09: ",checks," checks, ",failures," failures; rescue ",saved," / 10000")
	get_tree().quit(1 if failures else 0)
