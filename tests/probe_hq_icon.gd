extends Node
## Tool: renders the mobile HQ (the «base» model) into a transparent icon for the base health meter (T-117),
## in an offscreen SubViewport so no HUD overlay gets in. Output: /tmp/r13-hq-icon.png (512×512).
func _ready():call_deferred("run")
func run():
	var vp=SubViewport.new();vp.size=Vector2i(512,512);vp.transparent_bg=true;vp.own_world_3d=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(vp)
	var root=Node3D.new();vp.add_child(root)
	var env=WorldEnvironment.new();root.add_child(env);env.environment=Environment.new();env.environment.background_mode=Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("c8d0dc");env.environment.ambient_light_energy=.9;env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var sun=DirectionalLight3D.new();root.add_child(sun);sun.rotation_degrees=Vector3(-48,-40,0);sun.light_energy=1.3
	var rim=DirectionalLight3D.new();root.add_child(rim);rim.rotation_degrees=Vector3(-20,150,0);rim.light_energy=.5;rim.light_color=Color("b8ccff")
	var model=Visuals.model("base",root,Vector3.ZERO);model.rotation_degrees.y=60
	var box=Visuals.mesh_bounds(model,Transform3D.IDENTITY)
	var cam=Camera3D.new();root.add_child(cam);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=maxf(box.size.x,maxf(box.size.y,box.size.z))*1.35
	var c=box.get_center();cam.position=c+Vector3(0,3.2,6);cam.look_at(c);cam.current=true
	for i in range(12):await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png("/tmp/r13-hq-icon.png");get_tree().quit()
