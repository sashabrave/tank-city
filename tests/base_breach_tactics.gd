extends Node
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func _ready():call_deferred("run")
func remove_wall(arena,cell):
	if arena.walls.has(cell):arena.walls[cell].node.queue_free();arena.walls.erase(cell);arena.navigation.invalidate(cell)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1);Engine.physics_ticks_per_second=240
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false);arena.phase="combat";arena.spawn_queue.clear();arena.base_hp=10000
	for actor in arena.actors:actor.set_physics_process(false);actor.dead=true
	arena.player.position=arena.world_pos(Vector2i(0,0));arena.player.cell=Vector2i(0,0)
	for wall in arena.walls.values():wall.node.queue_free()
	for trench in arena.trenches.values():trench.queue_free()
	for node in arena.get_children():
		if node.has_meta("vegetation_appearance"):node.queue_free()
	arena.walls.clear();arena.trenches.clear();arena.terrain.patches.clear();arena.wrecks.clear();arena.navigation.reset()
	for side in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:arena.add_wall(arena.base_cell+side,8)
	var enemy=arena.spawn_actor("tank",arena.base_cell+Vector2i.UP*4,false);enemy.set_physics_process(false);enemy.route_points.clear();enemy.facing=Vector2i.DOWN
	check(arena.enemy.base_firing_cells(enemy).is_empty(),"Intact walls provide no direct base shot")
	remove_wall(arena,arena.base_cell+Vector2i.LEFT)
	var target=arena.enemy.attack_waypoint(enemy,Vector2i(-1,-1))
	check(target.y==arena.base_cell.y and target.x<arena.base_cell.x,"Select firing position at left breach")
	check(arena.enemy_aim(enemy)==Vector2i.ZERO,"Stop shooting front wall when left breach is open")
	var before=arena.base_hp
	for frame in range(1800):
		enemy._physics_process(1.0/60)
		for bullet in arena.projectiles.duplicate():
			if is_instance_valid(bullet):bullet.set_physics_process(false);bullet._physics_process(1.0/60)
		if arena.base_hp<before:break
		await get_tree().physics_frame
	check(arena.base_hp<before and enemy.cell.y==arena.base_cell.y and enemy.cell.x<arena.base_cell.x,"Tank moves around front cover and hits base through side breach")
	check(arena.walls.has(arena.base_cell+Vector2i.UP) and arena.walls[arena.base_cell+Vector2i.UP].hp==8,"Front wall stays untouched")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/r13-base-breach.png")
	arena.add_wall(arena.base_cell+Vector2i.LEFT,8);remove_wall(arena,arena.base_cell+Vector2i.RIGHT)
	target=arena.enemy.attack_waypoint(enemy,Vector2i(-1,-1))
	check(target.y==arena.base_cell.y and target.x>arena.base_cell.x,"Replan when left closes and right opens")
	arena.add_wall(arena.base_cell+Vector2i.RIGHT,8)
	# Half-cell central gap can pass infantry bullets, but not full-width vehicle rounds.
	var wall=arena.walls[arena.base_cell+Vector2i.UP]
	for i in range(16):wall.sections[i]=0.0 if i%4 in [1,2] else 1.0
	arena.navigation.invalidate(arena.base_cell+Vector2i.UP)
	var soldier=arena.spawn_actor("soldier",Vector2i(1,0),false);soldier.set_physics_process(false);soldier.enemy_weapon="rifle"
	check(not arena.enemy.base_firing_cells(soldier).is_empty(),"Infantry recognizes partial central firing gap")
	check(arena.enemy.base_firing_cells(enemy).is_empty(),"Tank does not fire full-width round through narrow gap")
	print("BASE BREACH TACTICS failures ",failures);get_tree().quit(1 if failures else 0)
