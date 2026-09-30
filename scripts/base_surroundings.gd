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
	for x in [-4.3,4.3]:
		for z in [5.5,7.0,8.5,10.0]:Visuals.box(decor,Vector3(x,-.44,z),Vector3(.13,.02,.8),Color("b29a65"))
	# Edges: abstract one-tone mountains and hints of distant bases, no detail.
	var rng=RandomNumberGenerator.new();rng.seed=40417
	var rock=Color("969a8b");var ruin=Color("8b8f84")
	for side in [-1,1]:
		for index in range(int(length/6)+3):
			var z=10-index*6.0+rng.randf_range(-1.5,1.5)
			for k in range(2):
				var peak=preload("res://scripts/route_miniatures.gd").cylinder(decor,Vector3(side*rng.randf_range(15.5,20.0),-.5,z+k*2.4),rng.randf_range(1.8,3.0),rng.randf_range(2.0,4.2),rock.darkened(rng.randf_range(.04,.12)),rng.randi_range(5,7),rng.randf_range(.15,.5))
				peak.rotation.y=rng.randf()*TAU;peak.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if index%3==1:
				var chunk=Node3D.new();decor.add_child(chunk);chunk.position=Vector3(side*12.6,-.45,z);chunk.rotation.y=rng.randf_range(-.3,.3)
				match rng.randi_range(0,2):
					0:Visuals.box(chunk,Vector3(0,.45,0),Vector3(.4,.9,3.2),ruin)
					1:
						Visuals.box(chunk,Vector3(0,1.1,0),Vector3(.9,2.2,.9),ruin);Visuals.box(chunk,Vector3(0,2.35,0),Vector3(1.3,.3,1.3),ruin)
					_:
						Visuals.box(chunk,Vector3(0,.35,0),Vector3(2.2,.7,1.4),ruin);Visuals.box(chunk,Vector3(0,.55,.71),Vector3(1.2,.12,.02),ruin.darkened(.35))
