extends RefCounted
const STEP=.25
static var brick_mesh:ArrayMesh
static var brick_material:ShaderMaterial
const ROWS=4
const ROW_HEIGHT=.1875
const MORTAR=Color(.66,.58,.50)
const REINFORCED_TINT=Vector3(.66,.52,.48)
const CLAY=Color(.94,.52,.29)
const BRICK=Vector3(.246,.172,.1235)
const CORE=.244
const CORE_HEIGHT=.74
static func prepare_visual():
	if brick_mesh:return
	# One section = 4 courses x 2 bricks around a mortar core; courses alternate direction.
	# The core nearly fills the cell so neighbouring sections leave no see-through slit; bricks stand
	# out of it by ~2 mm, which keeps thin, dense joints.
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_box(surface,Vector3(0,CORE_HEIGHT*.5,0),Vector3(CORE,CORE_HEIGHT,CORE),Color(MORTAR.r,MORTAR.g,MORTAR.b,0))
	for row in range(ROWS):
		for side in [-1,1]:
			var id=row*2+(side+1)/2
			var jitter=func(salt:int)->float:return fposmod(sin(float(id*37+salt*11))*43758.545,1.0)-.5
			var along_x=row%2==0
			var size=Vector3(BRICK.x+jitter.call(1)*.002,BRICK.y+jitter.call(2)*.004,BRICK.z)
			var offset=Vector3(jitter.call(3)*.001,0,side*.0625+jitter.call(4)*.0008)
			if not along_x:size=Vector3(size.z,size.y,size.x);offset=Vector3(offset.z,0,offset.x)
			offset.y=row*ROW_HEIGHT+.009+size.y*.5
			var tint=.9+jitter.call(5)*.2
			add_box(surface,offset,size,Color(CLAY.r*tint,CLAY.g*tint,CLAY.b*tint,(id+1)/8.0))
	brick_mesh=surface.commit()
	brick_material=ShaderMaterial.new();brick_material.shader=preload("res://assets/shaders/brick_sections.gdshader")
static func add_box(surface:SurfaceTool,center:Vector3,size:Vector3,color:Color):
	var h=size*.5
	var faces=[[Vector3.RIGHT,Vector3.BACK,Vector3.UP],[Vector3.LEFT,Vector3.FORWARD,Vector3.UP],[Vector3.UP,Vector3.RIGHT,Vector3.BACK],[Vector3.DOWN,Vector3.RIGHT,Vector3.FORWARD],[Vector3.BACK,Vector3.LEFT,Vector3.UP],[Vector3.FORWARD,Vector3.RIGHT,Vector3.UP]]
	for face in faces:
		var n:Vector3=face[0];var u:Vector3=face[1];var v:Vector3=face[2]
		var c=center+n*h;var du=u*h;var dv=v*h
		var quad=[c-du-dv,c+du-dv,c+du+dv,c-du+dv]
		for index in [0,1,2,0,2,3]:
			surface.set_color(color);surface.set_normal(n);surface.add_vertex(quad[index])
static var reinforced_material:ShaderMaterial
static var rebar_material:StandardMaterial3D
const STEEL=Color(.24,.26,.28)
const RUST=Color(.46,.25,.14)
static func create(parent:Node3D,hp:float,reinforced:=false)->Dictionary:
	prepare_visual()
	var cells=[]
	var mesh=MultiMeshInstance3D.new();var batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.mesh=brick_mesh;batch.instance_count=16;mesh.multimesh=batch;parent.add_child(mesh)
	mesh.material_override=brick_material
	if reinforced:
		if reinforced_material==null:reinforced_material=brick_material.duplicate();reinforced_material.set_shader_parameter("clay_tint",REINFORCED_TINT)
		mesh.material_override=reinforced_material;rebar(parent,15)
	for i in range(16):
		cells.append(hp/4.0)
		batch.set_instance_transform(i,section_transform(i,true))
	return {"sections":cells,"section_batch":batch}
static func section_transform(i:int,alive:bool)->Transform3D:
	# Neighbouring sections turn 90 degrees so vertical joints never line up across the wall.
	var turn=((i%4+int(i/4))%2)*PI*.5+(int(i*7/3)%2)*PI
	return Transform3D(Basis(Vector3.UP,turn) if alive else Basis.IDENTITY.scaled(Vector3.ZERO),Vector3(-.375+(i%4)*STEP,0,-.375+int(i/4)*STEP))
static func set_half(wall:Dictionary,side:int):
	for i in range(16):
		var keep=(i%4<2 if side==0 else i%4>=2 if side==1 else i/4<2 if side==2 else i/4>=2 if side==3 else (i/4<2 if side<6 else i/4>=2) or (i%4<2 if side in [4,7] else i%4>=2))
		if not keep:wall.sections[i]=0.0
		if wall.has("section_batch"):wall.section_batch.set_instance_transform(i,section_transform(i,wall.sections[i]>0))
	if wall.get("reinforced",false):rebar(wall.node,quadrants(wall))
	if wall.hp>0:
		var fraction=.75 if side>=4 else .5
		wall.hp*=fraction;wall.max_hp*=fraction
static func overlap(wall:Dictionary,center:Vector3,pos:Vector3,half:Vector2)->bool:
	if not wall.has("sections"):return absf(pos.x-center.x)<half.x+.5-.001 and absf(pos.z-center.z)<half.y+.5-.001
	for i in range(16):
		if wall.sections[i]<=0:continue
		var x=center.x-.375+(i%4)*STEP;var z=center.z-.375+int(i/4)*STEP
		if absf(pos.x-x)<half.x+.125-.001 and absf(pos.z-z)<half.y+.125-.001:return true
	return false
static func hit(wall:Dictionary,center:Vector3,amount:float,impact:Vector3,direction:Vector3,width:float)->Array:
	var alive=wall.sections.map(func(hp):return hp>0)
	if direction.length_squared()<.01:
		for i in range(16):wall.sections[i]=maxf(0,wall.sections[i]-amount/4.0)
	else:
		var along_x=absf(direction.x)>absf(direction.z)
		var positive=direction.x>0 if along_x else direction.z>0
		for lane in range(4):
			var transverse=(center.z if along_x else center.x)-.375+lane*.25
			if absf(transverse-snappedf(impact.z if along_x else impact.x,.25))>=width*.5+.125-.001:continue
			var remaining=amount;var started=false
			for depth in range(4):
				var d=depth if positive else 3-depth
				var i=lane*4+d if along_x else d*4+lane
				var axis=(center.x if along_x else center.z)-.375+d*.25
				var distance=(axis-(impact.x if along_x else impact.z))*(1 if positive else -1)
				if distance<-.16:continue
				if wall.sections[i]<=0:
					if started:break
					continue
				started=true
				var spent=minf(remaining,wall.sections[i]);wall.sections[i]-=spent;remaining-=spent
				if remaining<=.0001:break
	wall.hp=0.0
	for i in range(16):
		wall.hp+=wall.sections[i]/4.0
		wall.section_batch.set_instance_transform(i,section_transform(i,wall.sections[i]>.0001))
	var removed=[]
	for i in range(16):
		if alive[i] and wall.sections[i]<=0:removed.append(i)
	return removed

## Bit mask of the 2x2 quadrants that still hold sections: bit = qx + qz*2.
static func quadrants(wall:Dictionary)->int:
	var mask=0
	for i in range(16):
		if wall.sections[i]>0:mask|=1<<(int((i%4)/2)+int(i/8)*2)
	return mask

## Steel cage around the kept footprint: two straps, rods at segment ends and middles, a grid on top.
static var rebar_meshes:={}
static func rebar(parent:Node3D,mask:int):
	if not rebar_meshes.has(mask):
		var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var e=.502
		for q in range(4):
			if not mask&(1<<q):continue
			var qx=q%2;var qz=q/2;var cx=-.25+qx*.5;var cz=-.25+qz*.5
			for dir in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var nx=qx+dir.x;var nz=qz+dir.y
				if nx>=0 and nx<=1 and nz>=0 and nz<=1 and mask&(1<<(nx+nz*2)):continue
				# Outer edges sit just outside the bricks; cut edges sit on the cut plane.
				var outer=nx<0 or nx>1 or nz<0 or nz>1
				var centre=Vector3(cx,0,cz)+Vector3(dir.x,0,dir.y)*(.25+(e-.5 if outer else .012))
				var along=Vector3(absf(dir.y),0,absf(dir.x))
				for y in [.17,.56]:add_box(surface,centre+Vector3(0,y,0),along*.52+Vector3(absf(dir.x),0,absf(dir.y))*.02+Vector3(0,.03,0),STEEL)
				for t in [-.25,0.0,.25]:add_box(surface,centre+along*t+Vector3(0,.385,0),Vector3(.028,.77,.028),STEEL)
			add_box(surface,Vector3(cx,.752,cz),Vector3(.52,.024,.024),STEEL);add_box(surface,Vector3(cx,.752,cz),Vector3(.024,.024,.52),STEEL)
			add_box(surface,Vector3(cx,.756,cz),Vector3(.045,.03,.045),RUST)
		rebar_meshes[mask]=surface.commit()
		if rebar_material==null:
			rebar_material=StandardMaterial3D.new();rebar_material.vertex_color_use_as_albedo=true;rebar_material.metallic=.55;rebar_material.roughness=.55
	var node=parent.get_node_or_null("Rebar")
	if node==null:node=MeshInstance3D.new();node.name="Rebar";node.material_override=rebar_material;parent.add_child(node)
	node.mesh=rebar_meshes[mask]
