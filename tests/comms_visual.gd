extends Node
## «Связь» page: call history. /tmp/r13-comms.png
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	get_window().size=Vector2i(1600,900)
	var memory=preload("res://scripts/ui/tablet_memory.gd");memory.loaded=true;memory.state={}
	for id in ["intro","first_death","first_haul"]:
		if "call_"+id not in Game.progression.seen:Game.progression.seen.append("call_"+id)
	var view=preload("res://scripts/ui/field_tablet.gd").new();view.tab="notifications";add_child(view)
	await get_tree().create_timer(.8).timeout
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-comms.png")
	get_tree().quit(0)
