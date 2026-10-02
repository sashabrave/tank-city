extends MultiMeshInstance3D
## Catnip gas: a low cluster of soft camera-facing puffs drawn with the edge-cloud shader
## (shaders/world/map_clouds.gdshader), tinted green. The same cloud is used in battle, sandbox and the hub
## training. Visual only: puff layout uses its own RNG, never the fight's.
var radius=1.5
var opacity=.0
var target_opacity=.62
var fading=false
func _init(cloud_radius:float=1.5,seed_value:int=0):
	radius=cloud_radius;name="GasCloud"
	var rng=RandomNumberGenerator.new();rng.seed=hash([seed_value,"gas_cloud"])
	var count=10+int(radius*3)
	var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true
	var quad=QuadMesh.new();quad.size=Vector2.ONE;multi.mesh=quad;multi.instance_count=count
	for i in range(count):
		var a=rng.randf()*TAU;var d=sqrt(rng.randf())*radius*.8
		var size=rng.randf_range(.9,1.4)*(1.0+radius*.18)
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),Vector3(cos(a)*d,rng.randf_range(.25,.75),sin(a)*d)))
		multi.set_instance_custom_data(i,Color(rng.randf_range(.55,.95),rng.randf(),0,1))
	multimesh=multi;cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;extra_cull_margin=2
	var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/world/map_clouds.gdshader")
	mat.set_shader_parameter("light_color",Color("d9ecb8"));mat.set_shader_parameter("shade_color",Color("7f9f6c"));mat.set_shader_parameter("opacity",0.0)
	material_override=mat
func fade_out():fading=true
func _process(delta):
	opacity=move_toward(opacity,0.0 if fading else target_opacity,delta*(1.2 if fading else 2.0))
	material_override.set_shader_parameter("opacity",opacity)
	rotation.y+=delta*.05
	if fading and opacity<=0.0:queue_free()
