extends Node
var failures=0
var checks=0
var arena
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
func _ready():call_deferred("run")
func empty_arena():
	if is_instance_valid(arena):arena.free()
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat";arena.spawn_queue.clear()
	for wall in arena.walls.values():wall.node.free()
	arena.walls.clear();arena.trenches.clear()
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.health_level=0;Game.damage_level=0;Game.base_level=0;Game.mobility_level=0
	var valid=true;var species={};var veterans=0;var samples=0;var enemies=0;var drone_waves=0
	for room in range(6):
		for wave in range(3):
			for seed_value in range(100):
				var entries=WaveDirector.build(seed_value,room,wave);var budget=0;var drones=0;var artillery=0
				valid=valid and entries==WaveDirector.build(seed_value,room,wave) and entries.size()<=8 and entries.size()>0
				for entry in entries:
					budget+=WaveDirector.rank_cost(entry.kind,entry.rank);species[entry.kind]=true
					if entry.rank==2:veterans+=1
					if entry.kind in ["drone","flyer"]:drones+=1
					if entry.kind in ["sniper","mortar"]:artillery+=1
				valid=valid and entries.size()==WaveDirector.wave_size(room,wave) and drones<=2 and artillery<=2
				samples+=1;enemies+=entries.size()
				if drones>0:drone_waves+=1
	check(valid and species.size()==10 and veterans>0,"1800 seeded waves: threat budgets, diversity, caps and veterans")
	print("WAVES samples=%d mean_count=%.2f drone_waves=%.1f%% veterans=%d" % [samples,float(enemies)/samples,100.0*drone_waves/samples,veterans])
	var maps=true
	for seed_value in range(100):maps=maps and BattleMapGenerator.validate(BattleMapGenerator.generate(seed_value,5).rows)
	check(maps,"sixth room maps stay connected")
	empty_arena()
	var veteran=arena.spawn_actor("soldier",Vector2i(0,0),false,false,2)
	check(is_equal_approx(veteran.hp,3.2) and is_equal_approx(veteran.damage,1.3) and veteran.health_label.rank==2,"rank two coefficients and chevrons")
	veteran._physics_process(.01);check(is_equal_approx(veteran.max_hp,3.2),"rank is applied only once")
	var flyer=arena.spawn_actor("flyer",Vector2i(2,2),false)
	var turret=arena.spawn_actor("mortar",Vector2i(10,10),false,true)
	check(arena.flyer_target(flyer)==turret,"flyer prioritizes turret over infantry")
	flyer.flight_state="travel";flyer.flight_target=arena.world_pos(Vector2i(4,2));arena.add_wall(Vector2i(3,2),-1)
	arena.flyer_step(flyer,1);check(flyer.cell==Vector2i(4,2),"flyer crosses concrete in a straight flight")
	flyer.flight_state="burst";flyer.flight_shots=0;flyer.flight_timer=0;var count=arena.projectiles.size()
	arena.flyer_step(flyer,.31)
	check(arena.projectiles.size()==count+1 and flyer.flight_state=="rest","flyer fires one large bullet before repositioning")
	empty_arena();arena.abilities.selected="barrier";arena.player.cell=Vector2i(5,5);arena.player.position=arena.world_pos(arena.player.cell);arena.player.facing=Vector2i.UP
	check(arena.abilities.cast() and arena.walls[Vector2i(5,4)].hp==12,"barrier has four bricks of health")
	check(not arena.abilities.cast(),"ability cooldown rejects repeats")
	arena.abilities.upgrade("utility",0);arena.abilities.cooldown=0;arena.player.cell=Vector2i(7,5);arena.player.position=arena.world_pos(arena.player.cell)
	check(arena.abilities.cast() and arena.walls.has(Vector2i(7,3)) and arena.walls.has(Vector2i(7,4)),"upgraded barrier places two blocks")
	var drone=arena.spawn_actor("drone",Vector2i(0,0),false);arena.add_barrier(Vector2i(0,1),12);arena.drone_step(drone)
	check(drone.dead and arena.walls[Vector2i(0,1)].hp==9,"kamikaze detonates on barrier")
	empty_arena();arena.abilities.selected="laser";arena.player.cell=Vector2i(5,8);arena.player.position=arena.world_pos(arena.player.cell);arena.player.facing=Vector2i.UP
	arena.add_wall(Vector2i(5,6),-1);arena.add_wall(Vector2i(5,3),-1)
	var first=arena.spawn_actor("soldier",Vector2i(5,5),false);var second=arena.spawn_actor("soldier",Vector2i(5,2),false)
	arena.abilities.cast();check(first.dead and not second.dead,"laser passes one concrete and stops at second")
	arena.abilities.upgrade("utility",0);arena.abilities.cooldown=0;arena.abilities.cast();check(second.dead,"laser upgrade extends concrete penetration")
	empty_arena();arena.abilities.selected="grenade"
	var near=arena.spawn_actor("soldier",Vector2i(5,6),false);var far=arena.spawn_actor("soldier",Vector2i(0,0),false)
	check(arena.abilities.cast() and arena.grenades.back().target==far.position and arena.grenades.back().blast_radius==2.5,"grenade selects farthest enemy with 2.5 radius")
	var hp=arena.player.hp;arena.grenade_explosion(arena.player.position,4,true,2.5);check(arena.player.hp==hp,"ability grenade never damages player")
	var service=load("res://scripts/service_room.gd").new();service.arena=arena;service.branch="vehicle";service.index=4;add_child(service)
	service.claim(1);var added=arena.vehicle_mods.apc.hp;service.claim(1)
	check(added>0 and arena.vehicle_mods.apc.hp==added and arena.pending_vehicle=="apc","mechanic reward and vehicle issued once")
	arena.begin_room(4);check(arena.player.kind=="apc" and arena.player.max_hp==5+added,"upgraded vehicle carries into next room")
	var general=load("res://scripts/service_room.gd").new();general.arena=arena;general.branch="ability";general.index=6;add_child(general)
	general.avatar.position=Vector3(0,0,0);general.interact();check(is_instance_valid(general.modal) and general.offers.size()==3,"salute opens three ability cards")
	general.claim(0);check(arena.abilities.level.power>0,"general improves selected run ability")
	arena.begin_room(5);check(not arena.boss_room and arena.grid_size==20,"sixth regular room")
	arena.begin_room(6);check(arena.boss_room and arena.grid_size==21 and arena.spawn_queue==["boss"],"seventh stage is final boss")
	var route=load("res://scripts/route_map.gd").new();route.available=2;route.needs_service=true;route.ability_available=true;add_child(route)
	var before=route.scroll;Input.action_press("north");route._process(.5);Input.action_release("north");check(route.scroll>before,"map W scroll")
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;route._unhandled_input(press)
	var motion=InputEventMouseMotion.new();motion.relative=Vector2(0,80);before=route.scroll;route._unhandled_input(motion)
	check(route.scroll>before and route.fork_positions.size()==2,"map mouse drag and two fork miniatures")
	var main=load("res://scripts/main.gd").new();add_child(main);main.start_run();main.enter_room(0)
	main.show_map(2);check(main.current.needs_service,"fork required after room two")
	main.enter_room(2);check(main.current.get_script().resource_path.ends_with("route_map.gd"),"cannot bypass fork")
	main.show_service("vehicle",2);main.current.claim(0);main.current.completed.emit(2)
	check(main.run_arena.visited_services.get(2)=="vehicle" and not main.current.needs_service,"chosen branch resolves exactly once")
	main.enter_room(2);check(main.current.room_index==2 and main.current.player.kind=="buggy","map returns to combat with mechanic vehicle")
	Game.ability_unlocks=[];Game.selected_ability="";Game.credits=200
	check(Game.unlock_or_equip_ability("grenade") and Game.credits==40,"ability unlock spends price")
	Game.unlock_or_equip_ability("grenade");check(Game.credits==40,"re-equipping is free")
	print("V06: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
