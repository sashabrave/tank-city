extends Node3D
## Probe: an original model and its AO-baked copy side by side, /tmp/r13-aomodels.png.
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false
	var env=WorldEnvironment.new();add_child(env);env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("c9c3b0")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("b8c0d8");env.environment.ambient_light_energy=.7;env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var sun=DirectionalLight3D.new();add_child(sun);sun.rotation_degrees=Vector3(-50,-35,0);sun.light_energy=1.0;sun.shadow_enabled=true
	var floor=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(12,12);floor.mesh=plane;add_child(floor);var fm=StandardMaterial3D.new();fm.albedo_color=Color("b9ad8f");floor.material_override=fm
	var names=OS.get_cmdline_user_args()
	var a=load("res://assets/models/vehicles_v6/"+names[0]+".glb").instantiate();add_child(a);a.position=Vector3(-1.1,0,0)
	var b=load("res://assets/models/vehicles_v6/"+names[1]+".glb").instantiate();add_child(b);b.position=Vector3(1.1,0,0)
	for m in [a,b]:m.rotation_degrees.y=35
	var cam=Camera3D.new();add_child(cam);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=3.2;cam.position=Vector3(0,3.2,3.6);cam.look_at(Vector3(0,.25,0));cam.current=true
	get_window().size=Vector2i(1400,700)
	for i in range(8):await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/r13-aomodels.png");get_tree().quit()
