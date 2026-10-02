extends Node3D
## Probe: daylight battles on a light and a mid biome, /tmp/r13-day-<seed>-<tag>.png (tag from args).
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	Settings.values.world_lighting="day";Settings.values.weather="clear";Settings.values.sun_day="golden";Settings.values.show_fps=false;Settings.apply()
	get_window().size=Vector2i(1600,900)
	var tag=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "x"
	for seed in [21,8,4]:
		var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=seed;add_child(arena);arena.auto_pause_enabled=false
		await get_tree().create_timer(1.6).timeout;arena.set_physics_process(false)
		print("FLOOR ",seed," ",Color(arena.room_palette().floor).get_luminance())
		await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-day-%d-%s.png" % [seed,tag])
		remove_child(arena);arena.queue_free();await get_tree().process_frame
	get_tree().quit()
