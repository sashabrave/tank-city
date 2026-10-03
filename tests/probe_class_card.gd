extends Node
## Probe: Barracks class card with two abilities and level actions, /tmp/r13-classcard.png.
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	get_window().size=Vector2i(1280,720)
	Game.class_first_slots=["recruit"];Game.class_levels["recruit"]=2
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(1.2).timeout
	hub.open_station("fighter");await get_tree().create_timer(.3).timeout
	var screen=hub.build_menu;screen.tab="shells";screen.selected="recruit";screen.build();await get_tree().create_timer(.6).timeout
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-classcard.png")
	get_tree().quit()
