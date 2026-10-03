extends RefCounted
## Sparse visual-only scenery, outside the authored gameplay grid.
## Light stands (tools/build_lights_v1.py): a tall lattice mast on the ground, a field tripod on block tops.
## One spotlight per stand sits in the modelled lamp heads (Godot -Z is the lamp side).
const STANDS={"light_mast":{"anchor":Vector3(0,2.62,-.2),"tilt":-50.0,"range":8.0,"angle":31.0},"light_tripod":{"anchor":Vector3(0,1.5,-.16),"tilt":-47.0,"range":6.0,"angle":30.0}}
static func lamp(parent:Node3D,pos:Vector3,yaw_jitter:=0.0):
	var rig=Node3D.new();rig.name="MilitaryLightStand";parent.add_child(rig);rig.position=pos
	rig.rotation.y=atan2(rig.global_position.x,rig.global_position.z)+yaw_jitter
	var kind="light_tripod" if pos.y>=.5 else "light_mast"
	Visuals.model(kind,rig)
	var spec=STANDS[kind]
	var light=preload("res://scripts/world_lighting.gd").beam(rig,spec.anchor,true,1)
	light.rotation.x=deg_to_rad(spec.tilt);light.spot_range=spec.range;light.spot_angle=spec.angle;light.set_meta("day_energy",.15);light.set_meta("night_energy",1.9)
	# Night pools (0.8): a narrower, brighter cone that falls off with distance lights a patch, not the field.
	light.spot_attenuation=1.6;light.spot_angle_attenuation=1.4
static func tree(parent:Node3D,pos:Vector3,height:float):
	Visuals.box(parent,pos+Vector3.UP*height*.23,Vector3(height*.08,height*.46,height*.08),Color("665641"))
	for i in range(3):
		var shape=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=height*.025;mesh.bottom_radius=height*(.30-.06*i);mesh.height=height*(.55-.07*i);mesh.radial_segments=8
		shape.mesh=mesh;shape.material_override=Visuals.material(Color("526852").lightened(i*.035));parent.add_child(shape);shape.position=pos+Vector3.UP*height*(.38+i*.22)

static func hub(parent:Node3D,ground:=Color("7c8176")):
	var decor=Node3D.new();decor.name="SparseSurroundings";parent.add_child(decor)
	Visuals.box(decor,Vector3(1,-.78,0),Vector3(44,.12,34),ground)
	for x in [-7.0,9.0]:
		for z in [-5.5,4.5]:lamp(decor,Vector3(x,-.65,z))
		for z in [-7.0,-3.0,1.0,6.0]:
			Visuals.box(decor,Vector3(x,-.70,z),Vector3(.10,.025,1.1),Color("ab9567"))
	for x in [-4.0,0.0,6.8]:
		preload("res://scripts/world_lighting.gd").floodlight(decor,Vector3(x,1.15,-2.85),PI,true)
	for p in [Vector3(-4.7,0,3.8),Vector3(6.8,0,3.8)]:lamp(decor,p)
	# Trees now come from the biome vegetation tiles (hub_outskirts.gd).
## Route map edges: the ground runs past both screen edges; a few big pyramidal mountains stand partly off-screen,
## and ruined apartment blocks (three panel khrushchyovka types, two brick towers) sit between them and the road.
## Layout is random per run (wave seed), visual only.
static func route(parent:Node3D,length:float):
	var decor=Node3D.new();decor.name="RouteSurroundings";parent.add_child(decor)
	Visuals.box(decor,Vector3(0,-.47,8),Vector3(9,.025,6),Color("898c80"))
	var rng=RandomNumberGenerator.new();rng.seed=hash([int(parent.get("wave_seed")) if parent.get("wave_seed")!=null else 0,"route_edges"])
	for side in [-1,1]:
		# Mountains: few and big, every 12–18 units, centres beyond the visible ground so they are cut by the edge.
		var z=12.0-rng.randf_range(0,8)
		while z>-length-14:
			mountain(decor,Vector3(side*rng.randf_range(21.0,27.0),-.5,z),rng)
			z-=rng.randf_range(11.0,16.0)
		# Ruins: one block every 7–11 units on the inner belt.
		z=8.0-rng.randf_range(0,5)
		while z>-length-6:
			ruin(decor,Vector3(side*rng.randf_range(12.0,16.5),-.45,z),rng,side)
			z-=rng.randf_range(7.0,11.0)
		if rng.randf()<.6:industry(decor,Vector3(side*rng.randf_range(11.5,13.0),-.45,-rng.randf_range(0,length)),rng)
## Massif (0.8): a big terraced plateau instead of a pyramid — three to four stacked faceted tiers with flat
## tops, each a little off-centre and narrower, darker strata bands at the steps, a few fallen blocks at the foot.
static func mountain(parent:Node3D,base:Vector3,rng:RandomNumberGenerator):
	var mini=preload("res://scripts/route_miniatures.gd")
	var rock=Color("9a9a8a").darkened(rng.randf_range(0,.12));var radius=rng.randf_range(7.5,11.0)
	var sides=rng.randi_range(6,8);var yaw=rng.randf()*TAU
	var tiers=rng.randi_range(3,4);var y=base.y;var center=base;var r=radius
	for t in range(tiers):
		var height=rng.randf_range(1.6,2.6)*(1.0 if t<tiers-1 else 1.3)
		var tier=mini.cylinder(parent,Vector3(center.x,y,center.z),r,height,rock.darkened(.05*t),sides,r*rng.randf_range(.86,.94))
		tier.rotation.y=yaw+t*.4;tier.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Strata band at the step: a thin darker ring just under the tier top.
		var band=mini.cylinder(parent,Vector3(center.x,y+height-.32,center.z),r*.97,.16,rock.darkened(.22),sides,r*.95)
		band.rotation.y=yaw+t*.4;band.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		y+=height;r*=rng.randf_range(.58,.74)
		center+=Vector3(rng.randf_range(-.18,.18),0,rng.randf_range(-.18,.18))*radius
	for k in range(rng.randi_range(2,4)):
		var a=rng.randf()*TAU;var d=radius*rng.randf_range(1.0,1.2)
		var boulder=Visuals.box(parent,base+Vector3(cos(a)*d,rng.randf_range(.3,.7),sin(a)*d),Vector3.ONE*rng.randf_range(1.0,2.0),rock.darkened(rng.randf_range(.05,.2)))
		boulder.rotation=Vector3(rng.randf(),rng.randf()*TAU,rng.randf());boulder.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
static var facade_cache:={}
static func facade(color:Color,brick:bool,burnt:float,seed_value:float)->ShaderMaterial:
	var key="%s|%s|%.2f|%d" % [color.to_html(),brick,burnt,int(seed_value)%7]
	if facade_cache.has(key):return facade_cache[key]
	var material=ShaderMaterial.new();material.shader=preload("res://shaders/world/ruin_facade.gdshader")
	material.set_shader_parameter("wall",color);material.set_shader_parameter("brick",1.0 if brick else 0.0);material.set_shader_parameter("burnt",burnt);material.set_shader_parameter("seed",float(int(seed_value)%7))
	material.set_shader_parameter("window_grid",Vector2(.34,.3) if brick else Vector2(.42,.34))
	facade_cache[key]=material;return material
static func block(parent:Node3D,pos:Vector3,size:Vector3,material:Material)->MeshInstance3D:
	var node=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=Vector3.ONE;node.mesh=mesh;node.material_override=material
	parent.add_child(node);node.position=pos+Vector3.UP*size.y*.5;node.scale=size;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
## Ruined blocks: 0–2 five-storey panel khrushchyovka (whole with a burnt corner, half collapsed in steps,
## bare frame end), 3–4 brick towers (broken stepped top, side gouge). Rubble at the foot.
static func ruin(parent:Node3D,pos:Vector3,rng:RandomNumberGenerator,side:float):
	var node=Node3D.new();parent.add_child(node);node.position=pos;node.rotation.y=PI*.5+rng.randf_range(-.25,.25)+(PI if side>0 else 0.0)
	node.scale=Vector3.ONE*.7  # 0.8: smaller, the route reads first
	var panel=Color("a7a79c").darkened(rng.randf_range(0,.12));var brick=Color("9a6a52").darkened(rng.randf_range(0,.15))
	var rubble=Color("85837a");var kind=rng.randi_range(0,6);var seed_value=rng.randi()
	match kind:
		0:
			# Whole block with a burnt corner that lost its top floors.
			block(node,Vector3(-.5,0,0),Vector3(3.6,1.9,1.3),facade(panel,false,.25,seed_value))
			block(node,Vector3(1.8,0,0),Vector3(1.0,1.35,1.3),facade(panel.darkened(.2),false,.9,seed_value))
		1:
			# Half collapsed: the left part keeps five floors, the right steps down.
			block(node,Vector3(-1.4,0,0),Vector3(1.8,1.9,1.3),facade(panel,false,.25,seed_value))
			block(node,Vector3(.3,0,0),Vector3(1.6,1.15,1.3),facade(panel,false,.5,seed_value))
			block(node,Vector3(1.75,0,0),Vector3(1.3,.5,1.3),facade(panel,false,.7,seed_value))
			block(node,Vector3(2.2,0,.55),Vector3(1.6,.22,.9),StandardMaterial3D.new()).material_override=Visuals.material(rubble)
		2:
			# Burnt shell: the end section is a bare frame of columns and slabs.
			block(node,Vector3(-.9,0,0),Vector3(2.8,1.9,1.3),facade(panel.darkened(.15),false,.85,seed_value))
			for x in [.8,1.35,1.9]:block(node,Vector3(x,0,-.55),Vector3(.12,1.5,.12),StandardMaterial3D.new()).material_override=Visuals.material(panel.darkened(.3))
			for y in [.5,1.0,1.5]:block(node,Vector3(1.35,y,0),Vector3(1.3,.06,1.25),StandardMaterial3D.new()).material_override=Visuals.material(panel.darkened(.25))
		3:
			# Brick tower with a broken stepped top.
			block(node,Vector3.ZERO,Vector3(1.5,3.6,1.5),facade(brick,true,.3,seed_value))
			block(node,Vector3(-.35,3.6,0),Vector3(.8,.5,1.5),facade(brick,true,.5,seed_value))
			block(node,Vector3(-.5,4.1,-.3),Vector3(.5,.3,.9),facade(brick.darkened(.1),true,.8,seed_value))
		5:
			# Village house: two low cottages with pitched roofs, one roof caved in.
			for i in range(2):
				var x=-.9+i*1.9;var roof=Color("6f5a4a").darkened(rng.randf_range(0,.2))
				block(node,Vector3(x,0,0),Vector3(1.4,.8,1.1),facade(panel.lerp(Color("c9bba0"),.4),false,.2+i*.5,seed_value))
				for s in [-1,1]:
					var slope=Visuals.box(node,Vector3(x,.98,s*.29),Vector3(1.5,.06,.68),roof);slope.rotation.x=s*-.62*(.55 if i==1 and s>0 else 1.0)
				Visuals.box(node,Vector3(x+.4,1.2,.1),Vector3(.18,.4,.18),brick.darkened(.1))
		6:
			# Arched army hangar with a dark open end.
			var shell=preload("res://scripts/route_miniatures.gd").cylinder(node,Vector3(0,.0,0),.95,3.0,Color("7f8574"),10)
			shell.rotation.z=PI*.5;shell.position=Vector3(0,.2,0)
			Visuals.box(node,Vector3(1.52,.45,0),Vector3(.04,.8,1.1),Color("2a2c2a"))
			Visuals.box(node,Vector3(0,-.38,0),Vector3(3.4,.1,2.2),rubble)
		_:
			# Brick tower with a gouged side.
			block(node,Vector3(-.3,0,0),Vector3(.9,4.3,1.6),facade(brick,true,.35,seed_value))
			block(node,Vector3(.55,0,0),Vector3(.8,2.2,1.6),facade(brick,true,.6,seed_value))
			block(node,Vector3(.55,2.2,.35),Vector3(.8,.9,.9),facade(brick.darkened(.08),true,.9,seed_value))
	for k in range(3):
		var bit=block(node,Vector3(rng.randf_range(-2.2,2.4),0,rng.randf_range(.7,1.3)),Vector3(rng.randf_range(.3,.7),rng.randf_range(.1,.25),rng.randf_range(.3,.6)),StandardMaterial3D.new())
		bit.material_override=Visuals.material(rubble.darkened(rng.randf_range(0,.15)));bit.rotation.y=rng.randf()*TAU
## Derelict industry: a banded chimney, a broken shop wall with window gaps, or a cooling tower.
static func industry(parent:Node3D,pos:Vector3,rng:RandomNumberGenerator):
	var mini=preload("res://scripts/route_miniatures.gd")
	var brick=Color("8a7a6a");var concrete=Color("8b8f84")
	var node=Node3D.new();parent.add_child(node);node.position=pos;node.rotation.y=rng.randf_range(-.4,.4)
	match rng.randi_range(0,2):
		0:
			mini.cylinder(node,Vector3.ZERO,.35,3.4,brick,8,.28)
			for y in [2.4,2.9]:mini.cylinder(node,Vector3(0,y,0),.33,.14,Color("c8452f") if y<2.6 else Color("e8e2d0"),8)
			Visuals.box(node,Vector3(.8,.4,0),Vector3(1.2,.8,1.0),concrete)
		1:
			for i in range(4):
				var h=rng.randf_range(.7,1.9)
				Visuals.box(node,Vector3(-1.2+i*.8,h*.5,0),Vector3(.72,h,.25),concrete if i%2 else brick)
				if h>1.2:Visuals.box(node,Vector3(-1.2+i*.8,h*.6,.13),Vector3(.3,.35,.02),Color("2a2c2a"))
			Visuals.box(node,Vector3(.2,.1,.8),Vector3(1.6,.2,.9),concrete.darkened(.15))
		_:
			mini.cylinder(node,Vector3.ZERO,1.1,2.4,concrete,10,.75)
			mini.cylinder(node,Vector3(0,2.3,0),.78,.25,concrete.darkened(.2),10,.82)
