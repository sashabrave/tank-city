extends RefCounted
## Sparse visual-only scenery, outside the authored gameplay grid.
static func lamp(parent:Node3D,pos:Vector3):
	var rig=Node3D.new();rig.name="MilitaryLightStand";parent.add_child(rig);rig.position=pos
	rig.rotation.y=atan2(rig.global_position.x,rig.global_position.z)
	Visuals.box(rig,Vector3(0,.75,0),Vector3(.065,1.5,.065),Color("515d51"))
	for angle in [0.0,TAU/3,TAU*2/3]:
		var leg=Visuals.box(rig,Vector3(sin(angle)*.14,.12,cos(angle)*.14),Vector3(.045,.30,.045),Color("535d50"));leg.rotation=Vector3(.55,angle,0)
	Visuals.box(rig,Vector3(0,1.43,0),Vector3(1.0,.055,.06),Color("515d51"))
	for x in [-.34,0,.34]:
		var head=Visuals.box(rig,Vector3(x,1.5,0),Vector3(.28,.17,.20),Color("65715b"));head.rotation.x=-.3
		Visuals.box(rig,Vector3(x,1.47,-.105),Vector3(.22,.105,.025),Color("ffe0a0")).material_override=EffectLighting.glow(Color("ffe0a0"))
	# Three lamp heads share one broad spotlight instead of tripling real lights.
	var light=preload("res://scripts/world_lighting.gd").beam(rig,Vector3(0,1.46,-.13),true,1)
	light.rotation.x=deg_to_rad(-47);light.spot_range=6;light.spot_angle=43;light.set_meta("day_energy",.15);light.set_meta("night_energy",1.7)
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
		preload("res://scripts/world_lighting.gd").floodlight(decor,Vector3(x,1.15,-2.85),PI)
	for p in [Vector3(-4.7,0,3.8),Vector3(6.8,0,3.8)]:lamp(decor,p)
	# Trees now come from the biome vegetation tiles (hub_outskirts.gd).
static func route(parent:Node3D,length:float):
	var decor=Node3D.new();decor.name="RouteSurroundings";parent.add_child(decor)
	Visuals.box(decor,Vector3(0,-.47,8),Vector3(9,.025,6),Color("898c80"))
	# Edges: stepped mountains with strata and light tops, a derelict industrial belt in front of them.
	var rng=RandomNumberGenerator.new();rng.seed=40417
	for side in [-1,1]:
		for index in range(int(length/6)+3):
			var z=10-index*6.0+rng.randf_range(-1.5,1.5)
			mountain(decor,Vector3(side*rng.randf_range(16.0,20.5),-.5,z),rng)
			if index%2==1:industry(decor,Vector3(side*rng.randf_range(12.2,13.4),-.45,z+rng.randf_range(-1.2,1.2)),rng)
static func mountain(parent:Node3D,base:Vector3,rng:RandomNumberGenerator):
	var mini=preload("res://scripts/route_miniatures.gd")
	var rock=Color("8f9384").darkened(rng.randf_range(0,.12));var height=rng.randf_range(2.6,5.0);var radius=rng.randf_range(2.2,3.2)
	var sides=rng.randi_range(5,7);var yaw=rng.randf()*TAU
	var tiers=[[1.0,.42],[.7,.34],[.42,.24]]
	var y=base.y;var offset=Vector3.ZERO
	for t in range(tiers.size()):
		var h=height*tiers[t][1];var r=radius*tiers[t][0]
		var piece=mini.cylinder(parent,base+offset+Vector3(0,y-base.y,0),r,h,rock.lightened(t*.05),sides,r*.78)
		piece.rotation.y=yaw+t*.4;piece.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		y+=h*.92;offset+=Vector3(rng.randf_range(-.3,.3),0,rng.randf_range(-.3,.3))
	var band=mini.cylinder(parent,base+Vector3(0,height*.3,0),radius*.86,.12,rock.darkened(.22),sides,radius*.84);band.rotation.y=yaw;band.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if height>3.6:
		var cap=mini.cylinder(parent,base+offset+Vector3(0,y-base.y-.05,0),radius*.34,.35,Color("e6e4dc"),sides,.05);cap.rotation.y=yaw;cap.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in range(3):
		var boulder=mini.cylinder(parent,base+Vector3(rng.randf_range(-radius,radius)*1.2,0,rng.randf_range(-radius,radius)*1.2),rng.randf_range(.25,.55),rng.randf_range(.2,.5),rock.darkened(.1),5,.12)
		boulder.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
