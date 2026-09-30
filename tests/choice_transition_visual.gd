extends Node3D
func shot(name:String):
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/choice_transition/"+name+".png")
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=0;route.available=1;add_child(route)
	await get_tree().create_timer(.8).timeout;shot("map")
	route.queue_free();await get_tree().process_frame
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	for actor in arena.actors:actor.set_physics_process(false)
	arena.phase="combat";arena.wave=0;arena.flow.finish_wave()
	await get_tree().create_timer(.6).timeout;shot("status")
	await get_tree().create_timer(1.3).timeout;shot("cards")
	get_tree().quit()
