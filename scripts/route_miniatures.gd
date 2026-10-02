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
	if variant>=2:
		battle_alt(parent,difficulty,side,y,bag,olive,steel,light,anim)
	else:
		battle_main(parent,difficulty,side,y,bag,olive,steel,light,anim)
	battlefield(parent,variant,side,y,color)
	preload("res://scripts/base_surroundings.gd").tree(parent,Vector3(-side*2.25,y,-2.1),1.6)
	preload("res://scripts/base_surroundings.gd").tree(parent,Vector3(side*2.2,y,2.0),1.3)
	if cleared:
		# Taken ground: our flag waves over it.
		var flag=Node3D.new();parent.add_child(flag);flag.position=Vector3(0,y,1.6);flag.scale=Vector3.ONE*1.2
		ExitFlag.build(flag)
static func battle_main(parent:Node3D,difficulty:int,side:float,y:float,bag:Color,olive:Color,steel:Color,light:Color,anim):
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
## Battlefield dressing shared by every battle tile: a ruined building corner with a jagged top and rubble,
## a hedgehog barricade line and a crater — in the car's scale, so the tile reads as a place of war.
static func battlefield(parent:Node3D,variant:int,side:float,y:float,color:Color):
	var wall=color.darkened(.25).lerp(Color("8b8f84"),.5);var rubble=color.darkened(.35)
	var corner=Node3D.new();parent.add_child(corner);corner.position=Vector3(-side*1.9,y,1.9-(variant%2)*3.6);corner.rotation.y=side*.2
	var heights=[1.3,1.0,.55]
	for i in range(3):Visuals.box(corner,Vector3(i*.5,heights[i]*.5,0),Vector3(.5,heights[i],.22),wall)
	for i in range(2):Visuals.box(corner,Vector3(0,[1.15,.7][i]*.5,.45+i*.45),Vector3(.22,[1.15,.7][i],.45),wall)
	Visuals.box(corner,Vector3(.35,.62,.02),Vector3(.24,.3,.04),Color("2a2c2a"))
	for k in range(4):Visuals.box(corner,Vector3(.4+k*.22,.07,.45+(k%2)*.2),Vector3(.2,.14,.18),rubble).rotation.y=k*.7
	for k in range(3):
		var hog=Node3D.new();parent.add_child(hog);hog.position=Vector3(-.9+k*.9,y,-2.35);hog.rotation.y=k*.8
		for axis in [Vector3(1,1,0),Vector3(-1,1,0),Vector3(0,1,1)]:
			var beam=Visuals.box(hog,Vector3(0,.2,0),Vector3(.06,.48,.06),Color("4f5443"))
			beam.basis=Basis(Vector3.UP.cross(axis.normalized()).normalized() if Vector3.UP.cross(axis.normalized()).length()>.01 else Vector3.RIGHT,Vector3.UP.angle_to(axis.normalized()))
	cylinder(parent,Vector3(side*1.7,y-.02,-1.6+(variant%2)*.4),.45,.05,color.darkened(.45),10)
## Second set of battle dioramas, picked by the node seed so neighbouring fields differ:
## checkpoint (easy), convoy under camo net (medium), bunker with a sweeping searchlight (hard).
static func battle_alt(parent:Node3D,difficulty:int,side:float,y:float,bag:Color,olive:Color,steel:Color,light:Color,anim):
	match difficulty:
		0:
			Visuals.box(parent,Vector3(side*1.1,y+.7,-.8),Vector3(1.1,1.4,1.1),olive)
			Visuals.box(parent,Vector3(side*1.1,y+1.5,-.8),Vector3(1.4,.12,1.4),olive.darkened(.25))
			var arm=Node3D.new();parent.add_child(arm);arm.position=Vector3(side*.4,y+.8,.3)
			Visuals.box(arm,Vector3(-side*1.0,0,0),Vector3(2.0,.12,.12),Color("e8e2d0"))
			for i in range(3):Visuals.box(arm,Vector3(-side*(.35+i*.6),0,.0),Vector3(.25,.14,.14),Color("cf613f"))
			anim.add(arm,"rotation:z",[0.0,side*.35,side*.7,side*.35])
			sandbags(parent,Vector3(-side*1.2,y,-1.2),6,.6,bag)
		1:
			for i in range(2):
				var truck=Node3D.new();parent.add_child(truck);truck.position=Vector3(-side*.6+i*side*1.3,y,-.3+i*.9);truck.rotation.y=.2*side
				Visuals.box(truck,Vector3(0,.45,.3),Vector3(.9,.7,1.5),olive)
				Visuals.box(truck,Vector3(0,.55,-.75),Vector3(.9,.9,.6),olive.darkened(.15))
			for x in [-1.8,1.8]:cylinder(parent,Vector3(x,y,-.2),.05,1.6,steel,5)
			var net=Visuals.box(parent,Vector3(0,y+1.65,-.2),Vector3(4.0,.06,2.8),Color("6d7650"));net.rotation.z=.08*side
			var lamp=Visuals.box(parent,Vector3(side*1.8,y+1.75,-.2),Vector3(.2,.2,.2),Color("ffd27a"));lamp.material_override=Visuals.material(Color("ffd27a"),true)
			anim.add(lamp,"visible",[true,false,true,true])
		_:
			var bunker=Visuals.box(parent,Vector3(0,y+.55,-.6),Vector3(2.8,1.1,1.8),Color("7d7f76"))
			Visuals.box(parent,Vector3(0,y+.7,.31),Vector3(1.8,.16,.05),Color("1f2320"))
			Visuals.box(parent,Vector3(0,y+1.18,-.6),Vector3(3.1,.18,2.1),Color("6a6c63"))
			var light_head=Node3D.new();parent.add_child(light_head);light_head.position=Vector3(side*1.1,y+1.45,-.6)
			var head=cylinder(light_head,Vector3.ZERO,.22,.35,steel,8);head.rotation.x=PI*.5
			var beam=Visuals.box(light_head,Vector3(0,-.25,1.3),Vector3(.3,.05,2.4),Color(1,.95,.7,.35));beam.material_override=Visuals.material(Color(1,.95,.7,.35),true)
			anim.add(light_head,"rotation:y",[-.6,-.2,.2,.6,.2,-.2])
			sandbags(parent,Vector3(-side*1.3,y,1.1),7,.7,bag)
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

## Pit-stop depot: the HQ vehicle drives in, gets its cards and drives on. Open bay with a lift,
## a fuel pump, a tool wall and a blinking bay lamp; chevrons lead in.
static func depot(parent:Node3D):
	var concrete=Color("8c9588");base(parent,concrete,true)
	var frame=Color("4b5048");var accent=Color("e5b34f")
	for x in [-1.9,1.9]:Visuals.box(parent,Vector3(x,1.2,-.6),Vector3(.26,1.9,2.6),frame)
	Visuals.box(parent,Vector3(0,2.2,-.6),Vector3(4.1,.22,2.8),frame.lightened(.12))
	for i in range(6):Visuals.box(parent,Vector3(-1.75+i*.7,2.1,.78),Vector3(.35,.16,.04),accent if i%2==0 else Color("2f332d"))
	Visuals.box(parent,Vector3(0,.34,-.6),Vector3(2.4,.08,2.2),Color("3f433d"))
	var lift=Visuals.box(parent,Vector3(0,.42,-.6),Vector3(1.6,.08,1.6),accent.darkened(.2))
	var anim=animator(parent);anim.add(lift,"position:y",[.42,.52,.62,.52])
	Visuals.box(parent,Vector3(-1.45,1.0,-1.6),Vector3(.7,1.2,.12),Color("6a6f63"))
	for i in range(3):Visuals.box(parent,Vector3(-1.65+i*.2,1.1,-1.52),Vector3(.06,.5,.04),Color("c9cfbe"))
	var pump=Visuals.box(parent,Vector3(2.5,.75,1.0),Vector3(.5,.9,.4),Color("cf613f"))
	Visuals.box(parent,Vector3(2.5,1.3,1.0),Vector3(.52,.18,.42),Color("e8e2d0"))
	var lamp=Visuals.box(parent,Vector3(0,2.45,.6),Vector3(.25,.18,.25),Color("ffb52c"));lamp.material_override=Visuals.material(Color("ffb52c"),true)
	anim.add(lamp,"visible",[true,false])
	for i in range(3):
		for side in [-1,1]:
			var chevron=Visuals.box(parent,Vector3(side*.34,.31,2.3-i*.6),Vector3(.7,.03,.14),Color("f0d27a"));chevron.rotation.y=side*.75
## «Захваченный КП»: a dark enemy bunker with a torn red flag, sandbags, a radio mast and a glowing chest.
static func command_post(parent:Node3D):
	base(parent,Color("5b5752"),true)
	var concrete=Color("6f6c66");var dark=Color("3a3734")
	Visuals.box(parent,Vector3(0,.75,-.4),Vector3(3.4,1.1,2.2),concrete)
	Visuals.box(parent,Vector3(0,1.4,-.4),Vector3(3.8,.25,2.6),dark)
	Visuals.box(parent,Vector3(0,.8,.73),Vector3(1.6,.22,.06),Color("1d1c1b"))  # firing slit
	sandbags(parent,Vector3(0,.3,1.8),7,1.6,Color("a8996f"))
	var mast=cylinder(parent,Vector3(1.4,1.5,-1.1),.05,2.2,dark,6)
	var flag=Visuals.box(parent,Vector3(.95,3.2,-1.1),Vector3(.9,.5,.04),Color("c8452f"))
	var anim=animator(parent);anim.add(flag,"rotation:y",[0.0,.2,0.0,-.15])
	var chest=Visuals.box(parent,Vector3(-1.5,.55,1.2),Vector3(.8,.5,.55),Color("6b4a2a"))
	var glow=Visuals.box(parent,Vector3(-1.5,.83,1.2),Vector3(.7,.06,.45),Color("ffd36a"));glow.material_override=Visuals.material(Color("ffd36a"),true)
	anim.add(glow,"visible",[true,true,false,true])
	star(parent,1)
## Weather over a node, from the room's biome: snow, rain, sun, fog or embers. Static meshes stepped by
## the diorama animator — no particles, a few boxes per node.
static func weather(parent:Node3D,kind:String):
	if kind=="":return
	var sky=Node3D.new();sky.name="Weather";parent.add_child(sky);sky.position=Vector3(1.9,3.9,-1.6)
	var anim=animator(sky)
	match kind:
		"snow","rain":
			for p in [Vector3(-.3,0,0),Vector3(.25,.12,.05),Vector3(.7,-.05,0)]:Visuals.box(sky,p,Vector3(.8,.35,.6),Color("e4e6e0") if kind=="snow" else Color("9aa3a6"))
			for set_index in range(2):
				var drops=Node3D.new();sky.add_child(drops)
				for i in range(4):
					var d=Visuals.box(drops,Vector3(-.5+i*.4,-.55-(i%2)*.3-set_index*.15,.1*set_index),Vector3(.1,.1,.1) if kind=="snow" else Vector3(.04,.32,.04),Color("ffffff") if kind=="snow" else Color("8fc7ff"))
					d.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				anim.add(drops,"visible",[set_index==0,set_index==1])
		"sun":
			var disc=cylinder(sky,Vector3.ZERO,.35,.08,Color("ffd27a"),12);disc.rotation.x=PI*.5;disc.material_override=Visuals.material(Color("ffd27a"),true)
			var rays=Node3D.new();sky.add_child(rays)
			for i in range(6):
				var ray=Visuals.box(rays,Vector3(cos(i*TAU/6)*.6,sin(i*TAU/6)*.6,0),Vector3(.22,.07,.05),Color("ffe29a"));ray.rotation.z=i*TAU/6
			anim.add(rays,"rotation:z",[0.0,.26,.52])
		"fog":
			for i in range(2):
				var band=Visuals.box(sky,Vector3(-.2+i*.4,-1.6-i*.35,0),Vector3(1.6,.12,.9),Color(.92,.93,.9,.55));band.material_override=Visuals.material(Color(.92,.93,.9,.55),true)
				anim.add(band,"position:x",[-.2+i*.4,.1+i*.4,.4+i*.4,.1+i*.4])
		"embers":
			for i in range(3):
				var ember=Visuals.box(sky,Vector3(-.4+i*.4,-1.8,0),Vector3(.12,.12,.12),Color("ff8a3d"));ember.material_override=Visuals.material(Color("ff8a3d"),true)
				anim.add(ember,"position:y",[-1.8-i*.2,-1.3-i*.2,-.8-i*.2,-2.3])
static func weather_for(entry:Dictionary)->String:
	var kinds:Array=entry.get("kinds",[])
	if "ice" in kinds:return "snow"
	match str(entry.get("ambience","")):
		"marsh":return "rain"
		"desert":return "sun"
		"mountains":return "fog"
		"inferno":return "embers"
	return ""
## Boss arena: scorched plate, the boss hull in the middle, crossing searchlights and red beacons.
## The general's lair: an iron throne. Dark plated platform ringed with bayonets, a fan of welded steel plates
## with spikes behind the boss tank, two fire braziers, red beacons and sweeping searchlights.
static func boss(parent:Node3D,_color:Color):
	var iron=Color("3b3a37");var steel=Color("595a55");var rust=Color("6b4434")
	base(parent,iron)
	var anim=animator(parent)
	# Throne back: plates of different heights, fanned, with spikes on top.
	for i in range(7):
		var k=i-3;var h=2.4+(3-absi(k))*.6
		var plate=Visuals.box(parent,Vector3(k*.66,h*.5+.2,-2.35+absi(k)*.14),Vector3(.6,h,.18),steel.darkened(.08*(i%2)) if i!=3 else rust)
		plate.rotation.y=k*-.12;plate.rotation.z=k*.05
		var spike=cylinder(parent,Vector3(k*.66,h+.2,-2.35+absi(k)*.14),.13,.8,Color("8d8f88"),4,0.0);spike.rotation.z=k*.05
	# Bayonets around the edge, leaning outwards.
	for i in range(14):
		var a=i*TAU/14.0;var at=Vector3(cos(a)*2.95,.25,sin(a)*2.95)
		if at.z<-1.6 and absf(at.x)<2.2:continue
		var blade=cylinder(parent,at,.09,1.15,Color("b5b7b0"),4,0.0)
		blade.rotation=Vector3(sin(a)*.45,0,-cos(a)*.45)
	# The general's tank, larger than any other piece on the map.
	var hull=Visuals.model("boss",parent);hull.scale=Vector3.ONE*1.55;hull.position=Vector3(0,.3,.1);hull.rotation.y=PI
	# Fire braziers: dark pots with flickering flames.
	for side in [-1,1]:
		var pot=cylinder(parent,Vector3(side*2.25,.28,1.75),.4,.5,iron,8,.5)
		for core in [false,true]:
			var flame=cylinder(parent,Vector3(side*2.25,.78,1.75),.38 if not core else .22,.95 if not core else .55,Color(1,.48,.12) if not core else Color(1,.86,.4),6,0.0)
			flame.material_override=Visuals.material(Color(1,.48,.12) if not core else Color(1,.86,.4),true)
			anim.add(flame,"scale",[Vector3(1,1,1),Vector3(.9,1.25,.9),Vector3(1.05,.85,1.05)] if not core else [Vector3(1,1.2,1),Vector3(.9,.9,.9),Vector3(1,1.1,1)])
	for side in [-1,1]:
		var mast=cylinder(parent,Vector3(side*2.6,.3,-1.4),.07,2.6,Color("3e423d"),6)
		var head=Node3D.new();parent.add_child(head);head.position=Vector3(side*2.6,2.9,-1.4)
		var beam=Visuals.box(head,Vector3(0,-.4,1.5),Vector3(.35,.05,3.0),Color(1,.9,.7,.3));beam.material_override=Visuals.material(Color(1,.9,.7,.3),true)
		anim.add(head,"rotation:y",[side*-.5,0.0,side*.5,0.0])
		var beacon=Visuals.box(parent,Vector3(side*2.6,3.2,-1.4),Vector3(.22,.22,.22),Color("ff4a3a"));beacon.material_override=Visuals.material(Color("ff4a3a"),true)
		anim.add(beacon,"visible",[side==1,side==-1])
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
		"survive":
			for p in [Vector3(-1.2,0,-.8),Vector3(1,0,.6),Vector3(-.2,0,1.3)]:
				var ring=Visuals.ring(parent,Color("d8453a"),.9);ring.position=p+Vector3(0,.32,0)
			Visuals.box(parent,Vector3(.9,.7,-1),Vector3(.5,.8,.5),Color("6d6a5c"))
