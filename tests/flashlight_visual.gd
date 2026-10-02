extends Node
## Hub at night: the soldier's chest flashlight while running (soft beam edge, steadied light). Window shots /tmp/r13-flash-*.png.
func _ready():call_deferred("run")
func shot(label:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/r13-flash-"+label+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.values.world_lighting="night";Settings.apply()
	var hub=load("res://scenes/hub.tscn").instantiate()
	add_child(hub);await get_tree().create_timer(1.0).timeout
	hub.phase="combat";hub.avatar.position=Vector3(2,0,1);hub.moving=false
	var camera=hub.get_viewport().get_camera_3d();camera.size=6.5;camera.position=Vector3(4,8,7);camera.look_at(Vector3(4,.4,1))
	await shot("idle")
	assert(PerfOverlay.label.size.x>100 and PerfOverlay.label.text.contains("FPS"),"build and FPS line readable in the corner")
	Input.action_press("east");await get_tree().create_timer(.3).timeout
	var steady=hub.avatar.find_child("SteadyBeam",true,false)
	assert(steady!=null,"flashlight beam rides a steadied mount")
	await shot("run-a");await get_tree().create_timer(.17).timeout;await shot("run-b")
	Input.action_release("east")
	print("FLASHLIGHT VISUAL PASS")
	get_tree().quit()
