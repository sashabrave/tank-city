extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	for actor in arena.actors:actor.set_physics_process(false)
	arena.presentation.text_tween.kill();arena.presentation.heading.hide();arena.presentation.caption.hide();arena.phase="combat";arena.wave_roster.clear()
	for kind in ["soldier","grenadier","shield","sniper","tank","apc","buggy","flyer","drone","mortar","boss"]:arena.wave_roster.append({"kind":kind,"state":"queued"})
	await get_tree().create_timer(.7).timeout
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://audio_demo/music_expansion/roster.png")
	get_tree().quit()
