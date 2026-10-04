extends Node3D
## CORE: shared navigation cache, base breach tactics, terrain awareness of enemies and aiming around
## half-blocks. Profile and settings writes stay disabled.
var failures=0
func check(ok:bool,message:String)->bool:
	if not ok:failures+=1;printerr("FAIL ",message);push_error(message)
	return ok
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame
func remove_wall(arena,cell):
	if arena.walls.has(cell):arena.walls[cell].node.queue_free();arena.walls.erase(cell);arena.navigation.invalidate(cell)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	await shared_cache()
	await base_breach()
	await terrain_awareness()
	await half_block_aim()
	print("NAVIGATION CACHE: failures=",failures)
	get_tree().quit(1 if failures else 0)

func shared_cache():
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.process_mode=Node.PROCESS_MODE_DISABLED
	for a in arena.actors:a.queue_free()
	arena.actors.clear();arena.walls.clear();arena.trenches.clear();arena.generators.clear();arena.wrecks.clear();arena.terrain.patches.clear();arena.navigation.reset()
	# This scenario tests an explicit waypoint, with no open base firing lane.
	for side in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:arena.add_wall(arena.base_cell+side,8)
	var cell=Vector2i(6,6);var center=arena.world_pos(cell)
	var a=arena.spawn_actor("soldier",cell+Vector2i.UP,false)
	var b=arena.spawn_actor("soldier",cell+Vector2i.RIGHT,false)
	arena.add_wall(cell,4)
	check(not arena.navigation.is_open(center,a),"a wall closes its cell")
	var misses=arena.navigation.misses
	check(not arena.navigation.is_open(center,b) and arena.navigation.misses==misses,"a second unit reuses the cached result")
	var distant=arena.world_pos(Vector2i(1,1));check(arena.navigation.is_open(distant,a),"distant cell open")
	for i in range(4):arena.board.damage_wall(cell,1,center+Vector3.BACK,Vector3.FORWARD,.5)
	check(arena.walls.has(cell) and arena.navigation.is_open(center,a),"partial damage invalidates locally and opens the slit")
	misses=arena.navigation.misses
	check(arena.navigation.is_open(distant,b) and arena.navigation.misses==misses,"distant cache retained")
	b.kind="tank";check(not arena.navigation.is_open(center,b),"vehicle clearance");b.kind="soldier"
	# A moving unit never poisons the shared static result or discards a short-lived route.
	var start=Vector2i(roundi(a.position.x*4),roundi(a.position.z*4))
	var next=start+Vector2i.DOWN
	var waypoint=cell+Vector2i.DOWN;a.route_points=[waypoint]
	var state={"key":[waypoint,arena.navigation.revision,arena.walls.size(),arena.base_cell],"start":start,"queue":[],"came":{},"free":{},"head":0,"path":[next],"done":true,"created":Time.get_ticks_msec(),"retry":0}
	a.set_meta("quarter_search",state)
	b.position=Vector3(next.x*.25,0,next.y*.25)
	check(arena.navigation.is_open(b.position,a),"units do not poison the static cache")
	check(arena.path_direction(a)==Vector2i.ZERO and a.has_meta("quarter_search") and state.has("jam_since"),"a transient jam keeps the route")
	b.position=distant
	check(arena.path_direction(a)==Vector2i.DOWN and not state.has("jam_since"),"the route resumes when the way clears")
	b.position=Vector3(next.x*.25,0,next.y*.25)
	check(arena.path_direction(a)==Vector2i.ZERO,"jammed again")
	state.jam_since=Time.get_ticks_msec()-700
	check(arena.path_direction(a)==Vector2i.ZERO and not a.has_meta("quarter_search"),"a persistent jam replans")
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
	if check(direction==Vector2i.RIGHT and tank.has_meta("cell_search"),"the tank finds its route"):
		var route:Dictionary=tank.get_meta("cell_search")
		check(route.done and route.path.size()>=6,"complete vehicle route")
		check(arena.path_direction(tank)==Vector2i.RIGHT and tank.get_meta("cell_search")==route,"the vehicle keeps its route")
		b.position=arena.actor_world_pos(tank,tank.cell+Vector2i.RIGHT);b.cell=tank.cell+Vector2i.RIGHT
		check(arena.path_direction(tank)==Vector2i.ZERO and route.has("jam_since"),"the vehicle yields to traffic")
		b.position=arena.world_pos(Vector2i(0,1));b.cell=Vector2i(0,1)
		check(arena.path_direction(tank)==Vector2i.RIGHT and not route.has("jam_since"),"the vehicle resumes")
		arena.add_wall(tank.cell+Vector2i.RIGHT,4)
		check(arena.path_direction(tank)!=Vector2i.RIGHT,"a new wall invalidates the route")
		route.jam_since=Time.get_ticks_msec()-700
		check(arena.path_direction(tank)==Vector2i.ZERO and not tank.has_meta("cell_search"),"a persistent jam replans the vehicle")
	arena.free();await settle()

## from base_breach_tactics: tanks go round intact front cover to a side breach; narrow gaps pass only infantry fire.
func base_breach():
	Engine.physics_ticks_per_second=240
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
	check(arena.enemy.base_firing_cells(enemy).is_empty(),"intact walls provide no direct base shot")
	remove_wall(arena,arena.base_cell+Vector2i.LEFT)
	var target=arena.enemy.attack_waypoint(enemy,Vector2i(-1,-1))
	check(target.y==arena.base_cell.y and target.x<arena.base_cell.x,"select firing position at left breach")
	check(arena.enemy_aim(enemy)==Vector2i.ZERO,"stop shooting front wall when left breach is open")
	var before=arena.base_hp
	for frame in range(1800):
		enemy._physics_process(1.0/60)
		for bullet in arena.projectiles.duplicate():
			if is_instance_valid(bullet):bullet.set_physics_process(false);bullet._physics_process(1.0/60)
		if arena.base_hp<before:break
		await get_tree().physics_frame
	check(arena.base_hp<before and enemy.cell.y==arena.base_cell.y and enemy.cell.x<arena.base_cell.x,"tank moves around front cover and hits base through side breach")
	check(arena.walls.has(arena.base_cell+Vector2i.UP) and arena.walls[arena.base_cell+Vector2i.UP].hp==8,"front wall stays untouched")
	arena.add_wall(arena.base_cell+Vector2i.LEFT,8);remove_wall(arena,arena.base_cell+Vector2i.RIGHT)
	target=arena.enemy.attack_waypoint(enemy,Vector2i(-1,-1))
	check(target.y==arena.base_cell.y and target.x>arena.base_cell.x,"replan when left closes and right opens")
	arena.add_wall(arena.base_cell+Vector2i.RIGHT,8)
	# Half-cell central gap can pass infantry bullets, but not full-width vehicle rounds.
	var wall=arena.walls[arena.base_cell+Vector2i.UP]
	for i in range(16):wall.sections[i]=0.0 if i%4 in [1,2] else 1.0
	arena.navigation.invalidate(arena.base_cell+Vector2i.UP)
	var soldier=arena.spawn_actor("soldier",Vector2i(1,0),false);soldier.set_physics_process(false);soldier.enemy_weapon="rifle"
	check(not arena.enemy.base_firing_cells(soldier).is_empty(),"infantry recognizes partial central firing gap")
	check(arena.enemy.base_firing_cells(enemy).is_empty(),"tank does not fire full-width round through narrow gap")
	arena.free();Engine.physics_ticks_per_second=60;await settle()

## from enemy_terrain_awareness: shots cross every floor surface; ground units detour round sand, respect ice, avoid water/forest.
func terrain_awareness():
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false);arena.phase="combat"
	arena.walls.clear();arena.trenches.clear();arena.nets.clear();arena.generators.clear();arena.wrecks.clear();arena.terrain.patches.clear();arena.navigation.reset()
	for side in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:arena.add_wall(arena.base_cell+side,8)
	var player=arena.player;player.set_physics_process(false);player.position=arena.world_pos(Vector2i(8,5));player.cell=Vector2i(8,5);player.invulnerable=0;player.hp=100;player.max_hp=100
	arena.abilities.shield_time=0;arena.abilities.cloak_time=0;arena.run.dodge=0.0
	for kind in ["soldier","buggy","apc","tank"]:
		var enemy=arena.spawn_actor(kind,Vector2i(2,5),false);enemy.set_physics_process(false);enemy.enemy_weapon="rifle";enemy.assault_time=0
		for surface in ["vegetation","water","sand","ice"]:
			arena.terrain.patches.clear();arena.terrain.set_cell(Vector2i(5,5),surface);arena.navigation.reset()
			check(arena.enemy_aim(enemy)==Vector2i.RIGHT,"%s sees target through %s" % [kind,surface])
			var before=player.hp
			var bullet=arena.spawn_bullet(enemy,enemy.position,Vector2i.RIGHT,1.0,false);bullet.set_physics_process(false)
			for frame in range(65):
				if bullet.spent:break
				bullet._physics_process(1.0/60.0)
			check(player.hp<before,"%s shot hits through %s" % [kind,surface]);player.invulnerable=0
			if not bullet.spent:bullet.consume()
		enemy.dead=true;enemy.queue_free()
	# A ground enemy chooses a faster dry detour instead of six sand cells.
	arena.terrain.patches.clear()
	for x in range(2,8):arena.terrain.set_cell(Vector2i(x,5),"sand")
	arena.navigation.reset();player.position=arena.world_pos(Vector2i(10,10));player.cell=Vector2i(10,10)
	for kind in ["soldier","tank"]:
		var enemy=arena.spawn_actor(kind,Vector2i(1,5),false);enemy.set_physics_process(false);enemy.route_points=[Vector2i(8,5)];enemy.assault_time=0
		var detoured=false
		for frame in range(220):
			var direction=arena.path_direction(enemy)
			if direction!=Vector2i.ZERO:
				var stride=.25 if enemy.uses_quarter_steps() else 1.0
				enemy.position+=Vector3(direction.x,0,direction.y)*stride;enemy.cell=arena.grid_pos(enemy.position)
				detoured=detoured or enemy.cell.y!=5
			if enemy.cell==Vector2i(8,5):break
			await get_tree().physics_frame
		check(detoured and enemy.cell==Vector2i(8,5),kind+" uses dry detour")
		var ice_cell=Vector2i(5,8);var ice_pos=arena.world_pos(ice_cell)
		arena.terrain.set_cell(ice_cell,"ice");arena.navigation.reset()
		var plain=arena.terrain.navigation_cost(arena.world_pos(Vector2i(4,8)),enemy,Vector2i.RIGHT)
		check(arena.terrain.navigation_cost(ice_pos,enemy,Vector2i.RIGHT)>plain,"AI accounts for ice control loss")
		for surface in ["vegetation","water"]:
			arena.terrain.set_cell(ice_cell,surface);arena.navigation.reset()
			check(not arena.can_stand(ice_pos,enemy) and not arena.can_enter(ice_cell,enemy),kind+" cannot enter "+surface)
		enemy.dead=true;enemy.queue_free()
	arena.free();await settle()

## from half_block_aim_revision (T-002, T-169): no firing into indestructible cover over the HQ; brick still breaches.
func half_block_aim():
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=3;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(.8).timeout;arena.set_physics_process(false)
	var base=arena.base_cell;var spot=base+Vector2i(0,-3);var cover=base+Vector2i(0,-2)
	for c in [spot,cover,base+Vector2i(0,-1)]:
		if arena.walls.has(c):arena.walls[c].node.queue_free();arena.walls.erase(c)
	var enemy=arena.spawn_actor("soldier",spot,false);enemy.assault_time=5.0;enemy.set_physics_process(false)
	arena.add_wall(cover,-1);arena.board.shape_wall(cover,0)
	check(arena.enemy.enemy_aim(enemy)!=Vector2i.DOWN,"no firing down into a concrete half-block")
	arena.walls[cover].node.queue_free();arena.walls.erase(cover);arena.add_wall(cover,4)
	check(arena.enemy.concrete_to_base(spot)==false,"brick in between still counts as breachable")
	arena.walls[cover].node.queue_free();arena.walls.erase(cover);arena.add_wall(cover,-1)  # no open shot at the HQ
	arena.player.position=arena.world_pos(spot+Vector2i(2,0));arena.player.cell=spot+Vector2i(2,0)
	for c in [spot+Vector2i(1,0),spot+Vector2i(2,0)]:
		if arena.walls.has(c):arena.walls[c].node.queue_free();arena.walls.erase(c)
	check(arena.enemy.enemy_aim(enemy)==Vector2i.RIGHT,"assault still answers a lined-up player")
	arena.free();await settle()
