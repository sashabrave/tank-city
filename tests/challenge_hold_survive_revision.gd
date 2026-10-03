extends Node3D
# Hold and survive challenges: own finishing rules, zone progress, locked weapons and artillery.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame
func find(type:String)->Array:
	for candidate in range(1,400):
		var plan=RoutePlan.build(candidate)
		for stage in range(1,6):
			for n in plan[stage]:
				if n.type==type:return [candidate,plan,n]
	return []
func room(type:String):
	var found=find(type)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=found[0];add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	arena.run.route_choices=RoutePlan.path_to(found[1],found[2].stage,found[2].id);arena.begin_room(found[2].stage)
	return arena
func clear_enemies(arena):
	for actor in arena.room.actors:
		if is_instance_valid(actor) and not actor.player_owned:actor.dead=true
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	check(RoutePlan.CHALLENGES.has("hold") and RoutePlan.CHALLENGES.has("survive"),"hold and survive on the route")
	var arena=room("hold");await settle()
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
	check(rooms.status().ends_with("готово"),"status shows completion")
	arena.queue_free();await settle()
	arena=room("survive");await settle();rooms=arena.challenges
	check(arena.room.mode=="survive" and not rooms.weapons_locked(),"survive: shooting allowed under fire (T-118)")
	arena.phase="combat";arena.player.fire_cooldown=0
	check(arena.player.shoot(),"soldier can fire under the barrage")
	rooms.tick(.8);rooms.tick(.8);check(rooms.shells.size()>=1,"artillery marks the field")
	var shell=rooms.shells[0];shell.node.position=arena.player.position;var hp=arena.player.hp;arena.player.invulnerable=0
	rooms.explode_shell(shell)
	check(arena.player.hp<hp,"a shell hits the soldier")
	for i in range(60):rooms.tick(1.0)
	check(rooms.rewarded and not rooms.weapons_locked() and rooms.shells.is_empty(),"timer ends the barrage")
	arena.player.fire_cooldown=0;arena.player.turn_left=0
	check(arena.player.shoot(),"weapons back after the challenge")
	arena.queue_free();await settle()
	print("HOLD/SURVIVE: %d failures" % failures);get_tree().quit(1 if failures else 0)
