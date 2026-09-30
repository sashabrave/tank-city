extends Node
var arena
func _ready():call_deferred("run")
func samples(label:String):
	for i in range(30):await get_tree().process_frame
	var elapsed=[];var cpu=[];var last=Time.get_ticks_usec()
	for i in range(180):
		await get_tree().process_frame
		var now=Time.get_ticks_usec();elapsed.append((now-last)/1000.0);last=now
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
	elapsed.sort();cpu.sort()
	print("PERF ",label," frame_ms median=",elapsed[90]," p95=",elapsed[171]," max=",elapsed.back()," cpu_p95=",cpu[171]," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Settings.values.fullscreen=false;Settings.values.fps=0;Settings.values.vsync=0;Settings.apply();Campaign.configure(3)
	arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;arena.run_seed=14;add_child(arena);arena.set_physics_process(false)
	var began=Time.get_ticks_usec();arena.begin_room(5);print("PERF begin_room ms=",(Time.get_ticks_usec()-began)/1000.0)
	arena.phase="combat";arena.spawn_queue.clear();arena.player.hp=999999;arena.base_hp=999999
	for actor in arena.actors:actor.set_physics_process(false)
	began=Time.get_ticks_usec();arena.terrain.generate();print("PERF terrain.generate ms=",(Time.get_ticks_usec()-began)/1000.0)
	var enemy=arena.spawn_actor("tank",Vector2i(1,0),false);enemy.set_physics_process(false);enemy.route_points=[Vector2i(arena.grid_size-2,arena.grid_size-3)]
	var costs=[]
	for i in range(8):
		began=Time.get_ticks_usec();arena.path_direction(enemy);costs.append((Time.get_ticks_usec()-began)/1000.0)
	print("PERF vehicle path ms=",costs)
	var ready=false
	for frame in range(240):
		await get_tree().physics_frame
		if arena.path_direction(enemy)!=Vector2i.ZERO:ready=true;break
	assert(ready,"Incremental vehicle search must finish")
	began=Time.get_ticks_usec()
	for i in range(100):arena.path_direction(enemy)
	print("PERF cached vehicle path average ms=",(Time.get_ticks_usec()-began)/100000.0)
	await samples("forest-on-static")
	for node in arena.get_children():
		if node.has_meta("vegetation_appearance") or node.name=="TerrainAmbience":node.visible=false
	await samples("forest-hidden-static")
	for node in arena.get_children():
		if node.has_meta("vegetation_appearance") or node.name=="TerrainAmbience":node.visible=true
	for i in range(5):
		var actor=arena.spawn_actor("tank" if i%2==0 else "soldier",Vector2i(3+i*4,0),false);actor.hp=9999
	enemy.set_physics_process(true)
	await samples("forest-on-six-enemies")
	print("PERFORMANCE PROBE COMPLETE");get_tree().quit()
