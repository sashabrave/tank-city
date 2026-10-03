extends Node3D
## Field approach (0.8): an improvised ramp for the HQ vehicle in front of the board — a packed-earth slope
## down from the rim to the ground, then a dirt track curving off to one side like an exit from a highway.
## Sandbags along the ramp, wheel ruts, a barrier pole and a couple of hedgehogs. Visual only, own RNG.
const WIDTH=2.3
const LENGTH=3.4

func build(arena,ground,seed_value:int):
	var rng=RandomNumberGenerator.new();rng.seed=hash([seed_value,"approach"])
	var palette:Dictionary=arena.room_palette()
	var earth=Color(str(palette.get("edge","7d8270"))).lerp(Color("6e5f48"),.45).darkened(.08)  # packed dirt, darker than the rim so the ramp reads
	var front=arena.grid_size*.5+preload("res://scripts/field_border.gd").WIDTH
	var x0=arena.world_pos(arena.base_cell).x
	var bottom=ground.height(x0,front+LENGTH) if ground else -1.0
	# The ramp: one sloped slab from the rim top down to the ground.
	var top=Vector3(x0,-.03,front);var foot=Vector3(x0,bottom+.02,front+LENGTH)
	var ramp=MeshInstance3D.new();var slab=BoxMesh.new();slab.size=Vector3(WIDTH,.3,top.distance_to(foot));ramp.mesh=slab
	ramp.material_override=Visuals.material(earth);add_child(ramp)
	ramp.position=(top+foot)*.5-Vector3(0,.15,0);ramp.rotation.x=atan2(top.y-foot.y,LENGTH)
	ramp.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Sandbags along both edges of the ramp, stepping down with it.
	var bag=Color("b9ad8a")
	for side in [-1.0,1.0]:
		for k in range(5):
			var t=(k+.5)/5.0;var p=top.lerp(foot,t)+Vector3(side*(WIDTH*.5+.12),.08,0)
			var sack=Visuals.box(self,p,Vector3(.24,.14,.5),bag.darkened(rng.randf_range(0,.12)));sack.rotation=Vector3(ramp.rotation.x,rng.randf_range(-.15,.15),0)
	# The track: a curve from the ramp foot off to one side, following the ground.
	var turn=-1.0 if rng.randf()<.5 else 1.0
	var a=foot;var c=foot+Vector3(turn*7.0,0,3.2);var d=foot+Vector3(turn*15.0,0,5.0)
	var points=[]
	for i in range(25):
		var t=i/24.0;var u=1.0-t
		var p=a*u*u*u+(a+Vector3(0,0,2.4))*3*u*u*t+c*3*u*t*t+d*t*t*t
		p.y=(ground.height(p.x,p.z) if ground else -1.0)+.03
		points.append(p)
	add_child(ribbon(points,WIDTH,0.0,earth))
	for side in [-.42,.42]:add_child(ribbon(points,.22,.012,earth.darkened(.18),side*WIDTH))
	for side in [-.42,.42]:
		var rut=Visuals.box(self,(top+foot)*.5+Vector3(side*WIDTH,.0,0),Vector3(.22,.32,top.distance_to(foot)),earth.darkened(.18))
		rut.rotation.x=ramp.rotation.x;rut.position.y-=.135;rut.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A striped barrier pole lifted at the foot, two hedgehogs on the outside of the curve.
	var pole_at=foot+Vector3(-turn*(WIDTH*.5+.35),0,.3)
	Visuals.box(self,pole_at+Vector3(0,.3,0),Vector3(.12,.6,.12),Color("5c6150"))
	var arm=Visuals.box(self,pole_at+Vector3(0,.95,-.2),Vector3(.07,1.3,.07),Color("e8e2d0"));arm.rotation.x=-.35
	for k in range(2):Visuals.box(self,pole_at+Vector3(0,.7+k*.42,-.12-k*.15),Vector3(.075,.16,.075),Color("cf613f")).rotation.x=-.35
	for k in range(2):
		var at=points[10+k*5]+Vector3(turn*.0,0,WIDTH*.9+k*.4)
		hedgehog(at,rng)

func hedgehog(at:Vector3,rng:RandomNumberGenerator):
	var hog=Node3D.new();add_child(hog);hog.position=at;hog.rotation.y=rng.randf()*TAU
	for axis in [Vector3(1,1,0),Vector3(-1,1,0),Vector3(0,1,1)]:
		var beam=Visuals.box(hog,Vector3(0,.22,0),Vector3(.07,.55,.07),Color("4f5443"))
		beam.basis=Basis(Vector3.UP.cross(axis.normalized()).normalized(),Vector3.UP.angle_to(axis.normalized()))

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
