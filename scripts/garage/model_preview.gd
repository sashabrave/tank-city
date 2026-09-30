extends SubViewportContainer
var kind="buggy"
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE;stretch=true
	var viewport=SubViewport.new();viewport.size=Vector2i(180,140);viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var world=Node3D.new();viewport.add_child(world)
	var model=Visuals.model(kind,world);model.rotation.y=PI*.8
	var light=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-55,-35,0);light.light_energy=1.0
	var env=WorldEnvironment.new();world.add_child(env);env.environment=Environment.new();env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.75;env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var camera=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.7;camera.position=Vector3(2,2.5,3.5);camera.look_at(Vector3(0,.4,0))
