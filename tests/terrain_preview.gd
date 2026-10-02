extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.new_recipes.clear();Settings.values.fullscreen=false;Settings.apply();Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=82415
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--biome="):arena.run_seed=82411+int(arg.trim_prefix("--biome="))-1-2
	add_child(arena)
	arena.begin_room(2);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="upgrade"
	for a in arena.actors:a.set_physics_process(false)
	await get_tree().create_timer(2.3).timeout
	# The dummy headless renderer never draws a frame: the snapshot is only taken in a window.
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/terrain-final.png")
	print("PASS terrain visual")
	get_tree().quit()
