extends Node
## Quest page with vertical filter tabs. /tmp/r13-quest-tabs.png
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	get_window().size=Vector2i(1600,900)
	var memory=preload("res://scripts/ui/tablet_memory.gd");memory.loaded=true;memory.state={}
	Game.progression.accept_quest("first_alloy")
	var view=preload("res://scripts/ui/field_tablet.gd").new();view.manage=true;view.tab="quests";add_child(view)
	await get_tree().create_timer(.8).timeout
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-quest-tabs.png")
	get_tree().quit(0)
