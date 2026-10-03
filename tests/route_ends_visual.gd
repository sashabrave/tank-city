extends Node3D
## Route map ends: the static garage at the start and the pass at the top. /tmp/r13-route-start.png, -top.png.
func _ready():call_deferred("run")
func shot(path):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(path)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=5;add_child(route)
	await get_tree().create_timer(1.6).timeout
	await shot("/tmp/r13-route-start.png")
	route.follow_camera=false;route.scroll=-route.stage_z(route.plan.size()-1)+11;route.move_camera()
	await get_tree().create_timer(.5).timeout
	await shot("/tmp/r13-route-top.png")
	get_tree().quit(0)
