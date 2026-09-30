extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.visual_run_seed=42
	var route=load("res://scripts/route_map.gd").new();route.available=12;route.wave_seed=42;route.hero_kind="soldier";route.hero_weapon="rifle";add_child(route)
	await get_tree().create_timer(.4).timeout
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/route_wave_preview/route.png")
	route.camera.size=10;route.camera.position=Vector3(0,11,-12*14+8);route.camera.look_at(Vector3(0,0,-12*14+.5))
	route.root.hide()
	await get_tree().create_timer(.2).timeout
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/route_wave_preview/room_detail.png")
	get_tree().quit()
