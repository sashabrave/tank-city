extends Node
## Window check of brick walls around the HQ: smooth PCF shadows (no PCSS grain), dense joints, clay
## colour, darker reinforced brick. Saves /tmp/r13-bricks-*.png. No profile or settings writes.
func _ready():call_deferred("run")
func settle(n:=3):
	for i in n:await get_tree().process_frame
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	Settings.values.world_lighting=OS.get_environment("R13_LIGHT") if OS.get_environment("R13_LIGHT")!="" else "day"
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await settle()
	Campaign.configure(1,false);main.start_run();await settle()
	main.enter_room(int(OS.get_environment("R13_ROOM")) if OS.get_environment("R13_ROOM")!="" else 0);await settle(260)
	var arena=main.run_arena;arena.auto_pause_enabled=false
	var sun=arena.find_children("*","DirectionalLight3D",true,false)
	print("SUN angular=%.2f blur=%.2f" % [sun[0].light_angular_distance,sun[0].shadow_blur] if not sun.is_empty() else "no sun")
	get_window().size=Vector2i(1600,900);await settle(5)
	arena.set_physics_process(false);get_tree().paused=true;await settle(5)
	# Close-up on the HQ ring: the same angle as play, a smaller orthographic frame.
	var camera=get_viewport().get_camera_3d();var base=arena.find_children("*","Node3D",true,false).filter(func(n):return n.name.to_lower().contains("base") or n.get_script()==load("res://scripts/mobile_hq.gd"))
	var focus=base[0].global_position if not base.is_empty() else Vector3.ZERO
	camera.set_process(false);camera.set_physics_process(false)
	camera.size=float(OS.get_environment("R13_ZOOM")) if OS.get_environment("R13_ZOOM")!="" else 5.0
	camera.global_position=focus+Vector3(0,19,14).rotated(Vector3.UP,deg_to_rad(10));camera.look_at(focus)
	await settle(5)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/r13-bricks-field.png")
	get_tree().paused=false
	print("BRICKS done");get_tree().quit()
