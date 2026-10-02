extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Game.new_recipes.clear();Game.return_through_gate=false
	for visit in range(2):
		var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
		assert(hub.phase=="intro" and not hub.root.visible)
		assert(hub.printer_pos==Vector3(3,0,3) and not hub.hub_free(Vector2i(3,3)))
		hub.interact();hub.launch();assert(not hub.exit_queued and not is_instance_valid(hub.build_menu))
		# The 0.48 s timeline runs on tweens: a loaded headless machine may finish it a few frames late.
		var started=Time.get_ticks_msec()
		await get_tree().create_timer(.52).timeout
		while hub.phase=="intro" and Time.get_ticks_msec()-started<3000:await get_tree().process_frame
		assert(hub.phase=="combat" and hub.root.visible and hub.dpad.enabled)
		assert(hub.avatar.position.is_equal_approx(Vector3(3,0,1)) and hub.cell==Vector2i(3,1))
		assert(is_equal_approx(get_viewport().get_camera_3d().size,11.8))
		if visit==0 and DisplayServer.get_name()!="headless":
			RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/printer_hub.png")
			var cam=get_viewport().get_camera_3d();hub.root.hide();cam.size=4;cam.position+=hub.printer_pos+Vector3(0,.7,0)
			await get_tree().create_timer(.1).timeout
			RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/printer_close.png")
		hub.queue_free();await get_tree().process_frame
	print("PRINTER PASS: repeat entry, input lock, 0.48 s sequence, two-cell exit, camera restored, blocked footprint")
	get_tree().quit()
