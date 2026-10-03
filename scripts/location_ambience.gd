extends Node3D
var biome="forest"
var seed_value=0
var radius=10.0
var miniature=false
var room_index=0
var elapsed=0.0
var silhouettes:Array=[]
## Biome entry of the room (floor, edge, vegetation): the floating islands use its colours and plants.
var palette:Dictionary={}
## Upgrade rooms (2026-10-03): the same biome ground and big shapes, but close around a small room — sides and
## back, smaller shapes, light clouds (fair weather). See room().
var close:=false
var cloud_material:ShaderMaterial
var backdrop_materials:Array=[]
func update_lighting():
	for material in backdrop_materials:
		var color:Color=material.get_meta("day_color")
		# A close room (upgrade rooms) is always in warm daylight, whatever the setting.
		var night=Settings.values.world_lighting=="night" and not close
		# Volumetric silhouettes (0.8): lit faces and half-shadows from the scene light, a soft rim and a faint
		# inner glow. At night they stay darker than the sky behind them.
		material.albedo_color=color.darkened(.8).lerp(Color("0c1220"),.45) if night else color.darkened(.3)
		material.rim=.6 if night else .2;material.rim_tint=.2
		material.emission=(Color("2a3a5c") if night else color.lightened(.25));material.emission_energy_multiplier=.2 if night else .08
var weather=preload("res://assets/weather/default.tres")
func _ready():
	Settings.changed.connect(update_lighting)
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+room_index*7109
	# Battle: 7 per side spread past both ends so the empty left and right are filled; up to twice as big at
	# random, the outer ones are cut by the screen edge. Miniatures (route map) keep the old small set.
	var count=8 if miniature else 10 if close else 14
	# Battle ground (0.8): the board stands on a biome surface with a soft relief, not in the air.
	var ground=null
	if not miniature:
		ground=preload("res://scripts/backdrop_ground.gd").new();ground.name="BackdropGround";add_child(ground)
		ground.setup(palette,biome,radius,seed_value+room_index*7109)
		if get_parent() and get_parent().has_method("room_palette"):
			var approach=preload("res://scripts/field_approach.gd").new();approach.name="FieldApproach";add_child(approach);approach.build(get_parent(),ground,seed_value+room_index*7109)
	var tones:Array=preload("res://scripts/backdrop_ground.gd").colors(palette,biome) if not miniature else []
	for i in range(count):
		var root=Node3D.new();add_child(root)
		var side=-1 if i%2==0 else 1
		var row=floorf(i/2.0)/(count/2.0-1.0)
		var depth=radius*(1.0 if miniature else 1.15 if close else 1.5)
		var scale_value=rng.randf_range(1.5,3.2)*(rng.randf_range(1.0,2.0)) if not miniature else rng.randf_range(.65,1.2)
		if close:scale_value=rng.randf_range(1.3,2.3)
		# A bigger shape stands further out, so its foot never covers the field border.
		var gap=rng.randf_range(2,5) if miniature else 2.0+scale_value*1.05+rng.randf_range(0,2.5)
		if close:gap=1.2+scale_value*.6+rng.randf_range(0,1.0)
		root.position=Vector3(side*(radius+gap), -.7,lerpf(-depth,depth,row)+rng.randf_range(-1,1))
		# The last pair of a close room stands behind it instead, so the back is not empty.
		if close and i>=count-3:root.position=Vector3(lerpf(-radius,radius,float(i-(count-3))/2.0)+rng.randf_range(-.6,.6),-.7,-(radius+gap))
		if ground:root.position.y=ground.height(root.position.x,root.position.z)-.05
		root.scale=Vector3.ONE*scale_value
		var first=backdrop_materials.size()
		if miniature:make_shape(root,rng)
		else:symbol(root,rng)
		# A touch of colour: each shape leans to one of the ground tones, so the sides are not one grey.
		if not tones.is_empty():
			# Low contrast (0.8): the shapes lean strongly to the ground colour and blend into the backdrop.
			var tone:Color=tones[0].lerp(tones[rng.randi()%tones.size()],.4)
			for k in range(first,backdrop_materials.size()):
				var mat:StandardMaterial3D=backdrop_materials[k];mat.set_meta("day_color",Color(mat.get_meta("day_color")).lerp(tone,.7))
			update_lighting()
		silhouettes.append({"node":root,"phase":rng.randf()*TAU,"scale":scale_value,"y":root.position.y})
	if not miniature:
		Game.sound_loop("ambience_"+biome,self)
		var canvas=CanvasLayer.new();canvas.layer=0;add_child(canvas)
		var cloud=ColorRect.new();cloud.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(cloud);cloud.size=get_viewport().get_visible_rect().size
		get_viewport().size_changed.connect(func():if is_inside_tree() and is_instance_valid(cloud):cloud.size=get_viewport().get_visible_rect().size)
		cloud_material=ShaderMaterial.new();cloud_material.shader=preload("res://assets/weather/clouds.gdshader");cloud.material=cloud_material
		cloud_material.set_shader_parameter("coverage",.06 if close else minf(LocationStyle.cloud_cover(room_index),weather.maximum_cover))
		for key in ["opacity","drift_speed","cycle_seconds","minimum_activity"]:cloud_material.set_shader_parameter(key,weather.get(key))
		cloud_material.set_shader_parameter("seed_offset",rng.randf()*6)
## An upgrade room's surroundings: the biome of the field just fought, close around the room, fair weather.
static func room(parent:Node3D,arena,index:int,radius_value:=4.8)->Node3D:
	var palette:Dictionary=arena.room_palette() if is_instance_valid(arena) and arena.has_method("room_palette") else {}
	var node=load("res://scripts/location_ambience.gd").new();node.name="RoomSurroundings"
	node.seed_value=Game.visual_run_seed;node.room_index=index+300;node.biome=str(palette.get("ambience","forest"))
	node.radius=radius_value;node.palette=palette;node.close=true;parent.add_child(node);return node
func mesh(parent,shape,pos,scale_value=Vector3.ONE):
	var node=MeshInstance3D.new();node.mesh=shape;node.position=pos;node.scale=scale_value
	var mat=StandardMaterial3D.new();mat.roughness=.9;mat.rim_enabled=true;mat.emission_enabled=true
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
## Battle backdrop (0.8): abstract low-poly symbols of the biome or the war, mixed — big, simple, faceted.
const WAR_SYMBOLS=["hedgehog","shell","crates","helmet","barrels","mast","wall"]
const BIOME_SYMBOLS={"forest":["pines","pines","boulder"],"desert":["mesa","dune","boulder"],"marsh":["reeds","boulder","dune"],
	"city":["towers","towers","wall"],"mountains":["peak","peak","boulder"],"inferno":["shards","peak","boulder"]}
func symbol(root:Node3D,rng:RandomNumberGenerator):
	var kind=str(WAR_SYMBOLS[rng.randi()%WAR_SYMBOLS.size()]) if rng.randf()<.4 else str(BIOME_SYMBOLS.get(biome,BIOME_SYMBOLS.forest)[rng.randi()%3])
	root.rotation.y=rng.randf()*TAU
	match kind:
		"hedgehog":
			for axis in [Vector3(1,1,0),Vector3(-1,1,0),Vector3(0,1,1)]:
				var beam=prism(root,Vector3(0,.55,0),.09,1.6,4);beam.basis=Basis(Vector3.UP.cross(axis.normalized()).normalized(),Vector3.UP.angle_to(axis.normalized()))
		"shell":
			prism(root,Vector3(0,.55,0),.32,1.1,6);var tip=CylinderMesh.new();tip.top_radius=0;tip.bottom_radius=.32;tip.height=.55;tip.radial_segments=6;mesh(root,tip,Vector3(0,1.38,0))
		"crates":
			box(root,Vector3(0,.35,0),Vector3(.8,.7,.8));box(root,Vector3(.75,.3,.1),Vector3(.6,.6,.6));box(root,Vector3(.2,.95,.05),Vector3(.55,.5,.55))
		"helmet":
			var dome=SphereMesh.new();dome.radius=.8;dome.height=.8;dome.is_hemisphere=true;dome.radial_segments=7;dome.rings=3;mesh(root,dome,Vector3(0,0,0))
			prism(root,Vector3(0,.02,0),.95,.06,7)
		"barrels":
			for i in range(3):prism(root,Vector3((i-1)*.48,.38,(i%2)*.2),.22,.76,7)
			prism(root,Vector3(0,.95,.1),.22,.76,7)
		"mast":
			prism(root,Vector3(0,1.1,0),.05,2.2,4);var head=CylinderMesh.new();head.top_radius=0;head.bottom_radius=.35;head.height=.5;head.radial_segments=3;mesh(root,head,Vector3(0,2.3,0))
		"wall":
			box(root,Vector3(-.5,.45,0),Vector3(1.0,.9,.3));box(root,Vector3(.55,.3,0),Vector3(.9,.6,.3));box(root,Vector3(.15,.12,.45),Vector3(.5,.24,.4))
		"pines":
			for i in range(rng.randi_range(2,3)):cone(root,Vector3(i*.55-.5,.7+i*.1,(i%2)*.3),.45,1.4+i*.3)
		"boulder":
			var rock=SphereMesh.new();rock.radius=.7;rock.height=1.0;rock.radial_segments=5;rock.rings=2;mesh(root,rock,Vector3(0,.35,0),Vector3(1.3,1,1))
		"mesa":
			prism(root,Vector3(0,.45,0),.9,.9,6).mesh.top_radius=.7
		"dune":
			var hill=SphereMesh.new();hill.radius=1.0;hill.height=1.0;hill.is_hemisphere=true;hill.radial_segments=6;hill.rings=2;mesh(root,hill,Vector3(0,0,0),Vector3(1.6,.6,1))
		"reeds":
			for i in range(5):prism(root,Vector3((i-2)*.22,.6+(i%2)*.15,(i%3)*.12),.05,1.2+(i%2)*.3,4)
		"towers":
			box(root,Vector3(0,.9,0),Vector3(.7,1.8,.7));box(root,Vector3(.65,.55,.2),Vector3(.5,1.1,.5))
		"peak":
			cone(root,Vector3(0,.9,0),1.0,1.8);cone(root,Vector3(.75,.45,.3),.6,.9)
		"shards":
			for i in range(3):
				var shard=CylinderMesh.new();shard.top_radius=0;shard.bottom_radius=.25;shard.height=1.2+i*.4;shard.radial_segments=4;mesh(root,shard,Vector3((i-1)*.4,.6+i*.2,0))
				root.get_child(root.get_child_count()-1).rotation.z=(i-1)*.25
func prism(parent:Node3D,pos:Vector3,radius_value:float,height:float,sides:int)->MeshInstance3D:
	var shape=CylinderMesh.new();shape.top_radius=radius_value;shape.bottom_radius=radius_value;shape.height=height;shape.radial_segments=sides;shape.rings=1
	mesh(parent,shape,pos);return parent.get_child(parent.get_child_count()-1)
func _process(delta):
	elapsed+=delta
	for item in silhouettes:
		item.node.rotation.z=sin(elapsed*TAU/80+item.phase)*.014
		item.node.position.y=float(item.get("y",-.7))+(sin(elapsed*TAU/95+item.phase)*.045 if miniature else 0.0)
	if cloud_material:cloud_material.set_shader_parameter("elapsed",elapsed)
