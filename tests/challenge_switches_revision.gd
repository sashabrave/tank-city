extends Node3D
# Switches: plates flash in order, stepping in the same order opens the safe; three tries.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func frames(n):
	for i in range(n):await get_tree().process_frame
func room():
	var found=[]
	for candidate in range(1,800):
		var plan=RoutePlan.build(candidate)
		for stage in range(1,6):
			for n in plan[stage]:
				if n.type=="switches" and found.is_empty():found=[candidate,plan,n]
		if not found.is_empty():break
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=found[0];add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	arena.run.route_choices=RoutePlan.path_to(found[1],found[2].stage,found[2].id);arena.begin_room(found[2].stage)
	return arena
func wait_input(rooms):
	for i in range(900):
		if rooms.switch_state=="input":return
		await get_tree().process_frame
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	var arena=room();await frames(3);var rooms=arena.challenges;var level=arena.room.difficulty
	check(rooms.plates.size()==ChallengeRooms.PLATES[level] and rooms.sequence.size()==ChallengeRooms.SEQUENCE[level],"plates and order by difficulty")
	check(rooms.switch_state=="show" and rooms.blocks_waves(),"order shown first")
	await wait_input(rooms)
	check(rooms.switch_state=="input","input after the demonstration")
	var wrong=(rooms.sequence[0]+1)%rooms.plates.size()
	if wrong in [rooms.sequence[0]]:wrong=(wrong+1)%rooms.plates.size()
	rooms.press(wrong)
	check(rooms.tries==2 and rooms.switch_state=="show","mistake costs a try and replays")
	await wait_input(rooms)
	for plate in rooms.sequence:
		arena.player.position=rooms.plates[plate].node.position;rooms.tick_switches()
		arena.player.position=arena.world_pos(arena.room.base_cell)+Vector3(0,0,-1);rooms.tick_switches()
	check(rooms.rewarded and arena.room.pickups.any(func(p):return p.kind=="recipe_draft"),"right order opens the safe")
	arena.queue_free();await frames(3)
	arena=room();await frames(3);rooms=arena.challenges;await wait_input(rooms)
	for i in range(3):
		rooms.switch_state="input";rooms.step=0;rooms.press((rooms.sequence[0]+1)%rooms.plates.size())
	check(rooms.rewarded and arena.room.room_cleared and not arena.room.pickups.any(func(p):return p.kind=="recipe_draft"),"three mistakes lock the safe")
	arena.queue_free();await frames(3)
	print("SWITCHES: %d failures" % failures);get_tree().quit(1 if failures else 0)
