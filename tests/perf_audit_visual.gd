extends Node
## Final performance audit (2026-10-03), windowed only, not in the suites. Unlocked frame rate (no vsync)
## in the hub (day/night), a crowded battle with constant fire, and the world map: average FPS, frame-time
## median / p95 / max, freezes (>33 ms) and hitches (>100 ms), process/physics/render time, draw calls,
## nodes, active lights, and which scripts run _process/_physics_process every frame (and how many).
## Run: Godot --path . tests/perf_audit_visual.tscn   → prints PERF lines. Saves stay off.
var times:Array=[]
var last:=0
var acc={"process":0.0,"physics":0.0,"cpu":0.0,"gpu":0.0,"draw":0.0,"n":0}
var recording:=false
func _ready():call_deferred("run")
func _process(_d):
	var now=Time.get_ticks_usec()
	if recording and last>0:
		times.append((now-last)/1000.0)
		var vp=get_viewport().get_viewport_rid()
		acc.process+=Performance.get_monitor(Performance.TIME_PROCESS)*1000;acc.physics+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
		acc.cpu+=RenderingServer.viewport_get_measured_render_time_cpu(vp);acc.gpu+=RenderingServer.viewport_get_measured_render_time_gpu(vp)
		acc.draw+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME);acc.n+=1
	last=now
func measure(label:String,seconds:float,each_frame:=Callable()):
	await get_tree().create_timer(1.0).timeout
	times.clear();acc={"process":0.0,"physics":0.0,"cpu":0.0,"gpu":0.0,"draw":0.0,"n":0};last=0;recording=true
	var end=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		if each_frame.is_valid():each_frame.call()
		await get_tree().process_frame
	recording=false
	var s=times.duplicate();s.sort();var n=maxf(1,acc.n)
	var total=0.0
	for t in times:total+=t
	var freezes=times.filter(func(t):return t>33.0).size();var hitches=times.filter(func(t):return t>100.0).size()
	print("PERF %s: fps %.0f · median %.1f · p95 %.1f · max %.1f ms · freezes %d · hitches %d" % [label,times.size()*1000.0/maxf(1,total),s[s.size()/2],s[int(s.size()*.95)],s.back(),freezes,hitches])
	print("PERF %s: process %.2f · physics %.2f · render cpu %.2f gpu %.2f ms · draw calls %.0f · nodes %d · lights %d" % [label,acc.process/n,acc.physics/n,acc.cpu/n,acc.gpu/n,acc.draw/n,Performance.get_monitor(Performance.OBJECT_NODE_COUNT),visible_lights()])
	busy(label)
func visible_lights()->int:
	return get_tree().root.find_children("*","Light3D",true,false).filter(func(l):return l.is_visible_in_tree()).size()
## Scripts that tick every frame, grouped: a quick way to spot something left running for nothing.
func busy(label:String):
	var counts={}
	for node in get_tree().root.find_children("*","Node",true,false):
		var script=node.get_script()
		if script==null:continue
		var p=node.is_processing() and node.has_method("_process");var q=node.is_physics_processing() and node.has_method("_physics_process")
		if not p and not q:continue
		var key=script.resource_path.get_file()+(" [p]" if p else "")+(" [ph]" if q else "")
		counts[key]=int(counts.get(key,0))+1
	var rows=counts.keys();rows.sort_custom(func(a,b):return counts[a]>counts[b])
	print("PERF %s ticking: %s" % [label,", ".join(rows.slice(0,14).map(func(k):return "%s×%d" % [k,counts[k]]))])
func run():
	Game.save_enabled=false;Game.sound_enabled=true;Settings.persistence_enabled=false;Game.profiles.selected=true;Engine.set_meta("hub_calls_off",true)
	# Fullscreen on the Retina panel, like the author plays (pass -- --windowed for a 1600×900 window).
	var windowed="--windowed" in OS.get_cmdline_user_args()
	Settings.values.fullscreen=not windowed;Settings.values.retina=true;Settings.values.resolution="auto";Settings.values.vsync=false;Settings.values.fps=0;Settings.apply()
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if windowed:get_window().size=Vector2i(1600,900)
	await get_tree().create_timer(1.0).timeout;DisplayServer.window_move_to_foreground()
	print("PERF window %s · viewport %s · scale %.2f" % [DisplayServer.window_get_size(),get_viewport().get_visible_rect().size,DisplayServer.screen_get_scale()])
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	print("PERF preset=%s render_scale=%s light_budget=%s" % [Settings.values.graphics_preset,Settings.values.render_scale,Settings.values.light_budget])
	# Hub, day and night, standing and walking.
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	for light in ["day","night"]:
		Settings.values.world_lighting=light;Settings.apply()
		await measure("hub %s idle" % light,4.0)
		var flip=[0]
		await measure("hub %s walking" % light,4.0,func():flip[0]+=1;Game.touch_direction=[Vector2i.RIGHT,Vector2i.LEFT][(flip[0]/60)%2])
		Game.touch_direction=Vector2i.ZERO
	hub.queue_free();await get_tree().process_frame
	# Battle: a later field, a crowd advancing, the soldier firing nonstop.
	Settings.values.world_lighting="day";Settings.apply()
	Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=21;add_child(arena);arena.auto_pause_enabled=false
	arena.begin_room(4);await get_tree().create_timer(5.0).timeout
	arena.phase="combat";arena.base_hp=99999
	for i in range(10):
		var c=arena.find_free_near(Vector2i(2+i*2%(arena.grid_size-4),2))
		if c!=Vector2i(-1,-1):arena.spawn_actor(["soldier","grenadier","shield","buggy","soldier"][i%5],c,false)
	arena.soldier_hp=9999;arena.player.hp=9999
	await measure("battle crowd firing",10.0,func():Game.touch_fire=true;arena.phase="combat";arena.soldier_hp=9999;arena.player.hp=9999)
	Game.touch_fire=false
	print("PERF battle actors %d projectiles %d" % [arena.room.actors.size(),arena.room.projectiles.size()])
	Settings.values.world_lighting="night";Settings.apply()
	await measure("battle night firing",6.0,func():Game.touch_fire=true;arena.phase="combat";arena.soldier_hp=9999;arena.player.hp=9999)
	Game.touch_fire=false
	arena.queue_free();await get_tree().process_frame
	Settings.values.world_lighting="day";Settings.apply()
	# World map.
	var map=load("res://scripts/route_map.gd").new();map.available=1;map.wave_seed=Game.visual_run_seed;map.hero_weapon=Game.selected_weapon;add_child(map)
	await measure("world map",4.0)
	map.queue_free()
	get_tree().quit()
