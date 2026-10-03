extends Node3D
## Room machines up close (medkit, ammo gacha, slot machine) in room daylight. /tmp/r13-machines.png
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	get_window().size=Vector2i(1600,900)
	Visuals.setup_world(self,11.4,Vector3.ZERO)
	var positions=[]
	for x in range(-3,4):
		for z in range(-1,3):positions.append(Vector3(x,0,z))
	Visuals.tiled_floor(self,positions,Color("98917f"))
	preload("res://scripts/medkit_vendor.gd").place(self,null,Vector3(-1.6,0,0))
	preload("res://scripts/ammo_vendor.gd").place(self,null,Vector3(0,0,0))
	preload("res://scripts/slot_machine.gd").place(self,null,Vector3(1.7,0,0))
	var cam=Camera3D.new();add_child(cam);cam.position=Vector3(0,2.6,4.6);cam.look_at(Vector3(0,1.0,0));cam.fov=45;cam.current=true
	for i in range(30):await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-machines.png")
	get_tree().quit(0)
