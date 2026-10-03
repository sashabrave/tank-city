extends Node
var failures=0
var checks=0
var arena
func check(ok,message):
	checks+=1
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1;push_error("FAIL: "+message)
func _ready():call_deferred("run")
func empty_arena():
	if is_instance_valid(arena):arena.free()
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat";arena.spawn_queue.clear()
	for wall in arena.walls.values():wall.node.free()
	# Random floor patches (water, forest) and generators must not block the ability cells.
	arena.walls.clear();arena.trenches.clear();arena.terrain.patches.clear();arena.generators.clear();arena.navigation.reset()
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;Game.health_level=0;Game.damage_level=0;Game.base_level=0;Game.mobility_level=0
	# 0.7 waves are seeded squads (SquadCatalog): exact size, kind caps, tanks only from field 5, drones never in
	# waves (they come from the background cooldown), ranks follow the world.
	var valid=true;var species={};var ranks={};var samples=0;var enemies=0;var squads={}
	for world in range(1,4):
		Campaign.configure(world)
		for room in range(6):
			for wave in range(3):
				for seed_value in range(100):
					var entries=WaveDirector.build(seed_value,room,wave);var counts={}
					valid=valid and entries==WaveDirector.build(seed_value,room,wave) and entries.size()==WaveDirector.wave_size(room,wave)
					for entry in entries:
						var type="rpg" if entry.weapon=="rpg" else entry.kind
						counts[type]=int(counts.get(type,0))+1;species[entry.kind]=true;ranks[entry.rank]=true;squads[entry.squad]=true
						valid=valid and entry.rank==world and entry.kind in WaveDirector.PEOPLE+WaveDirector.MACHINES
					for type in counts:valid=valid and counts[type]<=int(SquadCatalog.CAPS.get(type,99))
					valid=valid and counts.has("tank")==WaveDirector.tanks_in_wave(room,wave)
					samples+=1;enemies+=entries.size()
	Campaign.configure(1)
	check(valid and species.size()==8 and ranks.size()==3 and squads.size()==SquadCatalog.SQUADS.size(),"5400 seeded squad waves: sizes, caps, tank pacing, all kinds, squads and world ranks")
	print("WAVES samples=%d mean_count=%.2f squads=%d" % [samples,float(enemies)/samples,squads.size()])
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
	# Barrier efficiency raises the limit of standing blocks: the first one is no longer recycled.
	check(arena.abilities.cast() and arena.walls.has(Vector2i(5,4)) and arena.walls.has(Vector2i(7,4)),"upgraded barrier keeps two blocks")
	var drone=arena.spawn_actor("drone",Vector2i(0,0),false);arena.add_barrier(Vector2i(0,1),12);arena.drone_step(drone)
	check(drone.dead and arena.walls[Vector2i(0,1)].hp==9,"kamikaze detonates on barrier")
	empty_arena();arena.abilities.selected="laser";arena.player.cell=Vector2i(5,8);arena.player.position=arena.world_pos(arena.player.cell);arena.player.facing=Vector2i.UP
	arena.add_wall(Vector2i(5,6),-1);arena.add_wall(Vector2i(5,3),-1)
	var first=arena.spawn_actor("soldier",Vector2i(5,5),false);var second=arena.spawn_actor("soldier",Vector2i(5,2),false)
	arena.abilities.cast();check(first.dead and not second.dead,"laser passes one concrete and stops at second")
	arena.abilities.upgrade("utility",0);arena.abilities.cooldown=0;arena.abilities.cast();check(second.dead,"laser upgrade extends concrete penetration")
	empty_arena();arena.abilities.selected="grenade"
	# The grenade is thrown 5 cells ahead of the hero and bounces; radius from combat.tres.
	var p=arena.player;var ahead=p.position+Vector3(p.facing.x,0,p.facing.y)*5
	check(arena.abilities.cast() and arena.grenades.back().target==ahead and is_equal_approx(arena.grenades.back().blast_radius,Balance.CONFIG.combat.grenade_radius),"grenade lands five cells ahead with the tuned radius")
	var hp=arena.player.hp;arena.player.invulnerable=0;arena.grenade_explosion(arena.player.position,4,true,2.5);check(is_equal_approx(arena.player.hp,hp-1.0),"own grenade bites the soldier for 1, not its full damage (T-026)")
	# The mechanic upgrades the player's vehicle: here the APC waiting for the next room.
	arena.pending_vehicle="apc"
	var service=load("res://scripts/service_room.gd").new();service.arena=arena;service.branch="vehicle";service.index=4;add_child(service)
	service.claim(1);var added=arena.vehicle_mods.apc.hp;service.claim(1)
	check(added>0 and arena.vehicle_mods.apc.hp==added and arena.pending_vehicle=="apc","mechanic reward and vehicle issued once")
	arena.begin_room(4);check(arena.player.kind=="apc" and is_equal_approx(arena.player.max_hp,GarageCatalog.stats("apc").hp+added),"upgraded vehicle carries into next room")
	# The instructor improves an equipped ability; without one there are no cards.
	arena.abilities.slots=["laser"];arena.abilities.select("laser")
	var general=load("res://scripts/service_room.gd").new();general.arena=arena;general.branch="ability";general.index=6;add_child(general)
	general.avatar.position=Vector3(0,0,0);general.interact();check(is_instance_valid(general.modal) and general.offers.size()==3,"salute opens three ability cards")
	general.claim(0);check(arena.abilities.level.power>0,"general improves selected run ability")
	arena.begin_room(5);check(not arena.boss_room and arena.grid_size==(Campaign.SIZES.max() if arena.room.mode=="maze" else Campaign.SIZES[5]),"sixth regular room (a maze challenge uses the largest field)")
	arena.begin_room(6);check(arena.boss_room and arena.grid_size==Campaign.SIZES[6] and arena.spawn_queue.size()==BossCatalog.encounter(arena.run_seed,6).count and arena.spawn_queue.all(func(k):return k=="boss"),"seventh stage is final boss (one or two by variant)")
	# WASD now drives the map rover (command_rover) and world 1 services are route nodes, so only the drag stays here.
	var route=load("res://scripts/route_map.gd").new();route.available=2;add_child(route);var before=route.scroll
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;route._unhandled_input(press)
	var motion=InputEventMouseMotion.new();motion.relative=Vector2(0,80);before=route.scroll;route._unhandled_input(motion)
	check(route.scroll>before,"map mouse drag scrolls")
	var main=load("res://scripts/main.gd").new();add_child(main);main.start_run();main.enter_room(0)
	main.show_map(2);check(main.current.needs_service,"fork required after room two")
	main.enter_room(2);check(main.current.get_script().resource_path.ends_with("route_map.gd"),"cannot bypass fork")
	main.show_service("vehicle",2);main.current.claim(0);main.current.completed.emit(2)
	check(main.run_arena.visited_services.get(2)=="vehicle" and not main.current.needs_service,"chosen branch resolves exactly once")
	# Stage 2 may also hold a route service or challenge node: enter an ordinary battle lane explicitly.
	var plan=RoutePlan.build(main.run_arena.run_seed)
	var lanes=[]
	for node in plan[1]:
		if not lanes.is_empty():break
		main.route_choices[1]=node.id
		lanes=RoutePlan.reachable(plan,2,main.route_choices,"vehicle").filter(func(id):return RoutePlan.node_branch(RoutePlan.chosen(plan,2,{2:id}))=="")
	main.enter_room(2,lanes[0] if not lanes.is_empty() else "")
	check("room_index" in main.current and main.current.room_index==2 and main.current.player.kind=="buggy","map returns to combat with mechanic vehicle")
	# Gadgets: the weapons workshop sells barrier/mine/laser/airstrike once an ability is unlocked.
	Game.built_workshops.append("weapons");Game.ability_unlocks=["laser"];Game.purchased_gadgets.clear();Game.selected_ability="";Game.credits=Game.gadget_cost("laser")+40
	check(not Game.unlock_or_equip_ability("grenade"),"grenade is not a gadget")
	check(Game.unlock_or_equip_ability("laser") and Game.credits==40 and Game.selected_ability=="laser","gadget purchase spends price")
	Game.unlock_or_equip_ability("laser");check(Game.credits==40,"re-equipping is free")
	print("V06: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
