extends Node3D
## Night field: lamps, beams and shadows. Window shot /tmp/r13-night.png.
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	Settings.values.world_lighting="night";Settings.values.sun_night="moon";Settings.values.weather="clear"
	get_window().size=Vector2i(1600,900)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=21;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.6).timeout;arena.set_physics_process(false)
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-night.png")
	Settings.values.world_lighting="day";Settings.values.sun_night="random";Settings.values.weather="random"
	get_tree().quit(0)
