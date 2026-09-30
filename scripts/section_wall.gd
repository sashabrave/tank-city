extends RefCounted
const STEP=.25
static var brick_mesh:ArrayMesh
static var brick_material:ShaderMaterial
static func prepare_visual():
	if brick_mesh:return
	var surface=SurfaceTool.new()
	for row in range(4):
		var box=BoxMesh.new();box.size=Vector3(.247,.176,.247)
		surface.append_from(box,0,Transform3D(Basis.IDENTITY,Vector3(0,.09375+row*.1875,0)))
	brick_mesh=surface.commit()
	brick_material=ShaderMaterial.new();brick_material.shader=preload("res://assets/shaders/brick_sections.gdshader")
static func create(parent:Node3D,hp:float)->Dictionary:
	prepare_visual()
	var cells=[]
	var mesh=MultiMeshInstance3D.new();var batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.mesh=brick_mesh;batch.instance_count=16;mesh.multimesh=batch;mesh.material_override=brick_material;parent.add_child(mesh)
	for i in range(16):
		cells.append(hp/4.0)
		batch.set_instance_transform(i,section_transform(i,true))
	return {"sections":cells,"section_batch":batch}
static func section_transform(i:int,alive:bool)->Transform3D:
	return Transform3D(Basis.IDENTITY if alive else Basis.IDENTITY.scaled(Vector3.ZERO),Vector3(-.375+(i%4)*STEP,0,-.375+int(i/4)*STEP))
static func set_half(wall:Dictionary,side:int):
	for i in range(16):
		var keep=(i%4<2 if side==0 else i%4>=2 if side==1 else i/4<2 if side==2 else i/4>=2 if side==3 else (i/4<2 if side<6 else i/4>=2) or (i%4<2 if side in [4,7] else i%4>=2))
		if not keep:wall.sections[i]=0.0
		if wall.has("section_batch"):wall.section_batch.set_instance_transform(i,section_transform(i,wall.sections[i]>0))
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
