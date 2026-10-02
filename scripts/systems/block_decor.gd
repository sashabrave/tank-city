extends RefCounted
## Visual-only dressing for blocks: tiny same-colour debris, weather caps and corner drifts.
## Everything is a child of the wall node, so it disappears with the block. Separate visual RNG.
static var sphere:SphereMesh
static var box:BoxMesh
static var tinted:={}

static func meshes():
	if sphere:return
	sphere=SphereMesh.new();sphere.radius=.5;sphere.height=1.0;sphere.radial_segments=16;sphere.rings=8
	box=BoxMesh.new();box.size=Vector3.ONE

static func material(color:Color)->StandardMaterial3D:
	var key=color.to_html()
	if not tinted.has(key):tinted[key]=Visuals.material(color)
	return tinted[key]

## Block bounds in world space (merged mesh AABBs); blocks may be rotated.
static func bounds(node:Node3D)->AABB:
	var result=AABB();var first=true
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		if mesh.is_in_group("block_dressing") or fixture(node,mesh):continue
		var box_bounds:AABB=mesh.global_transform*mesh.get_aabb()
		result=box_bounds if first else result.merge(box_bounds);first=false
	return result if not first else AABB(node.global_position+Vector3(-.45,0,-.45),Vector3(.9,1,.9))

## Concrete halves and L-cuts are made of quarters: a 2×2 grid. Each quarter is probed nearer the block centre so
## bevelled corners do not read as holes.
const TOP_GRID=2
## Height of the highest upward face over each quarter of the block bounds (NAN where nothing is there).
## Half and L-shaped concrete leave some quarters empty: caps there would hang in the air.
static func top_cells(node:Node3D,area:AABB)->Array:
	var triangles=[]
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		if mesh.is_in_group("block_dressing") or fixture(node,mesh) or mesh.mesh==null:continue
		var faces:PackedVector3Array=mesh.mesh.get_faces();var xf:Transform3D=mesh.global_transform
		for i in range(0,faces.size(),3):
			var a=xf*faces[i];var b=xf*faces[i+1];var c=xf*faces[i+2]
			if absf((b-a).cross(c-a).normalized().y)>.85 and minf(a.y,minf(b.y,c.y))>area.position.y+area.size.y*.5:triangles.append([a,b,c])
	var result=[];var cell=Vector2(area.size.x,area.size.z)/TOP_GRID;var middle=Vector2(area.get_center().x,area.get_center().z)
	for row in TOP_GRID:
		for column in TOP_GRID:
			var corner=Vector2(area.position.x+(column+.5)*cell.x,area.position.z+(row+.5)*cell.y)
			var height=NAN
			# A few probes per quarter: a probe on a shared triangle edge may miss both triangles.
			for probe in [middle.lerp(corner,.7),middle.lerp(corner,.55)+Vector2(.013,.007),middle.lerp(corner,.85)-Vector2(.009,.011)]:
				for t in triangles:
					if Geometry2D.point_is_inside_triangle(probe,Vector2(t[0].x,t[0].z),Vector2(t[1].x,t[1].z),Vector2(t[2].x,t[2].z)):
						var top=maxf(t[0].y,maxf(t[1].y,t[2].y));height=top if is_nan(height) else maxf(height,top)
			result.append(height)
	return result

## Lamps, floodlights and light cones mounted on a block are not part of its shape.
static func fixture(root:Node,mesh:Node)->bool:
	var node=mesh
	while node and node!=root:
		if node is Light3D or str(node.name) in ["MilitaryLightStand","Floodlight","SoftCone","HeadlightRig"]:return true
		node=node.get_parent()
	return false

static func piece(parent:Node3D,mesh:Mesh,color:Color,pos:Vector3,size:Vector3,yaw:float,group:="block_dressing")->MeshInstance3D:
	var node=MeshInstance3D.new();node.mesh=mesh;node.material_override=material(color)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.add_to_group("block_dressing")
	if group!="block_dressing":node.add_to_group(group)
	# pos is world space; the prop keeps a world-aligned orientation under a rotated block.
	parent.add_child(node);node.global_transform=Transform3D(Basis(Vector3.UP,yaw).scaled(size),pos)
	return node

## Three or four small props: rubble chips, pebbles, a plank, a pipe stub. Same tint as the block.
static func decorate(arena):
	meshes()
	var rng=RandomNumberGenerator.new();rng.seed=hash([Game.visual_run_seed,arena.room_index,"block_decor"])
	var palette=arena.room_palette()
	for cell in arena.walls:
		var wall=arena.walls[cell]
		if not is_instance_valid(wall.node) or rng.randf()>.55:continue
		var solid=wall.hp<0
		var tint=Color(palette.wall if solid else palette.brick).darkened(rng.randf_range(.08,.18))
		var area=bounds(wall.node)
		for i in range(rng.randi_range(1,2)):
			# Concrete tops stay intact; brick loses sections, so its props lie at the foot.
			var pos:Vector3
			if solid:pos=Vector3(rng.randf_range(area.position.x+.12,area.end.x-.12),area.end.y,rng.randf_range(area.position.z+.12,area.end.z-.12))
			else:pos=Vector3(area.get_center().x+rng.randf_range(-.4,.4),0.0,area.end.z+rng.randf_range(.04,.12))
			prop(wall.node,rng,tint,pos)

static func prop(parent:Node3D,rng:RandomNumberGenerator,tint:Color,pos:Vector3):
	var yaw=rng.randf()*TAU
	match rng.randi_range(0,3):
		0:
			for i in range(rng.randi_range(2,3)):
				var s=rng.randf_range(.05,.1)
				piece(parent,box,tint.lightened(rng.randf_range(0,.08)),pos+Vector3(rng.randf_range(-.08,.08),s*.35,rng.randf_range(-.08,.08)),Vector3(s,s*.7,s*rng.randf_range(.8,1.3)),yaw+i)
		1:
			for i in range(rng.randi_range(2,3)):
				var s=rng.randf_range(.05,.08)
				piece(parent,sphere,tint,pos+Vector3(rng.randf_range(-.07,.07),s*.25,rng.randf_range(-.07,.07)),Vector3(s,s*.6,s*1.1),yaw)
		2:piece(parent,box,tint.darkened(.06),pos+Vector3(0,.012,0),Vector3(.28,.024,.05),yaw)
		3:piece(parent,box,tint.darkened(.1),pos+Vector3(0,.022,0),Vector3(.2,.045,.045),yaw)

## Snow/sand: pillow caps on some blocks, rare smooth L-drifts at the camera-facing corner.
static func drifts(arena,kind:String):
	meshes()
	var rng=RandomNumberGenerator.new();rng.seed=hash([Game.visual_run_seed,arena.room_index,"drifts",kind])
	var snow=kind=="snow"
	var color=Color("f3f6fa") if snow else Color(arena.room_palette().floor).lightened(.1)
	for cell in arena.walls:
		var wall=arena.walls[cell]
		if not is_instance_valid(wall.node):continue
		var area=bounds(wall.node)
		var size=area.size
		if wall.hp<0 and rng.randf()<(.6 if snow else .3):
			var cover=1.0 if snow else rng.randf_range(.55,.8)
			var offset=Vector3.ZERO if snow else Vector3(rng.randf_range(-.1,.1),0,rng.randf_range(-.1,.1))
			var top=Vector3(area.get_center().x,area.end.y,area.get_center().z)+offset
			var heights=top_cells(wall.node,area)
			var present=heights.filter(func(h):return not is_nan(h))
			var flat=present.size()==heights.size() and present.max()-present.min()<.03
			if flat or present.is_empty():
				# Square pillow that follows the block top, plus a soft rounded crown.
				if not present.is_empty():top.y=present.max()
				if snow:piece(wall.node,box,color,top+Vector3(0,.02,0),Vector3(size.x*.97,.04,size.z*.97),0.0,"weather_drifts")
				piece(wall.node,sphere,color,top+Vector3(0,.035 if snow else 0.0,0),Vector3(size.x*.84*cover,.1 if snow else .08,size.z*.84*cover),0.0,"weather_drifts")
			else:
				# Half and L-shaped blocks or raised details: a pillow on each real top quarter at its own height,
				# never over the empty part.
				var step=Vector2(size.x,size.z)/TOP_GRID
				for i in heights.size():
					if is_nan(heights[i]):continue
					var center=Vector3(area.position.x+(i%TOP_GRID+.5)*step.x,heights[i],area.position.z+(i/TOP_GRID+.5)*step.y)
					if snow:piece(wall.node,box,color,center+Vector3(0,.02,0),Vector3(step.x*.97,.04,step.y*.97),0.0,"weather_drifts")
					piece(wall.node,sphere,color,center+Vector3(0,.03 if snow else 0.0,0),Vector3(step.x*.8*cover,.07 if snow else .06,step.y*.8*cover),0.0,"weather_drifts")
		if rng.randf()<(.14 if snow else .2):
			# Front edge faces the camera; the side arm goes to the visible right more often.
			var side=1.0 if rng.randf()<.7 else -1.0
			var height=.16 if snow else .11
			piece(wall.node,sphere,color,Vector3(area.get_center().x,0.0,area.end.z+.02),Vector3(size.x*1.05,height,.3),0.0,"weather_drifts")
			var x=area.end.x+.02 if side>0 else area.position.x-.02
			piece(wall.node,sphere,color,Vector3(x,0.0,area.get_center().z+size.z*.2),Vector3(.3,height*.9,size.z*.8),0.0,"weather_drifts")
