extends Node3D
## Dark maze challenge: maze layout, reachable goal, route count by stars, darkness, success and time-out.
## Window shots /tmp/r13-maze-*.png. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func shot(path):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(path)
func loops(plan:Dictionary)->int:
	# Edges minus nodes plus one = independent cycles (extra routes) in the open-cell graph.
	var edges=0
	for cell in plan.open:
		for dir in [Vector2i.RIGHT,Vector2i.DOWN]:
			if plan.open.has(cell+dir):edges+=1
	return edges-plan.open.size()+1
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	check("maze" in RoutePlan.CHALLENGES,"maze joins the route challenges")
	var easy=ChallengeLayouts.maze_plan(15,7,0);var hard=ChallengeLayouts.maze_plan(15,7,2)
	check(loops(easy)>loops(hard),"★ has more routes than ★★ (%d / %d)" % [loops(easy),loops(hard)])
	check(easy.goal.y<5,"goal lies far from the entrance (%s)" % str(easy.goal))
	var arena=load("res://scenes/arena.tscn").instantiate();arena.sandbox=true;arena.sandbox_mode="maze";arena.sandbox_difficulty=1;arena.run_seed=11;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.2).timeout
	var goal=arena.challenges.goal_flag
	check(is_instance_valid(goal),"green flag placed")
	check(is_instance_valid(arena.challenges.darkness),"darkness covers the field")
	check(arena.room.spawn_queue.is_empty() and arena.enemy_count()==0,"no enemies in the maze")
	# Walking route from the soldier to the flag through the real board (walls and terrain).
	var start=arena.grid_pos(arena.room.player.position);var target=arena.grid_pos(goal.position)
	var seen={start:true};var queue=[start]
	while not queue.is_empty():
		var at=queue.pop_front()
		for d in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			var to=at+d
			if seen.has(to) or not arena.inside(to) or arena.walls.has(to) or arena.terrain.movement_blocked_at_cell(to) or arena.room.trenches.has(to):continue
			seen[to]=true;queue.append(to)
	check(seen.has(target),"the flag is reachable on foot")
	var props=arena.find_children("*","Node3D",false,false).filter(func(n):return n.name.begins_with("Lamp") or n.name.begins_with("Tripod"))
	await shot("/tmp/r13-maze-dark.png")
	check(not arena.challenges.timer().is_empty() and arena.challenges.timer().title=="Тёмный лабиринт","countdown shown in the HUD")
	arena.room.player.position=goal.position;arena.room.player.cell=arena.grid_pos(goal.position)
	await get_tree().create_timer(.3).timeout
	check(arena.challenges.rewarded and int(Game.progression.counters.get("challenge_maze",0))>=1,"reaching the flag wins")
	check(is_instance_valid(arena.room.flag) and arena.flat_distance(arena.room.flag.position,goal.position)<.1 if is_instance_valid(goal) else is_instance_valid(arena.room.flag),"exit stands at the goal")
	await get_tree().create_timer(1.0).timeout
	await shot("/tmp/r13-maze-lit.png")
	arena.queue_free();await get_tree().process_frame
	# Time-out: lights come on, exit opens, no reward.
	var second=load("res://scenes/arena.tscn").instantiate();second.sandbox=true;second.sandbox_mode="maze";second.sandbox_difficulty=2;second.run_seed=12;add_child(second);second.auto_pause_enabled=false
	await get_tree().create_timer(1.0).timeout
	var before=int(Game.progression.counters.get("challenge_maze",0))
	second.challenges.progress=second.challenges.goal-.05
	await get_tree().create_timer(.3).timeout
	check(second.challenges.timed_out and not second.challenges.rewarded and second.room.room_cleared,"time-out opens the exit")
	check(int(Game.progression.counters.get("challenge_maze",0))==before,"time-out gives no success")
	print("MAZE: %d failures" % failures);get_tree().quit(1 if failures else 0)
