extends Node3D
## HQ vehicle rear (art_requests/hq_vehicle_v2): rear details, two red taillight pillars lit by the rig, wheels and dish
## still found by mobile_hq.gd. Window shot /tmp/r13-hq-rear.png. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	get_window().size=Vector2i(1600,900)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("d8d4cc");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("b8b6b0");env.environment.ambient_light_energy=.6;add_child(env)
	var sun=DirectionalLight3D.new();add_child(sun);sun.rotation_degrees=Vector3(-50,150,0);sun.light_energy=1.1;sun.shadow_enabled=true
	var hq=Visuals.model("base",self);hq.scale=Vector3.ONE*1.6
	await get_tree().create_timer(.3).timeout
	check(hq.find_children("Taillight pillar*","MeshInstance3D",true,false).size()>=2,"two red pillars on the model")
	check(hq.get_node_or_null("TaillightRig")!=null and hq.get_node("TaillightRig").find_children("*","SpotLight3D",true,false).size()==2,"rig lights the pillars")
	check(hq.find_children("Red taillamp*","",true,false).is_empty(),"no extra red boxes")
	check(not hq.find_children("WheelPivot*","Node3D",true,false).is_empty(),"wheel pivots still there")
	check(hq.find_child("RadarDish",true,false)!=null,"radar dish still there")
	var cam=Camera3D.new();add_child(cam);cam.fov=30;cam.position=Vector3(2.6,3.2,-5.4);cam.look_at(Vector3(0,1.0,0));cam.current=true
	await get_tree().create_timer(.4).timeout
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-hq-rear.png")
	print("HQ REAR: %d failures" % failures);get_tree().quit(1 if failures else 0)
