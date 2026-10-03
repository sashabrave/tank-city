extends Node
## Barracks general tab and HQ defence tab with the drawn upgrade icons. /tmp/r13-station-*.png
func _ready():call_deferred("run")
func shot(path):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(path)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	get_window().size=Vector2i(1600,900)
	if "headquarters" not in Game.built_workshops:Game.built_workshops.append("headquarters")
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(1.2).timeout
	hub.open_station("fighter");await get_tree().create_timer(.3).timeout
	var screen=hub.build_menu;screen.tab="general";screen.selected="";screen.build();await get_tree().create_timer(.5).timeout
	await shot("/tmp/r13-station-fighter.png")
	if "recruit" not in Game.class_second_slots:Game.class_second_slots.append("recruit")
	screen.tab="shells";screen.selected="recruit";screen.build();await get_tree().create_timer(.5).timeout
	await shot("/tmp/r13-station-class.png")
	hub.close_station();hub.open_station("hq");await get_tree().create_timer(.3).timeout
	screen=hub.build_menu;screen.tab=screen.provider.tabs()[1][0];screen.selected="";screen.build();await get_tree().create_timer(.5).timeout
	await shot("/tmp/r13-station-hq.png")
	get_tree().quit(0)
