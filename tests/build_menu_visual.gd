extends Node
## Build menu and HQ «Постройки» tab with the building miniatures. Window shots /tmp/r13-build-*.png.
func _ready():call_deferred("run")
func shot(path):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(path)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	get_window().size=Vector2i(1600,900)
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(1.2).timeout
	hub.show_build_menu();await get_tree().create_timer(.6).timeout
	await shot("/tmp/r13-build-menu.png")
	hub.close_station();if "headquarters" not in Game.built_workshops:Game.built_workshops.append("headquarters")
	hub.open_station("hq");await get_tree().create_timer(.4).timeout
	var screen=hub.build_menu
	if screen and screen.has_method("select_tab"):screen.select_tab("buildings")
	await get_tree().create_timer(.4).timeout
	await shot("/tmp/r13-build-hq.png")
	get_tree().quit(0)
