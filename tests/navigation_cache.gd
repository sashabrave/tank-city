extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.process_mode=Node.PROCESS_MODE_DISABLED
	for a in arena.actors:a.queue_free()
	arena.actors.clear();arena.walls.clear();arena.trenches.clear();arena.generators.clear();arena.wrecks.clear();arena.terrain.patches.clear();arena.navigation.reset()
	# This scenario tests an explicit waypoint, with no open base firing lane.
	for side in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:arena.add_wall(arena.base_cell+side,8)
	var cell=Vector2i(6,6);var center=arena.world_pos(cell)
	var a=arena.spawn_actor("soldier",cell+Vector2i.UP,false)
	var b=arena.spawn_actor("soldier",cell+Vector2i.RIGHT,false)
	arena.add_wall(cell,4)
	assert(not arena.navigation.is_open(center,a))
	var misses=arena.navigation.misses
	assert(not arena.navigation.is_open(center,b) and arena.navigation.misses==misses)
	var distant=arena.world_pos(Vector2i(1,1));assert(arena.navigation.is_open(distant,a))
	for i in range(4):arena.board.damage_wall(cell,1,center+Vector3.BACK,Vector3.FORWARD,.5)
	assert(arena.walls.has(cell) and arena.navigation.is_open(center,a))
	misses=arena.navigation.misses
	assert(arena.navigation.is_open(distant,b) and arena.navigation.misses==misses)
	b.kind="tank";assert(not arena.navigation.is_open(center,b));b.kind="soldier"
	# A moving unit never poisons the shared static result or discards a short-lived route.
	var start=Vector2i(roundi(a.position.x*4),roundi(a.position.z*4))
	var next=start+Vector2i.DOWN
	var waypoint=cell+Vector2i.DOWN;a.route_points=[waypoint]
	var state={"key":[waypoint,arena.navigation.revision,arena.walls.size(),arena.base_cell],"start":start,"queue":[],"came":{},"free":{},"head":0,"path":[next],"done":true,"created":Time.get_ticks_msec(),"retry":0}
	a.set_meta("quarter_search",state)
	b.position=Vector3(next.x*.25,0,next.y*.25)
	assert(arena.navigation.is_open(b.position,a))
	assert(arena.path_direction(a)==Vector2i.ZERO and a.has_meta("quarter_search") and state.has("jam_since"))
	b.position=distant
	assert(arena.path_direction(a)==Vector2i.DOWN and not state.has("jam_since"))
	b.position=Vector3(next.x*.25,0,next.y*.25)
	assert(arena.path_direction(a)==Vector2i.ZERO)
	state.jam_since=Time.get_ticks_msec()-700
	assert(arena.path_direction(a)==Vector2i.ZERO and not a.has_meta("quarter_search"))
	# A vehicle keeps its completed route, yields to traffic, and invalidates on geometry changes.
	arena.walls.clear();arena.terrain.patches.clear();arena.navigation.reset()
	for side in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:arena.add_wall(arena.base_cell+side,8)
	a.position=arena.world_pos(Vector2i(0,0));b.position=arena.world_pos(Vector2i(0,1))
	var tank=arena.spawn_actor("tank",Vector2i(2,2),false);tank.route_points=[Vector2i(8,2)]
	var direction=Vector2i.ZERO
	for frame in range(120):
		direction=arena.path_direction(tank)
		if direction!=Vector2i.ZERO:break
		await get_tree().physics_frame
	assert(direction==Vector2i.RIGHT)
	var route:Dictionary=tank.get_meta("cell_search")
	assert(route.done and route.path.size()>=6)
	assert(arena.path_direction(tank)==Vector2i.RIGHT and tank.get_meta("cell_search")==route)
	b.position=arena.actor_world_pos(tank,tank.cell+Vector2i.RIGHT);b.cell=tank.cell+Vector2i.RIGHT
	assert(arena.path_direction(tank)==Vector2i.ZERO and route.has("jam_since"))
	b.position=arena.world_pos(Vector2i(0,1));b.cell=Vector2i(0,1)
	assert(arena.path_direction(tank)==Vector2i.RIGHT and not route.has("jam_since"))
	arena.add_wall(tank.cell+Vector2i.RIGHT,4)
	assert(arena.path_direction(tank)!=Vector2i.RIGHT)
	route.jam_since=Time.get_ticks_msec()-700
	assert(arena.path_direction(tank)==Vector2i.ZERO and not tank.has_meta("cell_search"))
	print("PASS shared navigation: reuse across units, local invalidation after partial damage, distant cache retained, vehicle clearance, transient jam keeps route then resumes, persistent jam replans")
	get_tree().quit()
