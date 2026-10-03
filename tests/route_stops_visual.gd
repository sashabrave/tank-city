extends Node3D
## Close window shots of every Blender route stop as the route map builds it (models, game vehicles toned neutral).
## /tmp/r13-stop-<name>.png. No profile or settings writes.
const MINI=preload("res://scripts/route_miniatures.gd")
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("e8e4de");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("c9c6c0");env.environment.ambient_light_energy=.7;add_child(env)
	var sun=DirectionalLight3D.new();add_child(sun);sun.rotation_degrees=Vector3(-50,-35,0);sun.light_energy=1.2;sun.shadow_enabled=true
	var cam=Camera3D.new();add_child(cam);cam.fov=26;cam.position=Vector3(-4.5,7.5,12.0);cam.look_at(Vector3(0,1,0));cam.current=true
	for item in [["merchant","MerchantShop"],["training","TrainingPoint"],["mechanic","MechanicPoint"],["workshop","WorkshopPoint"],["command_post","CommandPostPoint"]]:
		var holder=Node3D.new();add_child(holder)
		match item[0]:
			"merchant":MINI.merchant(holder)
			"training":MINI.service(holder,false,Color("a99b79"))
			"mechanic":MINI.service(holder,true,Color("839c9f"))
			"workshop":MINI.depot(holder)
			"command_post":MINI.command_post(holder)
		var model=holder.get_node_or_null(item[1])
		if model==null:holder.queue_free();continue
		if item[0] in ["workshop","mechanic"]:check(model.get_node_or_null("GameVehicle")!=null,item[0]+": game vehicle in the scene")
		await get_tree().create_timer(.4).timeout
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-stop-%s.png" % item[0])
		holder.queue_free();await get_tree().process_frame
	print("ROUTE STOPS: %d failures" % failures);get_tree().quit(1 if failures else 0)
