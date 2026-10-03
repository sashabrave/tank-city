extends Node
## Hub range lane and bigger track. /tmp/r13-range.png
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	get_window().size=Vector2i(1600,900)
	for id in ["yard","range","garage"]:
		if id not in Game.built_workshops:Game.built_workshops.append(id)
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(1.4).timeout
	for ring in hub.find_children("IncomingCall","",true,false):ring.queue_free()
	hub.avatar.position=hub.FIRING_SPOT;hub.cell=Vector2i(roundi(hub.FIRING_SPOT.x),roundi(hub.FIRING_SPOT.z));hub.destination=hub.avatar.position
	await get_tree().create_timer(1.6).timeout
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-range.png")
	get_tree().quit(0)
