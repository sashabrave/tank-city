extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Game.apply_profile(Game.fresh_profile.duplicate(true));Settings.values.fullscreen=false;Settings.apply()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	arena.presentation.text_tween.kill();arena.presentation.heading.hide();arena.presentation.caption.hide();arena.phase="combat"
	Game.progression.tracked=["first_alloy","institute_character"];Game.progression.accepted=Game.progression.tracked.duplicate()
	Game.progression.tracker_collapsed=false
	arena.wave_roster.clear()
	for i in range(5):arena.wave_roster.append({"kind":"soldier","state":"queued"})
	await get_tree().create_timer(.4).timeout
	var expanded=arena.hud.right_info.size.y
	Game.progression.tracker_collapsed=true
	await get_tree().create_timer(.4).timeout
	assert(arena.hud.right_info.size.y<expanded)
	var collapsed=arena.hud.right_info.size.y
	for i in range(8):arena.wave_roster.append({"kind":"tank","state":"queued"})
	await get_tree().create_timer(.4).timeout
	assert(is_equal_approx(arena.hud.right_info.size.y,collapsed+64))
	arena.wave_roster[0].state="active";arena.wave_roster[1].state="dead"
	Game.progression.tracker_collapsed=false
	await get_tree().create_timer(.4).timeout
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/tank-wave-panel.png")
	print("PASS wave panel: collapse, expansion, additional roster rows")
	get_tree().quit()
