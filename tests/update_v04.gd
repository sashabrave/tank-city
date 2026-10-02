extends Node
var failures=0
var checks=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat"
	for wall in arena.walls.values():wall.node.queue_free()
	arena.walls.clear();arena.trenches.clear()
	arena.add_trench(Vector2i(3,3))
	check(not arena.can_enter(Vector2i(3,3),arena.player),"trench blocks player")
	var enemy=arena.spawn_actor("soldier",Vector2i(3,2),false)
	check(arena.can_enter(Vector2i(3,3),enemy),"infantry special entry")
	enemy.cell=Vector2i(3,3);enemy.position=arena.world_pos(enemy.cell);enemy._physics_process(.1)
	var hp=enemy.hp;enemy.take_damage(99);check(enemy.hp==hp,"hidden infantry protected")
	enemy._physics_process(2);enemy.take_damage(1);check(enemy.hp<hp,"exposed infantry vulnerable")
	arena.actors.erase(enemy);enemy.queue_free()
	var buggy=arena.spawn_actor("buggy",Vector2i(arena.base_cell.x,arena.grid_size-2),false)
	buggy.facing=Vector2i.LEFT;buggy.fire_cooldown=0;buggy.route_points.clear()
	for i in range(20):buggy._physics_process(.1)
	for bullet in arena.projectiles.duplicate():
		for i in range(40):
			if not bullet.spent:bullet._physics_process(.02)
	check(arena.base_hp<arena.base_max_hp,"buggy damages base")
	arena.actors.erase(buggy);buggy.queue_free()
	var tank=arena.spawn_actor("tank",Vector2i(1,7),true)
	var first=arena.spawn_actor("soldier",Vector2i(1,5),false)
	var second=arena.spawn_actor("apc",Vector2i(1,3),false)
	arena.spawn_bullet(tank,tank.position,Vector2i.UP,3,true)
	var shell=arena.projectiles.back()
	for i in range(60):
		if not shell.spent:shell._physics_process(.01)
	check(first.dead and second.hp==2,"shell pierces two targets once")
	var wreck=arena.make_wreck("tank",Vector2i(9,9),Vector2i.UP,false,9);wreck.start_delivery(2)
	check(not wreck.boardable,"delivery cannot be boarded in air")
	wreck._physics_process(2.1);check(wreck.boardable and is_zero_approx(wreck.position.y),"delivery lands")
	# Clear the room first: the pierced APC survives with 2 HP and the opening wave may still be queued.
	for actor in arena.actors.filter(func(a):return not a.player_owned and not a.allied):arena.actors.erase(actor);actor.queue_free()
	arena.spawn_queue.clear();arena.wave=2;arena.room_boss_spawned=true;arena.finish_wave();var credits=Game.credits
	check(arena.room_cleared and arena.phase=="combat","clear waits at flag")
	arena.open_flag();var offers=arena.upgrade_offers.duplicate(true);arena.return_to_field();arena.open_flag()
	check(offers==arena.upgrade_offers and Game.credits==credits,"reopen preserves offers and reward")
	arena.apply_upgrade("damage",2);arena.return_to_field();arena.open_flag()
	check(arena.reward_claimed and arena.room_index==0,"upgrade does not leave room")
	# Unified luck: the old rarity branch folded into luck_level.
	var old=Game.luck_level;Game.luck_level=0;check(Game.rarity_roll(.15)==1,"base rarity")
	Game.luck_level=20;check(Game.rarity_roll(.15)==2,"luck improves rarity");Game.luck_level=old
	var route=load("res://scripts/route_map.gd").new();add_child(route);check(route.camera!=null,"3D route loads")
	var main=load("res://scripts/main.gd").new();add_child(main)
	# World 1 may place a service on stage 1: start on a lane whose road leads to an ordinary battle.
	main.start_run();var plan=RoutePlan.build(Game.visual_run_seed);var start="";var battle=""
	for node in plan[0]:
		for id in node.next:
			if battle=="" and RoutePlan.node_branch(RoutePlan.chosen(plan,1,{1:id}))=="":start=node.id;battle=id
	main.enter_room(0,start)
	main.current.damage_bonus=7.0;main.current.soldier_hp=2
	main.show_map(1)
	main.enter_room(1,battle)
	check(main.current.room_index==1 and main.current.damage_bonus==7 and main.current.soldier_hp==2,"map preserves run state")
	print("V04: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
