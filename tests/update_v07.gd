extends Node
var checks=0
var failures=0
var arena
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var rng=RandomNumberGenerator.new();rng.seed=77
	var pending=[];Game.backpack_slots=6;Game.built_workshops=Game.BUILD_COST.keys()
	for i in range(200):Game.discover_recipe(rng,pending)
	check(pending.size()==Backpack.capacity(),"the backpack fills without duplicate recipes")
	check(Game.weapon_unlocks==["pistol"] and Game.bonus_unlocks==["heart"],"carried recipes do not unlock anything")
	Game.bank_recipes(pending)
	check(pending.is_empty() and "character" in Game.research_unlocks,"safe banking opens collection")
	Game.bonus_unlocks=Game.LOOT.BONUSES.keys()
	check(Game.star_chance(0)==0 and is_equal_approx(Game.star_chance(1),.006) and is_equal_approx(Game.star_chance(2),.015),"star only late waves and more likely in third")
	Game.credits=1000
	for i in range(3):Game.upgrade_bonus("star")
	check(is_equal_approx(Game.star_duration(),10.5) and is_equal_approx(Game.star_chance(2),.024),"star levels improve duration and chance slowly")
	check(not Game.upgrade_bonus("star"),"star maximum three upgrades")
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat";arena.spawn_queue.clear()
	arena.drop_pickup(Vector2i.ZERO,"star");arena.collect_pickup(arena.pickups.back())
	check(is_equal_approx(arena.star_time,10.5),"star pickup activates timer")
	var hp=arena.player.hp;arena.player.invulnerable=0;arena.player.take_damage(100)
	check(arena.player.hp==hp and not arena.player.dead,"star blocks damage")
	arena.phase="paused";arena._physics_process(2)
	check(is_equal_approx(arena.star_time,10.5),"pause freezes star")
	arena.phase="combat";arena._physics_process(.5)
	check(is_equal_approx(arena.star_time,10.0),"star ticks during combat")
	for item in arena.walls.values():item.node.queue_free()
	arena.walls.clear();arena.trenches.clear()
	var target=arena.spawn_actor("shield",Vector2i(2,2),false);target.shield_phase="active";target.max_hp=1000;target.hp=1000
	arena.spawn_bullet(arena.player,arena.player.position,Vector2i.UP,1,true)
	var bullet=arena.projectiles.back();bullet.position=target.position
	check(bullet.star_power,"star applies to player projectile at firing time")
	arena.bullet_hit(bullet)
	check(target.dead,"star one-shots armored high HP enemy through shield")
	var cell=Vector2i(3,3);arena.add_wall(cell,-1);bullet.position=arena.world_pos(cell)
	arena.bullet_hit(bullet);check(not arena.walls.has(cell),"star destroys concrete")
	arena.star_time=0;arena.add_wall(cell,-1);arena.spawn_bullet(arena.player,arena.player.position,Vector2i.UP,1,true)
	var ordinary=arena.projectiles.back();ordinary.position=arena.world_pos(cell);arena.bullet_hit(ordinary)
	check(arena.walls.has(cell),"ordinary bullets still cannot destroy concrete")
	arena.player.invulnerable=0;arena.player.take_damage(1)
	check(arena.player.hp==hp-1,"damage returns after star expires")
	Game.weapon_unlocks=["rifle"];arena.pending_recipes=[{"id":"sniper","category":"weapon"}]
	arena.hud.show_pause()
	check(arena.recipe_summary().contains("Снайперка") and not arena.can_extract_recipes(),"pause lists carried recipe before safe extraction")
	arena.resolve_recipes_on_return()
	check(arena.pending_recipes.is_empty() and "sniper" in Game.weapon_unlocks,"voluntary retreat midbattle banks recipes")
	arena.pending_recipes=[{"id":"heavy","category":"weapon"}];arena.room_cleared=true
	check(arena.can_extract_recipes(),"cleared room allows safe extraction")
	arena.run.lost_run=true;check(not arena.can_extract_recipes(),"lost run blocks extraction")
	arena.resolve_recipes_on_return();arena.run.lost_run=false
	check(arena.pending_recipes.is_empty() and "heavy" not in Game.weapon_unlocks,"lost run loses recipes on return")
	arena.pending_recipes=[{"id":"smg","category":"weapon"}];arena.finish_run(false,"test")
	check(arena.pending_recipes.is_empty() and "smg" not in Game.weapon_unlocks,"death loses pending recipe even after earlier room")
	var original_path=Game.save_path;Game.save_path="/private/tmp/tank-v07-%d/profile.json" % Time.get_ticks_usec();Game.profiles.selected=true;Game.save_blocked=false;Game.save_enabled=true
	Game.bonus_unlocks=["heart"];arena.pending_recipes=[{"id":"star","category":"bonus"}];Game.save_progress();Game.load_progress()
	check("star" not in Game.bonus_unlocks,"ordinary saves do not bank backpack")
	arena.phase="combat";arena.lost_run=false;arena.room_cleared=true;arena.resolve_recipes_on_return();Game.bonus_unlocks=["heart"];Game.load_progress()
	check("star" in Game.bonus_unlocks and Game.bonus_level("star")==3,"banked star recipe and levels persist")
	Game.save_enabled=false;Game.save_path=original_path
	Game.bonus_unlocks=["heart"]
	check(Game.star_chance(2)==0,"star recipe required for drop")
	var icons_valid=true
	for id in ["heart","repair","wall","vehicle_repair","turret","vehicle","star","barrier","grenade","laser","recipe","alloy","rifle","smg","heavy"]:
		var icon=Image.load_from_file("res://assets/icons/v1/"+id+".png")
		icons_valid=icons_valid and icon!=null and icon.get_width()>=512 and icon.detect_alpha()!=Image.ALPHA_NONE
	check(icons_valid,"fifteen original PNG icons have usable size and true alpha")
	print("V07: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
