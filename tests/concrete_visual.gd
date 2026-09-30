extends Node3D
func _ready():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Settings.values.fullscreen=false;Settings.apply()
	Visuals.setup_world(self,5.5,Vector3(0,.3,0))
	set_meta("environment_floor",Color("92958e"))
	Visuals.box(self,Vector3(0,-.12,0),Vector3(5,.2,4),Color("92958e"))
	for i in range(2):Visuals.model("concrete_%d" % i,self,Vector3((i-.5)*1.4,0,0))
	for i in range(4):Visuals.model("concrete_0_half_%d" % i,self,Vector3((i-1.5)*1.1,0,1.5))
	await get_tree().create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/concrete-pressed.png")
	print("PASS imported concrete models")
	get_tree().quit()
