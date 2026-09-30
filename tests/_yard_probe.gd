extends Node
func _ready():
	Game.save_enabled=false;Settings.persistence_enabled=false
	Game.built_workshops=["garage","range"]
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(3.5).timeout
	hub.avatar.position=Vector3(14,0,0);hub.cell=Vector2i(14,0);hub.destination=hub.avatar.position
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS")+"/yard.png")
	get_tree().quit()
