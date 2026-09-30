extends Node
func _ready():call_deferred("run")
func shot(name):
	await get_tree().create_timer(.2).timeout;RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png("/tmp/route-roof-"+name+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=92;add_child(route)
	await get_tree().create_timer(1.8).timeout;await shot("start")
	route.scroll=8;route.move_camera();await shot("scroll")
	route.scroll=0;route.move_camera();route.travel_to_room(0,route.reachable[0])
	await get_tree().create_timer(1).timeout;await shot("entry")
	route.cancel_entry();await get_tree().create_timer(.7).timeout
	assert(route.foreground_hangar.position.is_equal_approx(route.foreground_hangar.HOME))
	print("PASS roof scroll, entry zoom and return; enlarged HQ")
	get_tree().quit()
