extends Node
## Half-blocks are ordinary obstacles for enemies (author, 2026-10-03): the brick half blocks bodies,
## pathing and shots; only the open half lets infantry (0.49 wide) and bullets through. Vehicles never pass.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func clear(arena,c):
	if arena.walls.has(c):arena.walls[c].node.queue_free();arena.walls.erase(c);arena.navigation.invalidate(c)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=5;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(.6).timeout;arena.set_physics_process(false)
	for a in arena.actors:if a!=arena.player:a.set_physics_process(false)
	var cell=Vector2i(6,6)
	for x in range(4,9):
		for y in range(4,9):clear(arena,Vector2i(x,y))
	arena.add_wall(cell,6);arena.board.shape_wall(cell,0)  # side 0: the left half stays
	arena.navigation.invalidate(cell)
	var soldier=arena.spawn_actor("soldier",cell+Vector2i(0,-2),false);soldier.set_physics_process(false)
	var tank=arena.spawn_actor("tank",cell+Vector2i(2,-3),false);tank.set_physics_process(false)
	var center=arena.world_pos(cell)
	var left=center+Vector3(-.25,0,0);var right=center+Vector3(.25,0,0)
	check(not arena.can_stand(left,soldier,true),"infantry cannot stand in the brick half")
	check(arena.can_stand(right,soldier,true),"infantry fits the open half")
	check(not arena.navigation.is_open(left,soldier) and arena.navigation.is_open(right,soldier),"the path planner sees the same: brick closed, gap open")
	check(not arena.can_enter(cell,tank) and not arena.can_stand(center,tank,true),"a vehicle never enters a half-block cell")
	# Shots: through the brick half they stop, along the open half they pass.
	var from_left=left+Vector3(0,0,-2);var to_left=left+Vector3(0,0,2)
	var from_right=right+Vector3(.06,0,-2);var to_right=right+Vector3(.06,0,2)
	check(not arena.clear_shot(from_left,to_left,.2),"a shot through the brick half is blocked")
	check(arena.clear_shot(from_right,to_right,.2),"a thin shot along the open half passes")
	# Real movement: the soldier walking down past the half-block never overlaps the brick.
	var overlapped=false;var goal=cell+Vector2i(0,3)
	soldier.route_points.clear()
	for frame in range(360):
		soldier.try_move(Vector2i.DOWN if soldier.position.z<arena.world_pos(goal).z else Vector2i.ZERO)
		soldier._physics_process(1.0/60.0)
		if preload("res://scripts/section_wall.gd").overlap(arena.walls[cell],center,soldier.position,Vector2(.245,.245)):overlapped=true
		await get_tree().physics_frame
	check(not overlapped,"a soldier moving past never steps into the brick half")
	print("HALF BLOCK OBSTACLE: %d failures" % failures);get_tree().quit(1 if failures else 0)
