extends Node3D
var biome="forest"
var seed_value=0
var radius=10.0
var miniature=false
var room_index=0
var elapsed=0.0
var silhouettes:Array=[]
var cloud_material:ShaderMaterial
var backdrop_materials:Array=[]
func update_lighting():
	for material in backdrop_materials:
		var color:Color=material.get_meta("day_color")
		var night=Settings.values.world_lighting=="night"
		# At night the silhouettes must read darker than the sky behind them (author, 0.8): unlit, near-black blue.
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED if night else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		material.albedo_color=color.darkened(.9).lerp(Color("080b14"),.6) if night else color
var weather=preload("res://assets/weather/default.tres")
func _ready():
	Settings.changed.connect(update_lighting)
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+room_index*7109
	for i in range(8 if miniature else 8):
		var root=Node3D.new();add_child(root)
		var side=-1 if i%2==0 else 1
		root.position=Vector3(side*(radius+rng.randf_range(2,5)), -.7,lerpf(-radius,radius,floorf(i/2.0)/3.0)+rng.randf_range(-1,1))
		var scale_value=rng.randf_range(1.5,3.2) if not miniature else rng.randf_range(.65,1.2)
		root.scale=Vector3.ONE*scale_value
		make_shape(root,rng)
		silhouettes.append({"node":root,"phase":rng.randf()*TAU,"scale":scale_value})
	if not miniature:
		Game.sound_loop("ambience_"+biome,self)
		var canvas=CanvasLayer.new();canvas.layer=0;add_child(canvas)
		var cloud=ColorRect.new();cloud.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(cloud);cloud.size=get_viewport().get_visible_rect().size
		get_viewport().size_changed.connect(func():if is_inside_tree() and is_instance_valid(cloud):cloud.size=get_viewport().get_visible_rect().size)
		cloud_material=ShaderMaterial.new();cloud_material.shader=preload("res://assets/weather/clouds.gdshader");cloud.material=cloud_material
		cloud_material.set_shader_parameter("coverage",minf(LocationStyle.cloud_cover(room_index),weather.maximum_cover))
		for key in ["opacity","drift_speed","cycle_seconds","minimum_activity"]:cloud_material.set_shader_parameter(key,weather.get(key))
		cloud_material.set_shader_parameter("seed_offset",rng.randf()*6)
func mesh(parent,shape,pos,scale_value=Vector3.ONE):
	var node=MeshInstance3D.new();node.mesh=shape;node.position=pos;node.scale=scale_value
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=Color("bec3b8").lerp(LocationStyle.COLORS[biome],.27 if not miniature else .55)
	mat.set_meta("day_color",mat.albedo_color);backdrop_materials.append(mat);update_lighting()
	node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node)
func cone(parent,pos,width,height):
	var shape=CylinderMesh.new();shape.top_radius=0;shape.bottom_radius=width;shape.height=height;shape.radial_segments=5;mesh(parent,shape,pos)
func box(parent,pos,size_value):
	var shape=BoxMesh.new();shape.size=size_value;mesh(parent,shape,pos)
func make_shape(root,rng):
	match biome:
		"forest":
			box(root,Vector3(0,.5,0),Vector3(.12,1,.12))
			cone(root,Vector3(0,1.2,0),.7,1.4);cone(root,Vector3(0,1.8,0),.5,1.1)
		"city":
			box(root,Vector3(0,.8,0),Vector3(.8,1.6,.7));box(root,Vector3(.55,.5,.2),Vector3(.5,1,.55))
			box(root,Vector3(0,1.9,0),Vector3(.06,.6,.06))
		"mountains":cone(root,Vector3(0,.8,0),1.1,2.4);cone(root,Vector3(.8,.25,.3),.7,1.4)
		"desert":
			var sphere=SphereMesh.new();mesh(root,sphere,Vector3(0,0,0),Vector3(2,.4,1.1))
			box(root,Vector3(.4,.75,0),Vector3(.16,1.5,.16));box(root,Vector3(.65,.85,0),Vector3(.5,.12,.12))
		"marsh":
			for j in range(3):box(root,Vector3(j*.3,.7,rng.randf()*.3),Vector3(.035,1.4,.035));box(root,Vector3(j*.3,1.35,0),Vector3(.1,.3,.1))
		"inferno":
			cone(root,Vector3(0,.6,0),.9,1.8);cone(root,Vector3(.6,1,.2),.3,2.4)
func _process(delta):
	elapsed+=delta
	for item in silhouettes:
		item.node.rotation.z=sin(elapsed*TAU/80+item.phase)*.014
		item.node.position.y=-.7+sin(elapsed*TAU/95+item.phase)*.045
	if cloud_material:cloud_material.set_shader_parameter("elapsed",elapsed)
