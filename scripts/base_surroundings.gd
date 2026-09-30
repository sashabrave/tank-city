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

static func hub(parent:Node3D):
	var decor=Node3D.new();decor.name="SparseSurroundings";parent.add_child(decor)
	Visuals.box(decor,Vector3(1,-.78,0),Vector3(36,.12,28),Color("7c8176"))
	for x in [-7.0,9.0]:
		for z in [-5.5,4.5]:lamp(decor,Vector3(x,-.65,z))
		for z in [-7.0,-3.0,1.0,6.0]:
			Visuals.box(decor,Vector3(x,-.70,z),Vector3(.10,.025,1.1),Color("ab9567"))
	for x in [-4.0,0.0,6.8]:
		preload("res://scripts/world_lighting.gd").floodlight(decor,Vector3(x,1.15,-2.85),PI)
	for p in [Vector3(-4.7,0,3.8),Vector3(6.8,0,3.8)]:lamp(decor,p)
	for p in [Vector3(-9,-.65,-6),Vector3(-9.5,-.65,3),Vector3(11,-.65,-7),Vector3(10,-.65,6)]:tree(decor,p,2.1)
static func route(parent:Node3D,length:float):
	var decor=Node3D.new();decor.name="RouteSurroundings";parent.add_child(decor)
	Visuals.box(decor,Vector3(0,-.47,8),Vector3(9,.025,6),Color("898c80"))
	for x in [-4.3,4.3]:
		for z in [5.5,7.0,8.5,10.0]:Visuals.box(decor,Vector3(x,-.44,z),Vector3(.13,.02,.8),Color("b29a65"))
	for side in [-1,1]:
		for index in range(int(length/9)+2):
			var z=9-index*9.0
			Visuals.box(decor,Vector3(side*11.2,-.1,z),Vector3(.28,.65,3),Color("777f70"))
			lamp(decor,Vector3(side*11,-.4,z-2))
			tree(decor,Vector3(side*12.7,-.5,z+1),2.2+float(index%3)*.3)
