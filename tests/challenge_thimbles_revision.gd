extends Node3D
# Thimbles: the prize cup is tracked through swaps; one guess; right cup rewards, wrong cup only opens the exit.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func frames(n):
	for i in range(n):await get_tree().process_frame
func room(offset:int):
	var found=[]
	for candidate in range(1+offset,600):
		var plan=RoutePlan.build(candidate)
		for stage in range(1,6):
			for n in plan[stage]:
				if n.type=="thimbles" and found.is_empty():found=[candidate,plan,n]
		if not found.is_empty():break
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=found[0];add_child(arena);arena.auto_pause_enabled=false
	arena.run.route_choices=RoutePlan.path_to(found[1],found[2].stage,found[2].id);arena.begin_room(found[2].stage)
	return arena
func wait_pick(rooms):
	for i in range(900):
		if rooms.thimble_state=="pick":return
		await get_tree().process_frame
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	var arena=room(0);await frames(3);var rooms=arena.challenges
	check(arena.room.mode=="thimbles" and rooms.cups.size()==ChallengeRooms.CUPS[arena.room.difficulty],"cups by difficulty")
	check(rooms.hidden_cup.has_node("Prize") and rooms.thimble_state=="show","prize shown first")
	check(rooms.blocks_waves() and not arena.room.room_cleared,"room waits for the guess")
	await wait_pick(rooms)
	check(rooms.thimble_state=="pick","cups shuffle and wait for a pick")
	check(rooms.hidden_cup.has_node("Prize"),"prize stays under its cup through swaps")
	arena.player.position=rooms.hidden_cup.position+Vector3(0,0,1)
	check(rooms.nearest_cup()==rooms.hidden_cup,"nearest cup detected")
	arena.interact()
	check(rooms.rewarded and arena.room.pickups.any(func(p):return p.kind=="recipe_draft"),"right cup gives the reward")
	arena.queue_free();await frames(3)
	arena=room(0);await frames(3);rooms=arena.challenges;await wait_pick(rooms)
	var wrong=rooms.cups.filter(func(c):return c!=rooms.hidden_cup)[0]
	arena.player.position=wrong.position+Vector3(0,0,1)
	rooms.pick_cup(rooms.nearest_cup())
	check(rooms.rewarded and arena.room.room_cleared and not arena.room.pickups.any(func(p):return p.kind=="recipe_draft"),"wrong cup: exit without reward")
	rooms.pick_cup(rooms.hidden_cup)
	check(not arena.room.pickups.any(func(p):return p.kind=="recipe_draft"),"only one guess")
	arena.queue_free();await frames(3)
	print("THIMBLES: %d failures" % failures);get_tree().quit(1 if failures else 0)
