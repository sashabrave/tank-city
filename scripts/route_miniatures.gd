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
static func battle(parent:Node3D,variant:int,color:Color,cleared:bool=false):
	base(parent,color)
	var wall=color.darkened(.24);var top=color.lightened(.13)
	var layouts=[[[ -1.7,-1.2,1.2,1.1],[1.5,.6,1.1,1.5]], [[-1.6,0,.8,2.6],[1.5,-1.4,1.3,.8],[1.4,1.2,1.3,.8]], [[0,-1.5,2.8,.7],[-1.6,.8,.8,1.5],[1.5,1.2,.9,.8]], [[-1.6,-1.5,1.1,1.1],[1.5,-1.5,1.1,1.1],[0,.7,1.5,.8]]]
	for item in layouts[variant%4]:
		var cover=Visuals.model("wall" if variant%2==0 else "crate",parent,Vector3(item[0],.28,item[1]))
		cover.scale=Vector3(item[2],.85,item[3])
	for x in [-.6,.15,.9]:
		var sandbag=Visuals.model("net",parent,Vector3(x,.28,2));sandbag.scale=Vector3(.6,.35,.45)
	preload("res://scripts/base_surroundings.gd").tree(parent,Vector3(-2.25,.28,1.0),1.8)
	preload("res://scripts/base_surroundings.gd").tree(parent,Vector3(2.1,.28,-2),1.4)
	var supplies=Visuals.model("supply_stack",parent,Vector3(.1,.28,-.4));supplies.scale=Vector3.ONE*.7
	if cleared:
		for x in [-1.1,1.1]:
			var wreck=Node3D.new();parent.add_child(wreck);wreck.position=Vector3(x,.55,0);wreck.rotation=Vector3(0,x*.4,PI)
			Visuals.box(wreck,Vector3.ZERO,Vector3(.8,.3,1.1),wall);Visuals.box(wreck,Vector3(0,-.2,0),Vector3(.45,.25,.5),wall)
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
static func star(parent:Node3D,count:int=1,index:int=0):
	var points=PackedVector2Array()
	for i in range(10):
		var a=-PI*.5+i*TAU/10;points.append(Vector2(cos(a),sin(a))*(.9 if i%2==0 else .42))
	var badge=prism(parent,points,.24,Color("eac15e"));badge.name="EliteStar";badge.position=Vector3((index-(count-1)*.5)*2.0,2.65,-1.8);badge.rotation=Vector3(deg_to_rad(54),deg_to_rad(10),0)
	badge.material_override.emission_enabled=true;badge.material_override.emission=Color("ffcf56");badge.material_override.emission_energy_multiplier=2.8
	badge.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func headquarters(parent:Node3D):
	base(parent,Color("8c9c85"),true)
	var rover=Visuals.model("base",parent);rover.scale=Vector3.ONE*1.8;rover.position=Vector3(0,.28,0);rover.rotation.y=PI*.5
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
