extends Node
## Settings → «Графика» and «Экран» tabs. Window shots /tmp/r13-settings-*.png.
func _ready():call_deferred("run")
func shot(path):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(path)
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	get_window().size=Vector2i(1600,900)
	var memory=preload("res://scripts/ui/tablet_memory.gd");memory.loaded=true;memory.state={}
	var view=preload("res://scripts/ui/field_tablet.gd").new();view.tab="settings";view.settings_tab="Графика";add_child(view)
	await get_tree().create_timer(.6).timeout
	await shot("/tmp/r13-settings-graphics.png")
	view.settings_tab="Экран";view.refresh();await get_tree().create_timer(.4).timeout
	await shot("/tmp/r13-settings-screen.png")
	get_tree().quit(0)
