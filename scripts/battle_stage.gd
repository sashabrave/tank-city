extends RefCounted
## Micro-staging of a battle room: the HQ drives in on an arc, the soldier steps out to his post and the
## brick defence snaps together course by course; at the end the soldier boards and the HQ drives off,
## scattering the bricks still standing in its way. Visual only: cells, walls and HP are in place from
## the first frame, only models, section transforms and labels move. Own RNG, no combat randomness.
const WALL=preload("res://scripts/section_wall.gd")
const ARRIVE=.85
const STEP_OUT=.3
const BRICKS_AT=.5

## Every staging tween is registered on the arena, so a new room (or a sandbox rebuild) stops the old
## ones before their captured nodes are freed.
static func stage_tween(arena,owner:Node=null)->Tween:
	var t:Tween=(owner if owner else arena).create_tween()
	var list:Array=arena.get_meta("stage_tweens",[]);list.append(t);arena.set_meta("stage_tweens",list)
	return t
static func stop(arena):
	for t in arena.get_meta("stage_tweens",[]):
		if t is Tween and t.is_valid():t.kill()
	arena.set_meta("stage_tweens",[])

static func side(arena)->float:
	return -1.0 if posmod(hash([Game.visual_run_seed,arena.room_index,"hq_arc"]),2)==0 else 1.0

static func bezier(a:Vector3,b:Vector3,c:Vector3,t:float)->Vector3:
	return a.lerp(b,t).lerp(b.lerp(c,t),t)

## Brick walls of the HQ defence: the rows in front of and beside the base, nearest first.
static func fort_walls(arena)->Array:
	var result=[]
	for cell in arena.walls:
		var wall=arena.walls[cell]
		if wall.hp>0 and wall.has("section_batch") and cell.y>=arena.grid_size-4 and absi(cell.x-arena.base_cell.x)<=3:result.append(cell)
	result.sort_custom(func(a,b):return a.distance_squared_to(arena.base_cell)<b.distance_squared_to(arena.base_cell))
	return result

static func intro(arena):
	stop(arena)
	var hq:Node3D=arena.base_model
	if not is_instance_valid(hq):return
	var rest=hq.position;var yaw=hq.rotation.y;var s=side(arena)
	if is_instance_valid(arena.presentation):arena.presentation.swoop_in(s)
	var start=rest+Vector3(s*5.5,0,3.2);var bend=rest+Vector3(s*4.2,0,-.6)
	for node in [arena.base_label,arena.base_bar]:
		if is_instance_valid(node):node.visible=false
	hq.position=start
	var drive=func(t:float):
		if not is_instance_valid(hq):return
		var p=bezier(start,bend,rest,t);var ahead=bezier(start,bend,rest,minf(1.0,t+.02))-p
		hq.position=p
		var heading=atan2(ahead.x,ahead.z) if ahead.length()>.001 else yaw
		hq.rotation.y=lerp_angle(heading,yaw,smoothstep(.6,1.0,t))
	var tween=stage_tween(arena)
	tween.tween_method(drive,0.0,1.0,ARRIVE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		if not is_instance_valid(hq):return
		arena.burst(rest,Color("d8cfb4"),.5)
		var squash=stage_tween(arena,hq);squash.tween_property(hq,"scale",Vector3(1.04,.94,1.04),.06);squash.tween_property(hq,"scale",Vector3.ONE,.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for node in [arena.base_label,arena.base_bar]:
			if is_instance_valid(node):node.visible=true;pop(node))
	step_out(arena,rest)
	build_bricks(arena)

## The soldier (or his vehicle) leaves the HQ and takes the start cell.
static func step_out(arena,from:Vector3):
	var actor=arena.player
	if not is_instance_valid(actor) or not is_instance_valid(actor.model):return
	var model:Node3D=actor.model;var home=model.position
	model.visible=false;set_marks(actor,false)
	var tween=stage_tween(arena,actor);tween.tween_interval(ARRIVE-.08)
	tween.tween_callback(func():
		if not is_instance_valid(model):return
		model.visible=true;model.position=home+(from-actor.position);model.scale=Vector3.ONE*.7
		set_marks(actor,true))
	tween.tween_property(model,"position",home,STEP_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(model,"scale",Vector3.ONE,STEP_OUT*.8)

## Staircase build: nearest cell first, inside a cell the sections rise diagonally; each drops in
## from a little above with a short overshoot. A damaged section is never redrawn.
static func build_bricks(arena):
	var cells=fort_walls(arena)
	for k in range(cells.size()):
		var wall=arena.walls[cells[k]];var batch:MultiMesh=wall.section_batch
		for i in range(16):
			if wall.sections[i]<=0:continue
			batch.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
			var delay=BRICKS_AT+k*.045+((i%4)+int(i/4))*.018
			var grow=func(p:float):
				if not is_instance_valid(arena) or not arena.walls.has(cells[k]) or arena.walls[cells[k]]!=wall or wall.sections[i]<=0:return
				var t=WALL.section_transform(i,true)
				t.basis=t.basis.scaled(Vector3(1,maxf(.05,p),1));t.origin.y+=(1.0-minf(p,1.0))*.45
				batch.set_instance_transform(i,t)
			var tween=stage_tween(arena);tween.tween_interval(delay)
			tween.tween_method(grow,0.0,1.0,.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Departure: the soldier walks into the HQ, the HQ drives off on an arc and knocks down the defence
## bricks it passes. `done` runs when it has left the field.
static func outro(arena,done:Callable):
	stop(arena)
	var hq:Node3D=arena.base_model
	if not is_instance_valid(hq):done.call();return
	var rest=hq.position;var s=side(arena)
	var actor=arena.player
	if is_instance_valid(actor) and is_instance_valid(actor.model):
		var model:Node3D=actor.model;set_marks(actor,false)
		var board=stage_tween(arena,actor)
		board.tween_property(model,"position",model.position+(rest-actor.position),STEP_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		board.parallel().tween_property(model,"scale",Vector3.ONE*.6,STEP_OUT)
		board.tween_callback(func():if is_instance_valid(model):model.visible=false)
	for node in [arena.base_label,arena.base_bar]:
		if is_instance_valid(node):node.visible=false
	if is_instance_valid(arena.presentation):arena.presentation.swoop_out(s,hq)
	var finish=rest+Vector3(-s*6.0,0,3.6);var bend=rest+Vector3(-s*.8,0,-2.2)
	var fort=fort_walls(arena);var knocked={}
	var drive=func(t:float):
		if not is_instance_valid(hq):return
		var p=bezier(rest,bend,finish,t);var ahead=bezier(rest,bend,finish,minf(1.0,t+.02))-p
		hq.position=p
		if ahead.length()>.001:hq.rotation.y=lerp_angle(hq.rotation.y,atan2(ahead.x,ahead.z),.35)
		for cell in fort:
			if knocked.has(cell) or not arena.walls.has(cell):continue
			var center=arena.world_pos(cell)
			if p.distance_to(center)>1.35:continue
			knocked[cell]=true;scatter(arena,cell,(center-p).normalized())
	var tween=stage_tween(arena);tween.tween_interval(STEP_OUT)
	tween.tween_method(drive,0.0,1.0,.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(done)

## Bricks hit by the departing HQ: sections vanish into flying debris; the room is over, so only visuals change.
static func scatter(arena,cell:Vector2i,direction:Vector3):
	var wall=arena.walls[cell];var alive=[]
	for i in range(16):
		if wall.sections[i]>0:alive.append(i);wall.section_batch.set_instance_transform(i,WALL.section_transform(i,false))
	if alive.is_empty():return
	preload("res://scripts/brick_debris.gd").shared(arena).burst(arena.world_pos(cell),alive,2.2,direction+Vector3.UP*.3)
	Game.sound("wall_crumble",arena)

## Ring, health bar and labels that belong to the actor but not to its model follow the model's visibility.
static func set_marks(actor,shown:bool):
	for child in actor.get_children():
		if child==actor.model or not child is Node3D:continue
		if child is MeshInstance3D or child is Sprite3D or child is Label3D:
			child.visible=shown
			if shown:pop(child,.18)

## Small appear/disappear helpers so props never just blink in or out.
static func pop(node:Node3D,duration:=.22):
	if not is_instance_valid(node):return
	var target=node.scale;node.scale=target*.4
	node.create_tween().tween_property(node,"scale",target,duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
static func rise(node:Node3D,duration:=.3):
	if not is_instance_valid(node):return
	var target=node.scale;node.scale=Vector3(target.x,.05,target.z)
	node.create_tween().tween_property(node,"scale",target,duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
static func vanish(node:Node3D,duration:=.16,lift:=.35):
	if not is_instance_valid(node):return
	if node.has_meta("vanishing"):return
	node.set_meta("vanishing",true)
	var tween=node.create_tween().set_parallel(true)
	tween.tween_property(node,"scale",Vector3.ONE*.05,duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(node,"position:y",node.position.y+lift,duration)
	tween.chain().tween_callback(node.queue_free)
