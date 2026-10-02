extends Node3D
## Water and rain puddles: window shot /tmp/r13-water.png of a field with water under rain.
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	Settings.values.weather="rain";Settings.values.sun_day="golden"
	get_window().size=Vector2i(1600,900)
	var seed_value=1
	for s in range(1,300):
		if "water" in preload("res://scripts/biome_catalog.gd").entry(s,3).kinds:seed_value=s;break
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=seed_value;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(.6).timeout;arena.begin_room(3)
	await get_tree().create_timer(1.6).timeout;arena.set_physics_process(false)
	print("WATER cells ",arena.terrain.patches.values().count("water"))
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-water.png")
	Settings.values.weather="random";Settings.values.sun_day="random"
	get_tree().quit(0)
