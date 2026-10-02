extends Node3D
## Window shots of the v1 light fixtures at night: hub stands and wall lamps, battle block lights and corner masts.
## /tmp/r13-lights-*.png. No profile or settings writes.
func settle(n:=3):
	for i in n:await get_tree().process_frame
func shot(name:String):
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-lights-"+name+".png")
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	Settings.values.world_lighting="night"
	get_window().size=Vector2i(1600,900)
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);await settle(60)
	for dialog in get_tree().root.find_children("*","Control",true,false):
		if dialog.has_method("dismiss"):dialog.dismiss()
	hub.set_process(false);var camera=get_viewport().get_camera_3d();camera.set_process(false)
	var stands=hub.find_children("MilitaryLightStand",  "Node3D",true,false)
	var target=stands[0].global_position if not stands.is_empty() else Vector3.ZERO
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=40;camera.global_position=target+Vector3(2.5,2.6,5.5);camera.look_at(target+Vector3(0,1.2,0))
	await settle(20);await shot("hub")
	hub.queue_free();await settle(5)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=6;add_child(arena);arena.auto_pause_enabled=false
	await settle(90);arena.set_physics_process(false)
	camera=get_viewport().get_camera_3d();camera.set_process(false);camera.set_physics_process(false)
	var fixtures=arena.find_children("Floodlight","Node3D",true,false)+arena.find_children("MilitaryLightStand","Node3D",true,false)
	print("FIXTURES ",fixtures.size())
	if not fixtures.is_empty():
		var f=fixtures[0].global_position;camera.size=4.5;camera.global_position=f+Vector3(0,19,14).rotated(Vector3.UP,deg_to_rad(10)).normalized()*20;camera.look_at(f)
	await settle(20);await shot("battle")
	Settings.values.world_lighting="day"
	get_tree().quit()
