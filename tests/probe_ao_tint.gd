extends Node3D
## Probe: night field with the floor AO overlay shown and hidden (same light), /tmp/r13-ao-on.png / -off.png.
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	Settings.values.world_lighting="night";Settings.values.weather="clear";Settings.values.sun_night="moon"
	get_window().size=Vector2i(1600,900)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=21;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.6).timeout;arena.set_physics_process(false)
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-ao-on.png")
	arena.get_node("FloorAO").visible=false
	for i in range(3):await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/r13-ao-off.png")
	get_tree().quit()
