extends Node
## Window close-up of the hub command screen dashboard (idle and news). Saves /tmp/r13-command-*.png.
## No profile or settings writes.
func _ready():call_deferred("run")
func settle(n:=3):
	for i in n:await get_tree().process_frame
func shot(name:String):
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-command-"+name+".png")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	get_window().size=Vector2i(1600,900)
	var hub=preload("res://scripts/hub.gd").open_practice(self);await settle(60)
	for dialog in get_tree().root.find_children("*","Control",true,false):
		if dialog.has_method("dismiss"):dialog.dismiss()
	hub.set_process(false);hub.set_physics_process(false);hub.arena.presentation.set_process(false)  # the hub camera is the arena presentation's now
	var camera=get_viewport().get_camera_3d();camera.set_process(false);camera.set_physics_process(false)
	var focus=hub.command_model.global_position+Vector3(0,1.3,0)
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=40
	camera.global_position=focus+Vector3(0,.3,3.6);camera.look_at(focus);await settle(30)
	hub.command_screen.set_shader_parameter("alert",false);await settle(20);await shot("idle")
	await settle(50);await shot("idle2")
	hub.command_screen.set_shader_parameter("alert",true);await settle(10);await shot("alert")
	print("COMMAND done");get_tree().quit()
