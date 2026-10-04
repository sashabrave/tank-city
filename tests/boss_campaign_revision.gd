extends Node
var errors=0
func check(value:bool,message:String):
	if not value:errors+=1;push_error(message)
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame
# from challenge_hold_survive_revision: first route seed with a challenge room of this type.
func challenge_room(type:String):
	for candidate in range(1,400):
		var plan=RoutePlan.build(candidate)
		for stage in range(1,6):
			for n in plan[stage]:
				if n.type==type:
					var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=candidate;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
					arena.run.route_choices=RoutePlan.path_to(plan,n.stage,n.id);arena.begin_room(n.stage)
					return arena
	return null
func clear_enemies(arena):
	for actor in arena.room.actors:
		if is_instance_valid(actor) and not actor.player_owned:actor.dead=true
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	for world in [1,2,3]:
		Campaign.configure(world)
		for index in range(6):
			for seed_value in range(8):
				var rows=BattleMapGenerator.generate(seed_value,index).rows
				check(BattleMapGenerator.validate(rows),"Connected map")
				if world>=2:
					var cover=0;var width=rows.size()
					for y in range(int(width*.25),int(width*.75)):
						for x in range(int(width*.25),int(width*.75)):
							if rows[y][x] in ["B","C"]:cover+=1
					check(cover>=8,"Center cover: world %d field %d seed %d = %d" % [world,index,seed_value,cover])
		var variants={}
		for seed_value in range(3):variants[BossCatalog.encounter(seed_value,6).id]=true
		check(variants.size()==3,"Three boss variants in each world")
	Campaign.configure(3)
	check(Campaign.BOSSES==[6,7] and 7 in Campaign.SERVICES and not Campaign.is_final(6) and Campaign.is_final(7),"General, choice of service, then gigaboss")
	check(Campaign.service_options(42,7).size()==2,"Two final preparation options")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false);arena.begin_room(7);arena.phase="combat"
	for actor in arena.actors:actor.set_physics_process(false)
	arena.spawn_queue.clear();var boss=arena.spawn_actor("boss",Vector2i(15,1),false);boss.set_physics_process(false)
	check(not arena.boss.shield_active() and arena.generators.size()==4,"Starts vulnerable, four dormant generators")
	for i in range(4):
		boss.take_damage(99999)
		check(is_equal_approx(boss.hp,boss.max_hp*[.8,.6,.4,.2][i]),"Damage clamped to phase threshold")
		check(arena.boss.shield_active(),"One active shield")
		var active=arena.generators.keys().filter(func(cell):return arena.generators[cell].active)
		check(active.size()==1,"Only one active generator")
		var hp=boss.hp;boss.take_damage(999);check(boss.hp==hp,"Shield blocks damage")
		for cell in arena.generators.keys():
			if cell!=active[0]:arena.damage_generator(cell,999);check(arena.generators.has(cell),"Dormant generator cannot be skipped")
		arena.damage_generator(active[0],999);check(not arena.boss.shield_active(),"Generator destruction removes shield immediately")
		for actor in arena.actors:actor.set_physics_process(false)
	check(arena.actors.filter(func(a):return a.get_meta("generator_guard",false)).size()==8,"Two defenders per active position")
	boss.take_damage(99999);check(boss.dead,"Final HP can be depleted after four phases")
	arena.queue_free();await get_tree().process_frame
	# Regular world-1 boss: two flank generators at 60% and 30%, one guard each.
	Campaign.configure(1)
	arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false);arena.begin_room(Campaign.BOSSES[0]);arena.phase="combat"
	for actor in arena.actors:actor.set_physics_process(false)
	arena.spawn_queue.clear();boss=arena.spawn_actor("boss",Vector2i(9,1),false);boss.set_physics_process(false)
	check(arena.generators.size()==2 and not arena.boss.shield_active(),"Regular boss: two dormant generators")
	for i in range(2):
		boss.take_damage(99999);check(is_equal_approx(boss.hp,boss.max_hp*[.6,.3][i]) and arena.boss.shield_active(),"Regular boss shield at threshold")
		var live=arena.generators.keys().filter(func(cell):return arena.generators[cell].active)
		arena.damage_generator(live[0],999);check(not arena.boss.shield_active(),"Regular generator drops the shield")
		for actor in arena.actors:actor.set_physics_process(false)
	check(arena.actors.filter(func(a):return a.get_meta("generator_guard",false)).size()==2,"One guard per regular generator in world 1")
	boss.take_damage(99999);check(boss.dead,"Regular boss dies after two phases")
	arena.queue_free();await get_tree().process_frame
	# from chest_flag_revision (T-044): an unopened commander chest holds the exit flag back.
	arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=3;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(.8).timeout;arena.set_physics_process(false)
	arena.room.spawn_queue.clear()
	for a in arena.room.actors.duplicate():
		if is_instance_valid(a) and not a.player_owned:a.dead=true;arena.room.actors.erase(a);a.queue_free()
	arena.reward.drop_recipe(arena.player.cell+Vector2i(1,-2),{"elite":true})
	arena.room.wave=2;arena.room.room_boss_spawned=true;arena.phase="combat";arena.flow.finish_wave();await get_tree().process_frame
	check(not is_instance_valid(arena.room.flag) and arena.room.has_meta("pending_flag"),"no exit while the chest is unopened")
	var chests=arena.room.pickups.filter(func(p):return p.kind=="recipe_draft")
	check(not chests.is_empty(),"commander chest dropped")
	if not chests.is_empty():
		arena.reward.consume_chest(chests[0]);await get_tree().process_frame
		check(is_instance_valid(arena.room.flag) and not arena.room.has_meta("pending_flag"),"exit appears once the chest is done")
	arena.queue_free();await settle()
	# from challenge_ladder_revision: ladder I–III unlock order and effects, record on world clear, default step.
	var worlds=Game.progression.cleared_worlds.duplicate();var counters=Game.progression.counters.duplicate()
	Game.progression.cleared_worlds=[];check(Campaign.challenge_open(1)==0,"no ladder before the world is cleared")
	Game.progression.cleared_worlds=[1];Game.progression.counters.erase("challenge_w1")
	check(Campaign.challenge_open(1)==1,"clearing the world opens step I")
	Game.progression.counters["challenge_w1"]=1;check(Campaign.challenge_open(1)==2,"clearing I opens II")
	Campaign.configure(1);var base_skill=Professionalism.skill(0);var base_size=WaveDirector.wave_size(0,0)
	Campaign.challenge=2
	check(is_equal_approx(Professionalism.skill(0),base_skill+2*Campaign.CHALLENGE_SKILL),"each step adds professionalism")
	check(is_equal_approx(Campaign.reward_multiplier(),1.5),"step II pays +50%")
	Campaign.challenge=3;check(WaveDirector.wave_size(0,0)==base_size+1,"step III adds one enemy per wave")
	Game.progression.complete_world(1);check(int(Game.progression.counters.challenge_w1)==3,"clearing at III records it")
	Campaign.configure(1);check(Campaign.challenge==0,"configure starts at normal")
	Game.progression.counters["challenge_w1"]=1
	var picker=preload("res://scripts/ui/world_select.gd").new();add_child(picker)
	for i in 10:await get_tree().process_frame
	check(picker.challenge_for(1)==2,"the last open step is chosen by default")
	picker.queue_free()
	Game.progression.cleared_worlds=worlds;Game.progression.counters=counters;Campaign.configure(1)
	# from challenge_hold_survive_revision: hold zone rules and the survive barrage.
	Game.reset_upgrades();Campaign.configure(1)
	check(RoutePlan.CHALLENGES.has("hold") and RoutePlan.CHALLENGES.has("survive"),"hold and survive on the route")
	arena=challenge_room("hold");await settle()
	var rooms=arena.challenges
	check(arena.room.mode=="hold" and is_instance_valid(rooms.zone) and not arena.room.spawn_queue.is_empty(),"hold room: zone and enemies")
	check(rooms.blocks_waves() and not arena.room.room_cleared,"empty queue does not end the hold room")
	arena.room.spawn_queue.clear();clear_enemies(arena)
	arena.player.position=rooms.zone.position
	rooms.tick(5.0);check(is_equal_approx(rooms.progress,5.0),"progress grows in the zone")
	var intruder=arena.spawn_actor("soldier",arena.grid_pos(rooms.zone.position)+Vector2i(1,0),false);intruder.position=rooms.zone.position+Vector3(.6,0,0)
	rooms.tick(5.0);check(is_equal_approx(rooms.progress,5.0),"an enemy in the zone stops progress")
	intruder.dead=true
	arena.player.position=rooms.zone.position+Vector3(6,0,0)
	rooms.tick(4.0);check(is_equal_approx(rooms.progress,4.0),"progress slowly falls outside")
	arena.player.position=rooms.zone.position
	for i in range(80):
		arena.room.spawn_queue.clear();clear_enemies(arena);rooms.tick(1.0)
	check(rooms.rewarded and arena.room.room_cleared and is_instance_valid(arena.room.flag),"held zone opens the exit")
	check(arena.room.pickups.any(func(p):return p.kind=="recipe_draft" and p.offers.size()==3),"hold reward chest")
	arena.queue_free();await settle()
	arena=challenge_room("survive");await settle();rooms=arena.challenges
	check(arena.room.mode=="survive" and not rooms.weapons_locked(),"survive: shooting allowed under fire (T-118)")
	rooms.tick(.8);rooms.tick(.8);check(rooms.shells.size()>=1,"artillery marks the field")
	if not rooms.shells.is_empty():
		var shell=rooms.shells[0];shell.node.position=arena.player.position;var soldier_hp=arena.player.hp;arena.player.invulnerable=0
		rooms.explode_shell(shell)
		check(arena.player.hp<soldier_hp,"a shell hits the soldier")
	for i in range(60):rooms.tick(1.0)
	check(rooms.rewarded and rooms.shells.is_empty(),"timer ends the barrage")
	arena.queue_free();await settle()
	# from maze_revision: the maze goal flag is reachable on foot through the real board.
	arena=load("res://scenes/arena.tscn").instantiate();arena.sandbox=true;arena.sandbox_mode="maze";arena.sandbox_difficulty=1;arena.run_seed=11;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.2).timeout
	var goal=arena.challenges.goal_flag
	check(is_instance_valid(goal),"maze: green flag placed")
	if is_instance_valid(goal):
		var start=arena.grid_pos(arena.room.player.position);var target=arena.grid_pos(goal.position)
		var seen={start:true};var queue=[start]
		while not queue.is_empty():
			var at=queue.pop_front()
			for d in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
				var to=at+d
				if seen.has(to) or not arena.inside(to) or arena.walls.has(to) or arena.terrain.movement_blocked_at_cell(to) or arena.room.trenches.has(to):continue
				seen[to]=true;queue.append(to)
		check(seen.has(target),"maze: the flag is reachable on foot")
	arena.queue_free();await settle()
	print("BOSS/CAMPAIGN/MAPS failures: ",errors);get_tree().quit(1 if errors else 0)
