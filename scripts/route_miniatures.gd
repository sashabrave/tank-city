extends RefCounted
## Shared, low-poly map dioramas. All footprints are identical.
static func prism(parent:Node3D,points:PackedVector2Array,height:float,color:Color)->MeshInstance3D:
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles=Geometry2D.triangulate_polygon(points)
	for i in range(0,triangles.size(),3):
		for index in [triangles[i+2],triangles[i+1],triangles[i]]:
			var p=points[index];surface.add_vertex(Vector3(p.x,height,p.y))
	for i in range(points.size()):
		var a=points[i];var b=points[(i+1)%points.size()]
		for p in [Vector3(a.x,0,a.y),Vector3(b.x,height,b.y),Vector3(b.x,0,b.y),Vector3(a.x,0,a.y),Vector3(a.x,height,a.y),Vector3(b.x,height,b.y)]:surface.add_vertex(p)
	surface.generate_normals()
	var result=MeshInstance3D.new();result.mesh=surface.commit();result.material_override=Visuals.material(color);result.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED;parent.add_child(result);return result
static func outline(radius:float=3.15)->PackedVector2Array:
	var r=radius;var b=.22
	return PackedVector2Array([Vector2(r-b,r),Vector2(-r+b,r),Vector2(-r,r-b),Vector2(-r,-r+b),Vector2(-r+b,-r),Vector2(r-b,-r),Vector2(r,-r+b),Vector2(r,r-b)])

static func base(parent:Node3D,color:Color,round_tile=false):
	var points=outline()
	if round_tile:
		points=PackedVector2Array()
		for i in range(48):points.append(Vector2(cos(i*TAU/48),sin(i*TAU/48))*3.15)
	var plinth=prism(parent,points,.20,color.darkened(.18));plinth.position.y=-.08
	var tile=prism(parent,points,.28,color);tile.name="RoomTile"
static func border(parent:Node3D,color:Color,round_tile=false):
	var points=outline(3.3)
	if round_tile:
		points=PackedVector2Array()
		for i in range(48):points.append(Vector2(cos(i*TAU/48),sin(i*TAU/48))*3.3)
	for i in range(points.size()):
		var a=Vector3(points[i].x,.05,points[i].y);var b=Vector3(points[(i+1)%points.size()].x,.05,points[(i+1)%points.size()].y)
		var line=Visuals.box(parent,(a+b)*.5,Vector3(.13,.065,a.distance_to(b)+.03),color);line.rotation.y=atan2(b.x-a.x,b.z-a.z)
		line.material_override=Visuals.material(color,true)
static func cylinder(parent:Node3D,pos:Vector3,radius:float,height:float,color:Color,segments:int=8,top:float=-1.0)->MeshInstance3D:
	var shape=MeshInstance3D.new();var mesh=CylinderMesh.new()
	mesh.top_radius=radius if top<0 else top;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=segments;mesh.rings=1
	shape.mesh=mesh;shape.material_override=Visuals.material(color);parent.add_child(shape);shape.position=pos+Vector3.UP*height*.5;return shape
static func sandbags(parent:Node3D,center:Vector3,count:int,radius:float,color:Color):
	for i in range(count):
		var a=TAU*i/count;var bag=MeshInstance3D.new();var capsule=CapsuleMesh.new()
		capsule.radius=.22;capsule.height=.78;capsule.radial_segments=6;capsule.rings=1;bag.mesh=capsule
		bag.material_override=Visuals.material(color);parent.add_child(bag)
		bag.position=center+Vector3(cos(a)*radius,.2,sin(a)*radius);bag.rotation=Vector3(0,-a+PI*.5,PI*.5)
static func animator(parent:Node3D):
	var node=preload("res://scripts/diorama_animator.gd").new();parent.add_child(node);return node
## Battle dioramas by context: outpost (easy), supply depot (medium), fire base (hard). One stepped animation each.
static func battle(parent:Node3D,variant:int,color:Color,cleared:bool=false,difficulty:int=0):
	base(parent,color)
	var y=.28;var bag=color.lerp(Color("b0ac91"),.55);var olive=Color("5f6448");var steel=Color("4a4e52");var light=Color("dcd6c6")
	var anim=animator(parent)
	var side=-1.0 if variant%2==0 else 1.0
	match difficulty:
		0:
			# Outpost: a watchtower with a blinking lamp, sandbag ring, a couple of crates.
			var tower=Node3D.new();parent.add_child(tower);tower.position=Vector3(side*1.2,y,-.6)
			for x in [-.45,.45]:
				for z in [-.45,.45]:Visuals.box(tower,Vector3(x,1.1,z),Vector3(.12,2.2,.12),olive)
			Visuals.box(tower,Vector3(0,2.2,0),Vector3(1.2,.12,1.2),olive)
			Visuals.box(tower,Vector3(0,2.45,0),Vector3(1.2,.4,1.2),bag)
			var roof=Visuals.box(tower,Vector3(0,2.95,0),Vector3(1.4,.1,1.4),olive.darkened(.2))
			var lamp=Visuals.box(tower,Vector3(0,3.1,0),Vector3(.22,.22,.22),Color("ffd27a"));lamp.material_override=Visuals.material(Color("ffd27a"),true)
			anim.add(lamp,"visible",[true,true,false])
			sandbags(parent,Vector3(-side*1.0,y,.9),7,.75,bag)
			var crate=Visuals.model("crate",parent,Vector3(-side*1.5,y,-1.4));crate.scale=Vector3.ONE*1.1
		1:
			# Supply depot: two fuel tanks, crate stack, an antenna with a slow red beacon.
			for z in [-.9,.1]:
				var tank=cylinder(parent,Vector3(side*1.1,y+.55,z),.5,1.9,Color("7a8062"),10);tank.rotation.z=PI*.5
				tank.position=Vector3(side*1.1,y+.55,z)
				Visuals.box(parent,Vector3(side*1.1,y+.55,z),Vector3(.2,1.08,1.08),Color("e0692a"))
			var stack=Visuals.model("supply_stack",parent,Vector3(-side*1.2,y,-.9));stack.scale=Vector3.ONE*1.3
			var crate=Visuals.model("crate",parent,Vector3(-side*1.1,y,1.0));crate.scale=Vector3.ONE*1.1
			cylinder(parent,Vector3(0,y,-1.9),.06,2.6,steel,6)
			var beacon=Visuals.box(parent,Vector3(0,y+2.7,-1.9),Vector3(.2,.2,.2),Color("ff4a3a"));beacon.material_override=Visuals.material(Color("ff4a3a"),true)
			anim.add(beacon,"visible",[true,false,false])
		_:
			# Fire base: sandbagged gun pit with a traversing barrel, radar dish sweeping in steps.
			sandbags(parent,Vector3(side*.9,y,.2),9,1.05,bag)
			var gun=Node3D.new();parent.add_child(gun);gun.position=Vector3(side*.9,y+.35,.2)
			Visuals.box(gun,Vector3(0,0,0),Vector3(.8,.35,.8),olive)
			var barrel=cylinder(gun,Vector3(0,.2,-.3),.1,1.5,steel,6);barrel.rotation.x=-PI*.42;barrel.position=Vector3(0,.35,-.55)
			anim.add(gun,"rotation:y",[-.35,0.0,.35])
			var mast=cylinder(parent,Vector3(-side*1.4,y,-1.2),.08,1.4,steel,6)
			var dish=Node3D.new();parent.add_child(dish);dish.position=Vector3(-side*1.4,y+1.5,-1.2)
			var bowl=cylinder(dish,Vector3(0,0,.1),.55,.12,light,10,.3);bowl.rotation.x=PI*.5
			anim.add(dish,"rotation:y",[0.0,1.2,2.4])
			Visuals.model("crate",parent,Vector3(-side*1.3,y,1.2))
	preload("res://scripts/base_surroundings.gd").tree(parent,Vector3(-side*2.25,y,-2.1),1.6)
	preload("res://scripts/base_surroundings.gd").tree(parent,Vector3(side*2.2,y,2.0),1.3)
	if cleared:
		# Taken ground: our flag waves over it.
		var flag=Node3D.new();parent.add_child(flag);flag.position=Vector3(0,y,1.6);flag.scale=Vector3.ONE*1.2
		ExitFlag.build(flag)
static func service(parent:Node3D,hangar:bool,color:Color):
	base(parent,color,true)
	var dark=color.darkened(.3)
	if hangar:
		for x in [-1.7,1.7]:Visuals.box(parent,Vector3(x,1,-.5),Vector3(.25,1.5,2.8),dark)
		Visuals.box(parent,Vector3(0,1.8,-.5),Vector3(3.7,.22,3),color.lightened(.15))
		Visuals.box(parent,Vector3(0,.65,-.3),Vector3(1.5,.5,1.9),dark)
		Visuals.box(parent,Vector3(0,1.02,-.4),Vector3(.8,.35,.8),color.lightened(.15))
		Visuals.box(parent,Vector3(0,1.05,.3),Vector3(.15,.15,1.1),color.lightened(.3))
	else:
		Visuals.box(parent,Vector3(0,.7,-.6),Vector3(2.8,.85,2.3),dark)
		for side in [-1,1]:
			var roof=Visuals.box(parent,Vector3(side*.72,1.55,-.6),Vector3(1.8,.12,2.5),color.lightened(.12));roof.rotation.z=side*-.52
		Visuals.box(parent,Vector3(0,.75,.57),Vector3(.6,.95,.07),dark.darkened(.45))
	Visuals.box(parent,Vector3(2,1.5,1.2),Vector3(.08,2.5,.08),Color("d8d9ca"))
	Visuals.box(parent,Vector3(2.4,2.5,1.2),Vector3(.85,.5,.07),Color("e5b34f"))
## Round, puffy difficulty star: soft lobes and a domed top instead of sharp points.
static func star_mesh()->ArrayMesh:
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n=40;var outer=[];var inner=[]
	for i in range(n):
		var a=-PI*.5+i*TAU/n
		var lobe=pow(.5+.5*cos(a*5+PI*.5),1.4)
		var r=.5+.5*lobe
		outer.append(Vector2(cos(a),sin(a))*r);inner.append(Vector2(cos(a),sin(a))*r*.6)
	var top=Vector3(0,.42,0)
	for i in range(n):
		var j=(i+1)%n
		var o0=Vector3(outer[i].x,.1,outer[i].y);var o1=Vector3(outer[j].x,.1,outer[j].y)
		var m0=Vector3(inner[i].x,.3,inner[i].y);var m1=Vector3(inner[j].x,.3,inner[j].y)
		var b0=Vector3(outer[i].x,0,outer[i].y);var b1=Vector3(outer[j].x,0,outer[j].y)
		for p in [top,m1,m0, m0,m1,o1, m0,o1,o0, o0,o1,b1, o0,b1,b0, Vector3.ZERO,b0,b1]:surface.add_vertex(p)
	surface.generate_normals()
	return surface.commit()
static var cached_star:ArrayMesh
static func star(parent:Node3D,count:int=1,index:int=0):
	if cached_star==null:cached_star=star_mesh()
	var badge=MeshInstance3D.new();badge.mesh=cached_star;badge.name="EliteStar";parent.add_child(badge)
	badge.scale=Vector3.ONE*1.05
	badge.position=Vector3((index-(count-1)*.5)*2.1,2.65,-1.8);badge.rotation=Vector3(deg_to_rad(54),deg_to_rad(10),0)
	var mat=Visuals.material(Color("f2c75a"));mat.emission_enabled=true;mat.emission=Color("ffcf56");mat.emission_energy_multiplier=2.4;mat.roughness=.35
	badge.material_override=mat
	badge.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func headquarters(parent:Node3D):
	base(parent,Color("8c9c85"),true)
	var rover=Visuals.model("base",parent);rover.scale=Vector3.ONE*1.3;rover.position=Vector3(0,.28,0);rover.rotation.y=PI*.5
	Visuals.box(parent,Vector3(2,1.4,1.1),Vector3(.08,2.4,.08),Color("d8d9ca"))
	Visuals.box(parent,Vector3(2.4,2.4,1.1),Vector3(.85,.5,.07),Color("79bd9b"))

## Start pad: round concrete platform with a launch gate and chevrons the vehicle leaves from.
static func start(parent:Node3D):
	var concrete=Color("8d9186")
	base(parent,concrete,true)
	for x in [-2.1,2.1]:Visuals.box(parent,Vector3(x,1.05,-1.6),Vector3(.32,1.55,.32),concrete.darkened(.35))
	Visuals.box(parent,Vector3(0,1.9,-1.6),Vector3(4.6,.26,.4),Color("e5b34f"))
	for i in range(5):Visuals.box(parent,Vector3(-1.9+i*.95,1.9,-1.38),Vector3(.45,.2,.03),Color("2f332d"))
	for i in range(3):
		for side in [-1,1]:
			var chevron=Visuals.box(parent,Vector3(side*.38,.3,1.3-i*.95),Vector3(.9,.03,.18),Color("f0d27a"));chevron.rotation.y=side*.75
	Visuals.box(parent,Vector3(2.3,.55,1.6),Vector3(.7,.55,.7),concrete.darkened(.2))
	Visuals.box(parent,Vector3(2.3,.95,1.6),Vector3(.18,.3,.18),Color("cf613f"))

## Merchant stall: striped awning over a counter with crates.
static func merchant(parent:Node3D):
	var wood=Color("8a6a48")
	base(parent,Color("a99b79"),true)
	Visuals.box(parent,Vector3(0,.6,-.4),Vector3(3,.8,1),wood)
	for x in [-1.4,1.4]:Visuals.box(parent,Vector3(x,1.3,-.9),Vector3(.18,1.9,.18),wood.darkened(.3))
	for i in range(5):Visuals.box(parent,Vector3(-1.2+i*.6,2.25,-.6),Vector3(.6,.14,1.4),Color("c9793f") if i%2==0 else Color("e8dcc0"))
	Visuals.box(parent,Vector3(1.8,.45,1.1),Vector3(.7,.6,.7),Color("9c8156"))
	Visuals.box(parent,Vector3(-1.8,.45,1),Vector3(.6,.5,.6),Color("9c8156"))

## Challenge tile: battlefield plate with the challenge prop (cache chest…).
static func challenge(parent:Node3D,type:String,color:Color):
	base(parent,color)
	match type:
		"cache":
			Visuals.box(parent,Vector3(0,.75,0),Vector3(2.2,1.1,1.4),Color("5d5a4a"))
			Visuals.box(parent,Vector3(0,1.38,0),Vector3(2.3,.25,1.5),Color("7b7660"))
			for x in [-.7,.7]:Visuals.box(parent,Vector3(x,.8,-.72),Vector3(.2,1,.06),Color("d4bd73"))
			Visuals.box(parent,Vector3(0,.95,-.73),Vector3(.35,.35,.05),Color("cf613f"))
		"hold":
			Visuals.ring(parent,Color("e5b34f"),2.1)
			Visuals.box(parent,Vector3(0,1.4,0),Vector3(.18,2.4,.18),Color("eee9d8"))
			Visuals.box(parent,Vector3(.7,2.2,0),Vector3(1.3,.8,.1),Color("e5b34f"))
		"thimbles":
			for x in [-1.3,0,1.3]:
				var cup=MeshInstance3D.new();var shape=CylinderMesh.new();shape.top_radius=.28;shape.bottom_radius=.48;shape.height=.9;cup.mesh=shape;cup.position=Vector3(x,.75,0);cup.material_override=Visuals.material(Color("56645a"));parent.add_child(cup)
		"switches":
			var colors=[Color("d8453a"),Color("e5b34f"),Color("5aa469"),Color("4f86c6")]
			for i in range(4):Visuals.box(parent,Vector3(-1.2+(i%2)*2.4,.36,-1.2+int(i/2)*2.4),Vector3(1.1,.1,1.1),colors[i])
			Visuals.box(parent,Vector3(0,.8,0),Vector3(1,1,1),Color("59605a"))
		"survive":
			for p in [Vector3(-1.2,0,-.8),Vector3(1,0,.6),Vector3(-.2,0,1.3)]:
				var ring=Visuals.ring(parent,Color("d8453a"),.9);ring.position=p+Vector3(0,.32,0)
			Visuals.box(parent,Vector3(.9,.7,-1),Vector3(.5,.8,.5),Color("6d6a5c"))
