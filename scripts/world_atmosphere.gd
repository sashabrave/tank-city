extends Node3D
## Three small GPU batches; no per-particle processing, physics or light sources.
var materials:Array=[]
var batches:Array=[]
var tilt:CanvasLayer
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	var rng=RandomNumberGenerator.new();rng.seed=74983
	for kind in range(3):
		var multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_custom_data=true
		var quad=QuadMesh.new();quad.size=Vector2.ONE;multimesh.mesh=quad;multimesh.instance_count=[26,10,7][kind]
		for i in range(multimesh.instance_count):
			var scale_value=rng.randf_range(.04,.10) if kind!=2 else rng.randf_range(.07,.12)
			multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_value),Vector3(rng.randf_range(-11,11),rng.randf_range(.3,3.5),rng.randf_range(-9,9))))
			multimesh.set_instance_custom_data(i,Color(rng.randf(),0,0,1))
		var batch=MultiMeshInstance3D.new();batch.multimesh=multimesh;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;batch.extra_cull_margin=3
		var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/world/atmosphere.gdshader");mat.set_shader_parameter("kind",kind);batch.material_override=mat;add_child(batch);materials.append(mat);batches.append(batch)
	tilt=CanvasLayer.new();tilt.layer=0;add_child(tilt)
	var overlay=ColorRect.new();tilt.add_child(overlay);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material=ShaderMaterial.new();material.shader=preload("res://shaders/world/tilt_edges.gdshader");overlay.material=material
	Settings.changed.connect(apply);apply()
func apply():
	var night=Settings.values.world_lighting=="night"
	for mat in materials:mat.set_shader_parameter("night",night)
	var biome="forest"
	if get_parent().has_method("room_palette"):biome=get_parent().room_palette().ambience
	materials[2].set_shader_parameter("strength",1.0 if biome in ["forest","marsh","city"] else 0.0)
	for batch in batches:batch.visible=Settings.values.get("atmosphere",true)
	tilt.visible=Settings.values.get("tilt_shift",true) and Settings.values.get("shaders",true)
func _process(_delta):
	var camera=get_viewport().get_camera_3d()
	if camera:
		var forward=-camera.global_basis.z
		var center=camera.global_position+forward*(camera.global_position.y/maxf(.1,-forward.y))
		global_position=Vector3(center.x,0,center.z)

func anchor_to_map(length:float):
	# Cover the complete scrolling map once; camera movement never repositions dust.
	set_process(false);position=Vector3(0,0,-length*.5)
	var rng=RandomNumberGenerator.new();rng.seed=74983
	for kind in range(batches.size()):
		var multi=batches[kind].multimesh
		multi.instance_count=ceili([7,10,7][kind]*maxf(1.0,(length+18)/18.0))
		materials[kind].set_shader_parameter("near_bokeh",kind==0)
		for i in range(multi.instance_count):
			var size=rng.randf_range(.55,1.15) if kind==0 else rng.randf_range(.04,.10) if kind==1 else rng.randf_range(.07,.12)
			var height=rng.randf_range(11.5,15.5) if kind==0 else rng.randf_range(.3,3.5)
			multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),Vector3(rng.randf_range(-13,13),height,rng.randf_range(-length*.5-9,length*.5+15))))
			multi.set_instance_custom_data(i,Color(rng.randf(),0,0,1))
