extends Node3D
## Window shots of the route map (start and boss end) for the edge/mountain/ruin dressing. /tmp/r13-route-*.png
func _ready():call_deferred("run")
func shot(name:String):
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-route-"+name+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=int(OS.get_environment("R13_SEED")) if OS.get_environment("R13_SEED")!="" else 42;route.available=1;add_child(route)
	await get_tree().create_timer(1.5).timeout;await shot("start")
	route.follow_camera=false;route.scroll=-route.stage_z(route.plan.size()-1)-4;route.move_camera()
	await get_tree().create_timer(1.0).timeout;await shot("boss")
	get_tree().quit()
