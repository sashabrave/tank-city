extends Node
func capture(id:String):
	await get_tree().process_frame;await get_tree().process_frame
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://screenshots/editor-"+id+".png")
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.values.fps=60;Settings.apply()
	await get_tree().create_timer(1.0).timeout
	DisplayServer.window_set_size(Vector2i(1440,810));await get_tree().create_timer(.5).timeout
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);hub.set_physics_process(false)
	Game.built_workshops=["character","weapons","bonuses"];hub.open_workshop(false);await capture("workshop")
	hub.workshop_tab=3;hub.refresh();await capture("abilities")
	hub.close_station();hub.open_workshop(true);await capture("weapons")
	hub.queue_free();await get_tree().process_frame
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.player.set_physics_process(false)
	arena.hud.show_pause();await capture("pause")
	arena.phase="upgrade";arena.hud.show_upgrades();await capture("rewards")
	arena.hud.close_modal();arena.phase="combat";await capture("battle")
	# Offscreen viewports avoid macOS fullscreen transition timing and verify actual dimensions.
	for resolution in [Vector2i(1440,810),Vector2i(1024,768)]:
		var viewport=SubViewport.new();viewport.size=resolution;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
		var layout=load("res://scenes/ui/battle_hud.tscn").instantiate();viewport.add_child(layout)
		for path in ["BossHealth","BossName","SecondBossHealth","SecondBossName","CountdownLabel"]:layout.get_node(path).hide()
		await get_tree().process_frame;await get_tree().process_frame;RenderingServer.force_draw()
		assert(layout.get_node("RoomPanel").get_global_rect().end.x<=resolution.x)
		assert(layout.get_node("InteractButton").get_global_rect().end.y<=resolution.y)
		viewport.get_texture().get_image().save_png("res://screenshots/editor-layout-%d.png" % resolution.x)
		viewport.queue_free()
	print("EDITOR VISUAL: six game screens and two viewport layouts captured");get_tree().quit()
