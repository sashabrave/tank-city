extends Node3D
## Battle framing after the 5% zoom-in: every field cell stays inside the screen in combat and overview at
## 16:9, 16:10 and 3:2 (the border may leave the frame). Window shots /tmp/r13-fit-<w>x<h>.png.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	Settings.values.world_lighting="day";Settings.values.weather="clear";Settings.apply()
	for size in [Vector2i(1600,900),Vector2i(1440,900),Vector2i(1200,800)]:
		get_window().size=size
		var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=8;add_child(arena);arena.auto_pause_enabled=false
		await get_tree().create_timer(.5).timeout;arena.set_physics_process(false)
		for phase in ["combat","upgrade"]:
			arena.phase=phase
			for i in 60:arena.presentation._process(.1)
			await get_tree().process_frame
			var rect=Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size);var worst=1e9
			for x in range(arena.grid_size):
				for y in range(arena.grid_size):
					var c=arena.world_pos(Vector2i(x,y))
					for d in [Vector3(-.5,0,-.5),Vector3(.5,0,-.5),Vector3(-.5,0,.5),Vector3(.5,0,.5)]:
						var p=arena.camera.unproject_position(c+d)
						worst=minf(worst,minf(minf(p.x,rect.size.x-p.x),minf(p.y,rect.size.y-p.y)))
			check(worst>=0,"%s %dx%d: all cells on screen (margin %d px)" % [phase,size.x,size.y,int(worst)])
			if phase=="combat" and DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-fit-%dx%d.png" % [size.x,size.y])
		arena.queue_free();await get_tree().process_frame
	print("CAMERA FIT: %d failures" % failures);get_tree().quit(1 if failures else 0)
