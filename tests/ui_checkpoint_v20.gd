extends Node
func _ready():call_deferred("run_test")
func shot(path):
	await get_tree().process_frame
	if DisplayServer.get_name()=="headless":return
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png(path)
func run_test():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	Game.apply_profile(Game.fresh_profile.duplicate(true))
	var main=load("res://scripts/main.gd").new();add_child(main);await get_tree().process_frame;await get_tree().process_frame
	main.start_run();main.enter_room(0)
	var arena=main.run_arena;arena.set_physics_process(false);arena.auto_pause_enabled=false
	for actor in arena.actors:actor.set_physics_process(false)
	arena.phase="paused";preload("res://scripts/ui/pause_tablet.gd").open(arena,arena.pause_battle,arena.leave)
	await shot("/tmp/tank-v20-restart-tablet.png")
	var tablet=get_tree().get_first_node_in_group("field_tablet");assert(tablet and tablet.get_children().any(func(c):return c.get("can_restart")==true))
	tablet.close(false)
	var profile=Game.run_save_baseline.duplicate(true);profile.run_checkpoint=Game.run_checkpoint.duplicate(true)
	main.clear_current();main.run_arena.queue_free();main.run_arena=null;main.current=null
	Game.apply_profile(profile);main._return_hub()
	await get_tree().create_timer(2.5).timeout
	await shot("/tmp/tank-v20-clean-hub.png")
	assert(main.current and main.current.has_method("show_command") and not Game.run_checkpoint.is_empty())
	main.request_run();assert(main.current.build_menu and main.current.build_menu.get_script()==preload("res://scripts/ui/resume_run_dialog.gd"))
	await shot("/tmp/tank-v20-resume-dialog.png")
	print("PASS checkpoint UI: resume dialog and restart tablet")
	main.queue_free();await get_tree().process_frame
	get_tree().quit()
