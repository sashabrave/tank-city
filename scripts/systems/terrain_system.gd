extends RefCounted
## Half-cell floor ownership. Empty entries are ordinary floor; trenches own full cells.
var arena
var patches:Dictionary={}
var strips:Array=[]
var batches:Dictionary={}
var sand_mesh:ArrayMesh
func _init(context):arena=context
func half_pos(p:Vector2i)->Vector3:
	return Vector3(p.x*.5-arena.grid_size*.5+.25,0,p.y*.5-arena.grid_size*.5+.25)
func key(pos:Vector3)->Vector2i:
	return Vector2i(floori((pos.x+arena.grid_size*.5)*2),floori((pos.z+arena.grid_size*.5)*2))
func kind_at(pos:Vector3)->String:return patches.get(key(pos),"")
func water_at_cell(cell:Vector2i)->bool:return patches.get(cell*2,"")=="water"
func movement_blocked_at_cell(cell:Vector2i)->bool:return patches.get(cell*2,"") in ["water","vegetation"]
func blocked(pos:Vector3,half:float)->bool:
	var lo=key(pos-Vector3(half-.001,0,half-.001));var hi=key(pos+Vector3(half-.001,0,half-.001))
	for x in range(lo.x,hi.x+1):
		for y in range(lo.y,hi.y+1):
			if patches.get(Vector2i(x,y),"") in ["water","vegetation"]:return true
	return false
func speed_factor(actor)->float:return speed_factor_at(actor.position,actor)
func speed_factor_at(pos:Vector3,actor)->float:
	if actor.kind=="flyer":return 1.0
	var half=arena.body_size(actor)*.5
	for offset in [Vector3.ZERO,Vector3(half,0,half),Vector3(-half,0,half),Vector3(half,0,-half),Vector3(-half,0,-half)]:
		if kind_at(pos+offset)=="sand":return .55
	return 1.0
func navigation_cost(pos:Vector3,actor,direction:Vector2i)->float:
	if actor.kind=="flyer":return 1.0
	# Travel-time cost uses the very same sand slowdown as actual movement.
	var cost=1.0/speed_factor_at(pos,actor)
	if kind_at(pos)=="ice":
		# Ice remains usable, but a controllable route is preferable when comparable.
		cost+=.35
		var coast=pos+Vector3(direction.x,0,direction.y)*.5
		if not arena.navigation.is_open(coast,actor):cost+=1.5
	return cost
func begin_slide(actor)->bool:
	if actor.kind=="flyer" or actor.occupying_trench or actor.moving or actor.terrain_direction==Vector2i.ZERO:return false
	if kind_at(actor.position)=="ice":actor.slide_remaining=.5
	if actor.slide_remaining<=0:return false
	var next=actor.position+Vector3(actor.terrain_direction.x,0,actor.terrain_direction.y)*.25
	if not arena.can_stand(next,actor):
		actor.slide_remaining=0;actor.terrain_direction=Vector2i.ZERO;return false
	actor.slide_remaining=maxf(0,actor.slide_remaining-.25)
	actor.quarter_destination=next;actor.destination=arena.grid_pos(next);actor.terrain_sliding=true;actor.moving=true
	return true
func eligible(p:Vector2i)->bool:
	var c=Vector2i(p.x/2,p.y/2)
	if c.x<1 or c.x>=arena.grid_size-1 or c.y<2 or c.y>=arena.grid_size-3:return false
	if arena.boss_room:
		if abs(c.x-arena.base_cell.x)<=2:return false
		for corner in [Vector2i(2,2),Vector2i(arena.grid_size-3,2),Vector2i(2,arena.grid_size-3),Vector2i(arena.grid_size-3,arena.grid_size-3)]:
			if (c-corner).length()<2:return false
	if arena.room.mode!="battle" and ChallengeLayouts.keeps_clear(arena.grid_size,arena.room.mode,c):return false
	return arena.current_layout[c.y][c.x]=="." and not patches.has(p)
func set_cell(c:Vector2i,kind:String):
	for x in range(2):
		for y in range(2):patches[c*2+Vector2i(x,y)]=kind
func walkable(c:Vector2i,excluded:Vector2i)->bool:
	return arena.inside(c) and c!=excluded and not arena.walls.has(c) and not arena.trenches.has(c) and not movement_blocked_at_cell(c) and c!=arena.base_cell
func safe_water(c:Vector2i)->bool:
	# Removing a cell may not disconnect any of its previously connected neighbours.
	var neighbours=[]
	for dir in arena.DIRS:
		if walkable(c+dir,c):neighbours.append(c+dir)
	if neighbours.size()<2:return false
	var seen={neighbours[0]:true};var queue=[neighbours[0]];var head=0
	var remaining=neighbours.size()-1
	while head<queue.size():
		var p=queue[head];head+=1
		for dir in arena.DIRS:
			var n=p+dir
			if not seen.has(n) and walkable(n,c):
				seen[n]=true;queue.append(n)
				if n in neighbours:
					remaining-=1
					if remaining==0:return true
	for n in neighbours:
		if not seen.has(n):return false
	return true
func cell_eligible(c:Vector2i)->bool:
	for x in range(2):
		for y in range(2):
			if not eligible(c*2+Vector2i(x,y)):return false
	return true
func generate():
	patches.clear();strips.clear();arena.navigation.reset()
	var rng=RandomNumberGenerator.new();rng.seed=arena.run_seed+arena.room_index*100003+90173
	var kinds=arena.room_palette().kinds
	# One-cell ribbons share the same straight / L construction for ice and water.
	for kind in ["water","ice"]:
		if kind not in kinds:continue
		var remaining=terrain_budget()
		for strip in range(2+mini(arena.room_index,5)):
			for attempt in range(160):
				var p=Vector2i(rng.randi_range(1,arena.grid_size-2),rng.randi_range(2,arena.grid_size-4))
				var dir:Vector2i=arena.DIRS[rng.randi_range(0,3)]
				var length=rng.randi_range(1,mini(remaining,6 if arena.room.difficulty>=2 else 5))
				var bend=rng.randi_range(1,length-1) if length>2 and rng.randf()<.4 else -1
				var cells=[];var valid=true
				for step in range(length):
					if step==bend:dir=Vector2i(-dir.y,dir.x)
					if not cell_eligible(p):valid=false
					cells.append(p);p+=dir
				if not valid:continue
				for c in cells:
					if kind=="water" and not safe_water(c):valid=false;break
					set_cell(c,kind)
				if not valid:
					for c in cells:
						for x in range(2):
							for y in range(2):patches.erase(c*2+Vector2i(x,y))
					continue
				strips.append({"kind":kind,"width":1.0,"length":length,"bend":bend>=0,"cells":cells})
				remaining-=length;break
			if remaining<=0:break
	if "sand" in kinds:
		var count=0
		for attempt in range(160):
			var c=Vector2i(rng.randi_range(1,arena.grid_size-2),rng.randi_range(2,arena.grid_size-4))
			if not cell_eligible(c):continue
			set_cell(c,"sand");count+=1
			if count>=terrain_budget():break
	if "vegetation" in kinds:
		var count=0
		for attempt in range(240):
			var c=Vector2i(rng.randi_range(1,arena.grid_size-2),rng.randi_range(2,arena.grid_size-4))
			if not cell_eligible(c) or not safe_water(c):continue
			set_cell(c,"vegetation");count+=1
			if count>=terrain_budget():break
	arena.navigation.reset()
func terrain_budget()->int:
	# Grow both count and covered share toward the end of a world; retain open borders.
	var depth=mini(arena.room_index,5)
	return maxi(2,roundi(.85*maxi(3,ceili(arena.grid_size*arena.grid_size*(.018+depth*.004+mini(arena.room.difficulty,2)*.003)))))
func build():
	generate();batches.clear()
	var tint=Color(arena.room_palette().floor)
	var positions=[];var foundation=[]
	for z in range(arena.grid_size):
		for x in range(arena.grid_size):
			var c=Vector2i(x,z)
			if arena.trenches.has(c):continue
			foundation.append(arena.world_pos(c))
			if patches.get(c*2,"")=="vegetation":preload("res://scripts/vegetation_visual.gd").place(arena,c,tint)
			var special=false
			for dx in range(2):
				for dz in range(2):
					if patches.has(c*2+Vector2i(dx,dz)):special=true
			if not special:positions.append(arena.world_pos(c));continue
			for dx in range(2):
				for dz in range(2):draw_patch(c*2+Vector2i(dx,dz),tint)
	Visuals.battle_foundation(arena,foundation,arena.grid_size,Color(arena.room_palette().edge))
	Visuals.tiled_floor(arena,positions,tint)
	flush_batches()
	var fx=preload("res://scripts/systems/terrain_ambience.gd").new();fx.name="TerrainAmbience";arena.add_child(fx);fx.setup(self,tint)
func draw_patch(p:Vector2i,tint:Color):
	var kind=patches.get(p,"");var pos=half_pos(p)
	var color=tint;var height=.0
	if kind=="ice":color=tint.lerp(Color("a1c4d2"),.42)
	elif kind=="water":color=tint.lerp(Color("416d80"),.65).darkened(.12);height=-.035
	elif kind=="sand":color=tint.lerp(Color("c4ac77"),.58)
	elif kind=="vegetation":color=tint.darkened(.10)
	if kind=="water":
		# Water cells share one shader batch (shaders/world/water.gdshader), tinted by the biome.
		var mesh=BoxMesh.new();mesh.size=Vector3.ONE;mesh.subdivide_width=2;mesh.subdivide_depth=2
		batch("water",mesh,Transform3D(Basis.IDENTITY.scaled(Vector3(.5,.08,.5)),pos+Vector3(0,height-.04,0)),color,.2)
		batches.water["shader_tint"]=color
	else:batch_box(pos+Vector3(0,height-.04,0),Vector3(.5,.08,.5),color,.62 if kind=="ice" else .9)
	if kind=="ice":
		for i in range(2):batch_box(pos+Vector3(-.07+i*.13,height+.003,-.12+i*.21),Vector3(.19,.004,.009),(color.darkened(.16) if kind=="ice" else color.lightened(.2)),.9,.25 if kind=="water" else -.45+i*.7)
	elif kind=="sand":
		if sand_mesh==null:
			var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in range(3):
				var z=-.17+i*.16
				var a=Vector3(-.24,0,z-.06);var b=Vector3(.24,0,z-.06);var c=Vector3(.24,0,z+.06);var d=Vector3(-.24,0,z+.06)
				var l=Vector3(-.24,.04,z);var r=Vector3(.24,.07,z+.018)
				for v in [a,l,b,b,l,r,l,d,r,r,d,c]:surface.add_vertex(v)
			surface.generate_normals();sand_mesh=surface.commit()
		batch("ridges",sand_mesh,Transform3D(Basis.IDENTITY,pos),color.lightened(.035),.9)
func batch_box(pos:Vector3,size:Vector3,color:Color,rough:float,rotation:float=0):
	var mesh=BoxMesh.new();mesh.size=Vector3.ONE
	batch(str(color)+str(rough),mesh,Transform3D(Basis(Vector3.UP,rotation).scaled_local(size),pos),color,rough)
func batch(id:String,mesh:Mesh,transform:Transform3D,color:Color,rough:float):
	if not batches.has(id):batches[id]={"mesh":mesh,"transforms":[],"color":color,"rough":rough}
	batches[id].transforms.append(transform)
func flush_batches():
	for data in batches.values():
		var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=data.mesh;multi.instance_count=data.transforms.size()
		for i in range(data.transforms.size()):multi.set_instance_transform(i,data.transforms[i])
		var node=MultiMeshInstance3D.new();node.name="TerrainBatch";node.multimesh=multi
		if data.has("shader_tint"):
			var water=ShaderMaterial.new();water.shader=preload("res://shaders/world/water.gdshader");var tint:Color=data.shader_tint
			water.set_shader_parameter("deep",tint.darkened(.38));water.set_shader_parameter("shallow",tint.lightened(.18));node.material_override=water
		else:node.material_override=Visuals.material(data.color);node.material_override.roughness=data.rough
		arena.add_child(node)
	batches.clear()
