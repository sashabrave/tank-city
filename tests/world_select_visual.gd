extends Node
## World select right after opening: the default world card and ladder step are framed. /tmp/r13-world-select.png
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	get_window().size=Vector2i(1600,900)
	var picker=load("res://scripts/ui/world_select.gd").new();add_child(picker)
	await get_tree().create_timer(.6).timeout
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-world-select.png")
	get_tree().quit(0)
