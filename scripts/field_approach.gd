extends Node3D
## Field approach (0.8): a big trapezoid apron in front of the board — narrow end (80% of the field width)
## at the rim, wide end out on the ground — sloping down like a wide entry from a highway, with dirt tracks
## curving away to the left and to the right. Map-coloured, biome surface with random variations, tyre
## marks 10% darker on the lanes and tracks. Visual only, own RNG. BattleStage drives the HQ up one lane
## and away down the other (path_height gives the surface height, lane() the lane x).
const LENGTH=3.8
var front=0.0
var x0=0.0
var top_y=-.03
var ground=null
var narrow=4.0
var wide=6.4

func build(arena,ground_node,seed_value:int):
	ground=ground_node
	var rng=RandomNumberGenerator.new();rng.seed=hash([seed_value,"approach"])
	var palette:Dictionary=arena.room_palette();var family=str(palette.get("ambience","forest"))
	front=arena.grid_size*.5+preload("res://scripts/field_border.gd").WIDTH
	x0=0.0
	narrow=arena.grid_size*.8;wide=narrow*rng.randf_range(1.3,1.45)
	var edge=Color(str(palette.get("edge","7d8270")));var floor=Color(str(palette.get("floor","9aa08a")))
	# As close to the map colour as possible, so the apron does not stand out (author, 0.8).
	var earth=floor.lerp(edge,.25).darkened(.03)
	apron(earth)
	match family:
		"city":slabs(earth,rng)
		"marsh":planks(earth,rng)
		"mountains":gravel(earth,rng,Color("eef0ee"))
		"inferno":gravel(earth,rng,Color("3a3230"))
		_:pass  # plain map-coloured earth; tyre marks come with the lanes
	dressing(arena,earth,rng)
	var tyre=floor.darkened(.1)
	for side in [-1.0,1.0]:track(earth,tyre,side)
	for side in [-1.0,1.0]:
		for wheel in [-.5,.5]:
			for k in range(10):lay(Vector3(.16,.012,LENGTH/10.0),(lane(side)+wheel)/(lerpf(narrow,wide,(k+.5)/10.0)*.5),(k+.5)/10.0,tyre)

## Surface height of the approach at a ground point (for the arriving HQ); board top inside the field.
func path_height(p:Vector3)->float:
	if p.z<=front:return 0.0
	var outer=ground_height(p.x,front+LENGTH)
	if p.z<=front+LENGTH:return lerpf(top_y,outer,(p.z-front)/LENGTH)
	return ground_height(p.x,p.z)
func ground_height(x:float,z:float)->float:return ground.height(x,z) if ground else -1.0
## Lane x on the apron for a side (-1 left, 1 right).
func lane(side:float)->float:return side*narrow*.27

## The trapezoid: top surface plus side skirts down to the ground, one mesh.
func apron(color:Color):
	var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a=Vector3(x0-narrow*.5,top_y,front);var b=Vector3(x0+narrow*.5,top_y,front)
	var far_z=front+LENGTH
	var c=Vector3(x0+wide*.5,ground_height(x0+wide*.5,far_z)+.03,far_z);var d=Vector3(x0-wide*.5,ground_height(x0-wide*.5,far_z)+.03,far_z)
	for p in [a,b,c,a,c,d]:tool.add_vertex(p)
	for pair in [[a,d],[b,c]]:
		var top_a:Vector3=pair[0];var top_b:Vector3=pair[1]
		var low_a=Vector3(top_a.x,ground_height(top_a.x,top_a.z)-.05,top_a.z);var low_b=Vector3(top_b.x,ground_height(top_b.x,top_b.z)-.05,top_b.z)
		for p in [top_a,top_b,low_b,top_a,low_b,low_a]:tool.add_vertex(p)
	tool.generate_normals()
	var node=MeshInstance3D.new();node.mesh=tool.commit();node.material_override=Visuals.material(color)
	node.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)

## A point on the apron surface: u across (-1 left … 1 right), v along (0 rim … 1 outer end).
func on_apron(u:float,v:float,lift:=.02)->Vector3:
	var half=lerpf(narrow,wide,v)*.5;var p=Vector3(x0+u*half,0,front+v*LENGTH)
	p.y=path_height(p)+lift;return p
func lay(size:Vector3,u:float,v:float,color:Color,yaw:=0.0)->MeshInstance3D:
	var node=Visuals.box(self,on_apron(u,v,size.y*.5),size,color)
	var slope=atan2(top_y-path_height(Vector3(x0,0,front+LENGTH)),LENGTH)
	node.rotation=Vector3(slope,yaw,0);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;return node

func ruts(color:Color,rng):
	for side in [-.32,.32]:
		for k in range(8):lay(Vector3(.26,.015,LENGTH/8.0*.95),side+rng.randf_range(-.03,.03),(k+.5)/8.0,color.darkened(.2+rng.randf()*.08))
func slabs(color:Color,rng):
	for row in range(4):
		for col in range(3):
			if rng.randf()<.15:continue
			lay(Vector3(lerpf(narrow,wide,(row+.5)/4.0)/3.0*.9,.04,LENGTH/4.0*.88),-.66+col*.66,(row+.5)/4.0,color.lightened(rng.randf_range(-.04,.08)),rng.randf_range(-.04,.04))
func planks(color:Color,rng):
	for k in range(14):lay(Vector3(lerpf(narrow,wide,(k+.5)/14.0)*.8,.05,.2),rng.randf_range(-.05,.05),(k+.5)/14.0,Color("7d6648").lerp(color,.55).darkened(rng.randf()*.15),rng.randf_range(-.06,.06))
func gravel(color:Color,rng,accent:Color):
	for k in range(10):lay(Vector3(rng.randf_range(.3,.7),.03,rng.randf_range(.3,.6)),rng.randf_range(-.9,.9),rng.randf(),color.lerp(accent,.35),rng.randf()*TAU)

## Random military dressing: sandbag rows on 0–2 edges, a barrier pole, hedgehogs, crates, a tyre stack.
func dressing(arena,color:Color,rng):
	var bag=Color("b9ad8a")
	for side in [-1.0,1.0]:
		if rng.randf()<.35:continue
		for k in range(6):
			var v=(k+.5)/6.0;var u=side*1.04
			lay(Vector3(.26,.15,.5),u,v,bag.darkened(rng.randf_range(0,.12)),side*atan2((wide-narrow)*.5,LENGTH))
	var pole_side=-1.0 if rng.randf()<.5 else 1.0
	var pole_at=on_apron(pole_side*1.12,.92,0.0)
	Visuals.box(self,pole_at+Vector3(0,.3,0),Vector3(.12,.6,.12),Color("5c6150"))
	var arm=Visuals.box(self,pole_at+Vector3(-pole_side*.55,.62,0),Vector3(1.2,.07,.07),Color("e8e2d0"));arm.rotation.z=pole_side*.5
	for k in range(rng.randi_range(0,3)):hedgehog(on_apron(rng.randf_range(-1.6,-1.2) if rng.randf()<.5 else rng.randf_range(1.2,1.6),rng.randf_range(.3,1.0),0.0),rng)
	for k in range(rng.randi_range(0,2)):
		var crate=Visuals.model("crate",self,on_apron(rng.randf_range(1.15,1.4)*(-1.0 if rng.randf()<.5 else 1.0),rng.randf_range(.2,.9),0.0));crate.scale=Vector3.ONE*.6;crate.rotation.y=rng.randf()*TAU
	if rng.randf()<.5:
		var at=on_apron(rng.randf_range(1.2,1.45)*(-1.0 if rng.randf()<.5 else 1.0),rng.randf_range(.4,.95),0.0)
		for k in range(rng.randi_range(2,3)):preload("res://scripts/route_miniatures.gd").cylinder(self,at+Vector3(0,k*.13,0),.2,.12,Color("2c2c2a"),10,.2)

func hedgehog(at:Vector3,rng):
	var hog=Node3D.new();add_child(hog);hog.position=at;hog.rotation.y=rng.randf()*TAU
	for axis in [Vector3(1,1,0),Vector3(-1,1,0),Vector3(0,1,1)]:
		var beam=Visuals.box(hog,Vector3(0,.22,0),Vector3(.07,.55,.07),Color("4f5443"))
		beam.basis=Basis(Vector3.UP.cross(axis.normalized()).normalized(),Vector3.UP.angle_to(axis.normalized()))

## A dirt track from the lane at the wide end, curving away to its side and out of the frame, with tyre marks.
func track(color:Color,tyre:Color,side:float):
	var a=Vector3(lane(side),0,front+LENGTH);var c=a+Vector3(side*13.0,0,9.0);var d=a+Vector3(side*26.0,0,6.0)  # wide, lively arc that swings out and back
	var points=[]
	for i in range(25):
		var t=i/24.0;var u=1.0-t
		var p=a*u*u*u+(a+Vector3(0,0,4.5))*3*u*u*t+c*3*u*t*t+d*t*t*t
		p.y=ground_height(p.x,p.z)+.03;points.append(p)
	add_child(ribbon(points,wide*.3,0.0,color))
	for wheel in [-.5,.5]:add_child(ribbon(points,.16,.012,tyre,wheel))
	set_meta("track_left" if side<0 else "track_right",points)  # meta names must be identifiers

static func ribbon(points:Array,width:float,lift:float,color:Color,offset:=0.0)->MeshInstance3D:
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left=[];var right=[]
	for i in range(points.size()):
		var tangent=(points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var side=Vector3(-tangent.z,0,tangent.x).normalized()
		var center=points[i]+side*offset+Vector3.UP*lift
		left.append(center+side*width*.5);right.append(center-side*width*.5)
	for i in range(points.size()-1):
		for p in [left[i],right[i],right[i+1],left[i],right[i+1],left[i+1]]:surface.set_normal(Vector3.UP);surface.add_vertex(p)
	var mesh=MeshInstance3D.new();mesh.mesh=surface.commit();mesh.material_override=Visuals.material(color)
	mesh.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh
