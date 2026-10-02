extends Node3D
## Field dressing, own RNG (never the combat RNG):
## - urban biomes: packs of 1×2 cargo containers — indestructible cover (concrete rules), two harmonious
##   colours per field, six side ribs, doors on the ends; a pack is a full block (two stacked) or a half
##   block (one high). A pack is only kept if every entrance still reaches the HQ.
## - every field: a little floor clutter — paper, brick bits, a helmet — sparse and flat, visual only.
const PAIRS=[["b0563c","3f6f8a"],["c2873a","4f6d5a"],["8a3b34","6f7f86"],["3d6b7d","c9a24a"],["5b7048","a65a3a"]]
const RIBS=6
var arena
var rng=RandomNumberGenerator.new()
func setup(context):
	arena=context;name="FieldDressing"
	rng.seed=hash([arena.run_seed,arena.room_index,"field_dressing"])
	if arena.boss_room:return
	if arena.room.mode=="battle" and str(arena.room_palette().get("family",""))=="urban":containers()
	if arena.room.mode!="maze":clutter()
func free_cell(cell:Vector2i)->bool:
	var g=arena.grid_size
	if cell.x<1 or cell.x>g-2 or cell.y<3 or cell.y>g-5:return false
	if cell.x in arena.spawn_columns() and cell.y<=3:return false
	for q in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
		if arena.terrain.patches.has(cell*2+q):return false
	return not arena.walls.has(cell) and not arena.room.trenches.has(cell) and not arena.nets.has(cell) and arena.current_layout[cell.y][cell.x]=="."
## Every spawn marker cell on row 0 and the side rows must still reach the HQ apron.
func connected()->bool:
	var g=arena.grid_size;var start=Vector2i(arena.room.base_cell.x,g-2)
	var seen={start:true};var queue=[start]
	while not queue.is_empty():
		var at=queue.pop_front()
		for d in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			var to=at+d
			if seen.has(to) or not arena.inside(to) or arena.walls.has(to) or arena.terrain.movement_blocked_at_cell(to):continue
			seen[to]=true;queue.append(to)
	return arena.spawn_columns().all(func(x):return seen.has(Vector2i(x,0)) or seen.has(Vector2i(x,1)))
func containers():
	var pair=PAIRS[rng.randi_range(0,PAIRS.size()-1)]
	var packs=rng.randi_range(1,2)+(1 if arena.grid_size>=17 else 0)
	for attempt in range(packs*12):
		if packs<=0:break
		var along_x=rng.randf()<.6
		var size=rng.randi_range(1,3)
		var origin=Vector2i(rng.randi_range(1,arena.grid_size-3),rng.randi_range(3,arena.grid_size-6))
		# A pack: `size` containers side by side, each 1×2 along its axis.
		var cells=[]
		for k in range(size):
			var a=origin+(Vector2i(0,k) if along_x else Vector2i(k,0))
			cells.append([a,a+(Vector2i.RIGHT if along_x else Vector2i.DOWN)])
		if not cells.all(func(c):return free_cell(c[0]) and free_cell(c[1])):continue
		for c in cells:
			for cell in c:arena.board.add_wall(cell,-1)
		if not connected():
			for c in cells:
				for cell in c:remove(cell)
			continue
		var tall=rng.randf()<.45
		for c in cells:
			for cell in c:
				var wall=arena.walls[cell];wall["style_kind"]="container"
				# The layout knows the container too, so terrain and later passes treat it as concrete.
				BattleMapGenerator.put(arena.current_layout,cell,"C")
				if is_instance_valid(wall.node):wall.node.visible=false
			build(c,along_x,Color(pair[rng.randi_range(0,1)]),tall)
		packs-=1
func remove(cell:Vector2i):
	var wall=arena.walls.get(cell,{})
	if not wall.is_empty() and is_instance_valid(wall.node):wall.node.queue_free()
	arena.walls.erase(cell);arena.navigation.invalidate(cell)
## One container (two stacked when tall) over cells c[0]–c[1].
func build(c:Array,along_x:bool,color:Color,tall:bool):
	var root=Node3D.new();root.name="Container";add_child(root)
	root.position=(arena.world_pos(c[0])+arena.world_pos(c[1]))*.5
	root.rotation.y=0.0 if along_x else PI*.5
	for level in range(2 if tall else 1):
		var tint=color if level==0 else color.lerp(Color("d8d2c0"),.12)
		var y=.42+level*.84
		Visuals.box(root,Vector3(0,y,0),Vector3(1.92,.8,.9),tint)
		for side in [-1,1]:
			for i in range(RIBS):
				var x=-.8+i*(1.6/(RIBS-1))
				Visuals.box(root,Vector3(x,y,side*.455),Vector3(.06,.72,.02),tint.darkened(.18))
			# Doors on both ends: two leaves with lock bars.
		for end in [-1,1]:
			Visuals.box(root,Vector3(end*.965,y,0),Vector3(.02,.74,.84),tint.darkened(.12))
			for z in [-.2,.2]:Visuals.box(root,Vector3(end*.98,y,z),Vector3(.02,.66,.035),Color("4a4a46"))
		Visuals.box(root,Vector3(0,y+.405,0),Vector3(1.94,.03,.92),tint.lightened(.08))
## Sparse flat clutter on free floor: paper sheets, brick bits, a dropped helmet.
func clutter():
	var count=int(arena.grid_size*.45)
	var palette=arena.room_palette()
	for i in range(count):
		var cell=Vector2i(rng.randi_range(1,arena.grid_size-2),rng.randi_range(1,arena.grid_size-3))
		if arena.walls.has(cell) or arena.room.trenches.has(cell) or arena.terrain.movement_blocked_at_cell(cell):continue
		var spot=arena.world_pos(cell)+Vector3(rng.randf_range(-.38,.38),0,rng.randf_range(-.38,.38))
		var bit=Node3D.new();bit.name="Clutter";add_child(bit);bit.position=spot;bit.rotation.y=rng.randf()*TAU
		match rng.randi_range(0,3):
			0:Visuals.box(bit,Vector3(0,.006,0),Vector3(.16,.006,.11),Color("d9d3c2").darkened(rng.randf_range(0,.15)))
			1:
				for k in range(rng.randi_range(2,3)):Visuals.box(bit,Vector3(rng.randf_range(-.08,.08),.02,rng.randf_range(-.08,.08)),Vector3(.07,.04,.05),Color(palette.brick).darkened(rng.randf_range(0,.2)))
			2:
				var helmet=MeshInstance3D.new();var dome=SphereMesh.new();dome.radius=.08;dome.height=.08;dome.is_hemisphere=true;helmet.mesh=dome
				helmet.material_override=Visuals.material(Color("5f6744"));bit.add_child(helmet)
			3:Visuals.box(bit,Vector3(0,.015,0),Vector3(.09,.03,.05),Color("6f675a"))
		for child in bit.get_children():
			if child is GeometryInstance3D:child.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
