extends Node
func _ready():call_deferred("run")
func run():
	Settings.persistence_enabled=false;Settings.values.fps=60;Settings.apply()
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	# The restored superboss is the citadel final: world 3, local stage 7.
	Campaign.configure(3)
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.begin_room(7);arena.phase="combat";arena.set_physics_process(false);arena.player.set_physics_process(false)
	var boss=arena.spawn_actor("boss",Vector2i(15,4),false);boss.set_physics_process(false)
	for i in range(8):arena.spawn_actor("soldier",Vector2i(3+i*3,10),false).set_physics_process(false)
	var samples=[]
	for i in range(600):
		await get_tree().process_frame
		if i>180:samples.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
	samples.sort()
	var data={"settings":Settings.values,"viewport":str(get_viewport().get_visible_rect().size),"cpu_process_ms_median":samples[samples.size()/2],"cpu_process_ms_p95":samples[int(samples.size()*.95)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"fps":Performance.get_monitor(Performance.TIME_FPS)}
	FileAccess.open("/private/tmp/tank-render-probe.json",FileAccess.WRITE).store_string(JSON.stringify(data))
	# Headless has no rendered frame; the screenshot is only for windowed runs.
	if DisplayServer.get_name()!="headless":RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://screenshots/v09-restored-superboss.png")
	print("RENDER_PROBE ",JSON.stringify(data));get_tree().quit()
