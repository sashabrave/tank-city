extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.new_recipes.clear();Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.set_physics_process(false);arena.phase="upgrade"
	for actor in arena.actors:actor.set_physics_process(false)
	var enemy=arena.spawn_actor("soldier",Vector2i(1,1),false);enemy.set_physics_process(false)
	enemy.route_points=[Vector2i(-10,-10)]
	var start=Time.get_ticks_usec()
	for i in range(5):arena.path_direction(enemy)
	print("PATH benchmark five unreachable searches ms: ",(Time.get_ticks_usec()-start)/1000.0)
	assert((Time.get_ticks_usec()-start)<20000)
	arena.process_mode=Node.PROCESS_MODE_DISABLED
	for a in arena.actors:a.queue_free()
	# Isolated fixture: the run seed is random, so its water and vegetation could block the test column.
	arena.actors.clear();arena.walls.clear();arena.trenches.clear();arena.wrecks.clear();arena.generators.clear();arena.terrain.patches.clear()
	var cell=Vector2i(5,5);var center=arena.world_pos(cell)
	var pit=Node3D.new();arena.add_child(pit);arena.trenches[cell]=pit
	var first=arena.spawn_actor("soldier",cell+Vector2i.LEFT,false)
	var second=arena.spawn_actor("soldier",cell+Vector2i.RIGHT,false)
	first.position=center+Vector3(-.5,0,0);first.cell=arena.grid_pos(first.position);first.moving=true;first.destination=cell
	assert(not arena.board.trench_available(cell,second))
	assert(arena.board.occupy_trench(first,cell))
	assert(first.position.is_equal_approx(center) and not first.moving and first.occupying_trench)
	assert(not arena.board.occupy_trench(second,cell))
	assert(not arena.can_stand(center+Vector3(.5,0,0),second,true))
	first.dead=true
	assert(arena.board.occupy_trench(second,cell))
	second.player_owned=true;arena.player=second
	assert(arena.board.interact_trench() and not second.occupying_trench and not second.moving)
	assert(arena.board.trench_available(cell,first))
	second.dead=true;first.dead=false;first.occupying_trench=false;first.moving=false
	arena.trenches.clear();arena.boss_room=false
	# This scenario tests an explicit waypoint, with no open base firing lane.
	for side in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:arena.add_wall(arena.base_cell+side,8)
	# Two central columns removed: a straight .5-wide corridor through the block.
	var sections=[]
	for i in range(16):sections.append(0.0 if i%4 in [1,2] else 1.0)
	arena.walls[cell]={"hp":8.0,"sections":sections}
	arena.navigation.reset()
	assert(is_equal_approx(arena.body_size(first),.49))
	for direction in [-1,1]:
		first.position=center+Vector3(0,0,-direction*1.5);first.cell=arena.grid_pos(first.position)
		first.route_points=[cell+Vector2i(0,direction*2)];first.assault_time=0
		if first.has_meta("quarter_search"):first.remove_meta("quarter_search")
		var reached=false
		for step in range(300):
			await get_tree().physics_frame
			var dir=arena.path_direction(first)
			if dir==Vector2i.ZERO:continue
			var next=first.position+Vector3(dir.x,0,dir.y)*.25
			assert(arena.can_stand(next,first));assert(is_equal_approx(next.x,center.x))
			first.position=next;first.cell=arena.grid_pos(next)
			if direction*(next.z-center.z)>=1.5:reached=true;break
		assert(reached)
	# A remaining central section must immediately invalidate a cached move.
	arena.walls[cell].sections[5]=1.0;arena.navigation.invalidate(cell)
	assert(not arena.can_stand(center,first))
	var crowd=[]
	for i in range(10):
		var a=arena.spawn_actor("soldier",Vector2i(1+i%5,1+i/5),false)
		a.route_points=[Vector2i(-10,-10)];crowd.append(a)
	var worst=0
	for frame in range(90):
		await get_tree().physics_frame
		var began=Time.get_ticks_usec()
		for a in crowd:arena.path_direction(a)
		worst=maxi(worst,Time.get_ticks_usec()-began)
	print("PATH ten infantry / 90 frames worst search batch ms: ",worst/1000.0)
	assert(worst<20000)
	print("PASS trench reservation, centering, full-cell exclusion, death/exit release, .49 infantry through .5 corridor both ways, closed-gap collision")
	get_tree().quit()
