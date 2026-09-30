extends Node3D
# Windowed diagnostic: frame times while the soldier fires continuously into (a) open air, (b) brick walls,
# (c) enemies. Prints median / p95 / max and every spike above 25 ms with live counters.
# Run: Godot --path . tests/shooting_performance.tscn. Profile and settings writes stay disabled.
var arena
var times:Array=[]
var spikes:Array=[]
var last=0
var label=""
var cpu_total=0.0
var gpu_total=0.0
var process_total=0.0
var physics_total=0.0
func _ready():call_deferred("run")
func frames(n):
	for i in range(n):await get_tree().process_frame
func _process(_delta):
	var now=Time.get_ticks_usec()
	if last>0 and label!="":
		var ms=(now-last)/1000.0;times.append(ms)
		var vp=get_viewport().get_viewport_rid()
		var gpu=RenderingServer.viewport_get_measured_render_time_gpu(vp);var cpu=RenderingServer.viewport_get_measured_render_time_cpu(vp)
		cpu_total+=cpu;gpu_total+=gpu;process_total+=Performance.get_monitor(Performance.TIME_PROCESS)*1000;physics_total+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
		if ms>25:spikes.append("%s %.1f ms · process %.1f · physics %.1f · render cpu %.1f gpu %.1f · projectiles %d · draw %d" % [label,ms,Performance.get_monitor(Performance.TIME_PROCESS)*1000,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,cpu,gpu,arena.room.projectiles.size(),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	last=now
func scenario(name:String,facing:Vector2i,seconds:float):
	times.clear();spikes.clear();label=name;cpu_total=0;gpu_total=0;process_total=0;physics_total=0
	arena.player.facing=facing;arena.player.model.rotation.y=arena.player.angle_for(facing)
	var end=Time.get_ticks_msec()+int(seconds*1000);var shots=0;var peak=0
	while Time.get_ticks_msec()<end:
		Game.touch_fire=true;arena.phase="combat"
		var before=arena.room.projectiles.size()
		await get_tree().process_frame
		if arena.room.projectiles.size()>before:shots+=1
		peak=maxi(peak,arena.room.projectiles.size())
	print("  shots=%d peak_projectiles=%d phase=%s" % [shots,peak,arena.phase])
	Game.touch_fire=false;label=""
	var sorted=times.duplicate();sorted.sort()
	var median=sorted[sorted.size()/2] if not sorted.is_empty() else 0.0
	var p95=sorted[int(sorted.size()*.95)] if not sorted.is_empty() else 0.0
	print("SCENARIO %s frames=%d median=%.1f p95=%.1f max=%.1f spikes=%d" % [name,sorted.size(),median,p95,sorted.back() if not sorted.is_empty() else 0.0,spikes.size()])
	var n=maxf(1,sorted.size())
	print("  avg process %.1f · physics %.1f · render cpu %.1f · gpu %.1f ms" % [process_total/n,physics_total/n,cpu_total/n,gpu_total/n])
	for spike in spikes.slice(0,8):print("  SPIKE ",spike)
func run():
	Game.save_enabled=false;Game.sound_enabled=true;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	Campaign.configure(1)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=14;add_child(arena);arena.auto_pause_enabled=false
	arena.begin_room(3);await frames(90)
	arena.room.spawn_queue.clear()
	for actor in arena.room.actors:
		if is_instance_valid(actor) and not actor.player_owned:actor.set_physics_process(false)
	# Frozen dummies far from the line of fire keep the wave alive.
	for corner in [Vector2i(1,1),Vector2i(arena.grid_size-2,1)]:
		var dummy=arena.spawn_actor("soldier",arena.find_free_near(corner),false);dummy.set_physics_process(false);dummy.max_hp=9999;dummy.hp=9999
	arena.phase="combat"
	await scenario("warmup_up",Vector2i.UP,3.0)
	await scenario("air_side",Vector2i.LEFT,6.0)
	# Wall directly in front: build a brick row above the soldier.
	var cell=arena.player.cell+Vector2i.UP*2
	for x in range(-1,2):
		var c=cell+Vector2i(x,0)
		if not arena.room.walls.has(c):arena.add_wall(c,40)
	await scenario("bricks_up",Vector2i.UP,6.0)
	for i in range(4):
		var enemy=arena.spawn_actor("soldier",arena.find_free_near(arena.player.cell+Vector2i(3+i,0)),false);enemy.max_hp=500;enemy.hp=500;enemy.set_physics_process(false)
	await scenario("enemies_right",Vector2i.RIGHT,6.0)
	get_tree().quit()
