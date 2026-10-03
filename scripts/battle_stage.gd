extends RefCounted
## Micro-staging of a battle room: the HQ drives in on an arc, the soldier steps out to his post and the
## brick defence snaps together course by course; at the end the soldier boards and the HQ drives off,
## scattering the bricks still standing in its way. Visual only: cells, walls and HP are in place from
## the first frame, only models, section transforms and labels move. Own RNG, no combat randomness.
const WALL=preload("res://scripts/section_wall.gd")
const ARRIVE=.85
## Up the field approach (0.8): a longer drive along the track and the ramp.
const ARRIVE_RAMP=2.1
## Down the approach and away along the other track (0.8).
const LEAVE_RAMP=1.8
## Pause between the arrival beats: HQ stops, soldier hops out, wall rises.
const BEAT=.25
const STEP_OUT=.3
const BRICKS_AT=.5
## Defence wall assembly pace: 1.2 = 20% slower than before.
const BRICK_PACE=1.2

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
	# A cut-short intro must not leave the soldier hidden.
	var actor=arena.get("player")
	if is_instance_valid(actor) and actor.has_meta("stage_hidden"):actor.remove_meta("stage_hidden")

## Side the HQ arrives from. It follows the final yaw chosen when the room was built (MobileHQ.orientation), so
## the vehicle drives in already heading the way it will stand: facing +X it comes from -X and vice versa.
static func side(arena)->float:
	if is_instance_valid(arena.base_model) and absf(sin(arena.base_model.rotation.y))>.5:return -signf(sin(arena.base_model.rotation.y))
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
	var approach=arena.find_child("FieldApproach",true,false)
	if approach and approach.has_meta("track_right"):
		ramp_arrival(arena,hq,approach,rest,yaw)
		# One-two-three (author, 0.8): the HQ stops — a beat — the soldier hops out — a beat — the wall rises.
		step_out(arena,rest,ARRIVE_RAMP+BEAT)
		build_bricks(arena,ARRIVE_RAMP+BEAT+STEP_OUT*1.5+.2+BEAT-BRICKS_AT)
		return
	# The curve ends level with the rest point, so its last tangent is the final heading: no turn on the spot.
	var start=rest+Vector3(s*5.5,0,3.2);var bend=rest+Vector3(s*4.2,0,0)
	for node in [arena.base_label,arena.base_bar]:
		if is_instance_valid(node):node.visible=false
	hq.position=start
	var drive=func(t:float):
		if not is_instance_valid(hq):return
		var p=bezier(start,bend,rest,t);var ahead=bezier(start,bend,rest,minf(1.0,t+.02))-p
		hq.position=p
		var heading=atan2(ahead.x,ahead.z) if ahead.length()>.001 else yaw
		hq.rotation.y=lerp_angle(heading,yaw,smoothstep(.9,1.0,t))
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

## 0.8: the HQ comes along the dirt track, up the trapezoid apron and over the rim to its post. Height and
## pitch follow the surface (FieldApproach.path_height); it jolts a little at the ramp foot and on the rim lip.
static func ramp_arrival(arena,hq:Node3D,approach,rest:Vector3,yaw:float):
	var curve=approach_curve(approach,side(arena),rest,Vector3(sin(yaw),0,cos(yaw)),true)
	var length=curve.get_baked_length()
	for node in [arena.base_label,arena.base_bar]:
		if is_instance_valid(node):node.visible=false
	var bumps=[approach.front,approach.front+approach.LENGTH]
	var drive=func(t:float):
		if not is_instance_valid(hq):return
		var d=t*length;var p=curve.sample_baked(d,true);var ahead=curve.sample_baked(minf(length,d+.9),true)
		var h=approach.path_height(p) if p.z>rest.z+.01 else rest.y
		var h_ahead=approach.path_height(ahead) if ahead.z>rest.z+.01 else rest.y
		var jolt=0.0
		for z in bumps:jolt+=exp(-pow((p.z-z)/.18,2.0))
		hq.position=Vector3(p.x,h+jolt*.05*absf(sin(t*90.0)),p.z) if t<1.0 else rest
		var flat=Vector2(ahead.x-p.x,ahead.z-p.z)
		var heading=atan2(flat.x,flat.y) if flat.length()>.001 else yaw
		# Steering: the nose looks ~a wheelbase ahead along the path and turns toward it gradually, like a car.
		var target=lerp_angle(heading,yaw,smoothstep(.97,1.0,t))
		hq.rotation.y=target if t<.01 or t>=1.0 else lerp_angle(hq.rotation.y,target,.3)
		hq.rotation.x=0.0 if t>=1.0 else -atan2(h_ahead-h,maxf(.05,flat.length()))+jolt*.05*sin(t*120.0)
	var tween=stage_tween(arena)
	tween.tween_method(drive,0.0,1.0,ARRIVE_RAMP).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		if not is_instance_valid(hq):return
		hq.position=rest;hq.rotation=Vector3(0,yaw,0)
		arena.burst(rest,Color("d8cfb4"),.5)
		for node in [arena.base_label,arena.base_bar]:
			if is_instance_valid(node):node.visible=true;pop(node))
## Path between the HQ post and the field approach on one side: off-screen along that side's track, up its
## lane over the rim, then a quarter turn into the post along the final heading (arriving) — or the same
## way back out (leaving). Flat curve; heights come from FieldApproach.path_height.
static func approach_curve(approach,s:float,rest:Vector3,forward:Vector3,arriving:bool)->Curve3D:
	var track:Array=approach.get_meta("track_left" if s<0 else "track_right")
	var points:Array=[]
	for i in range(track.size()-1,0,-4):points.append(Vector3(track[i].x,0,track[i].z))
	var lane=approach.lane(s)
	points.append(Vector3(lane,0,approach.front+approach.LENGTH));points.append(Vector3(lane,0,approach.front+.1))
	points.append(Vector3(rest.x,0,rest.z))
	if not arriving:points.reverse()
	var curve=Curve3D.new()
	for p in points:curve.add_point(p)
	for i in range(1,curve.point_count-1):
		var tangent=(curve.get_point_position(i+1)-curve.get_point_position(i-1))*.25
		curve.set_point_in(i,-tangent);curve.set_point_out(i,tangent)
	# Over the rim straight up/down the board; at the post the path runs along the HQ heading.
	var top=curve.point_count-2 if arriving else 1
	var up=Vector3(0,0,-1.4) if arriving else Vector3(0,0,1.4)
	curve.set_point_in(top,-up*.7);curve.set_point_out(top,up)
	if arriving:curve.set_point_in(curve.point_count-1,-forward*1.4)
	else:curve.set_point_out(0,forward*1.4)
	return curve
## The soldier (or his vehicle) leaves the HQ and takes the start cell.
static func step_out(arena,from:Vector3,arrive:=ARRIVE):
	var actor=arena.player
	if not is_instance_valid(actor) or not is_instance_valid(actor.model):return
	var model:Node3D=actor.model;var home=model.position
	model.visible=false;set_marks(actor,false);actor.set_meta("stage_hidden",true)
	var tween=stage_tween(arena,actor);tween.tween_interval(arrive-.08)
	tween.tween_callback(func():
		if not is_instance_valid(model):return
		if is_instance_valid(actor):actor.remove_meta("stage_hidden")
		model.visible=true;model.position=home+(from-actor.position);model.scale=Vector3.ONE*.7
		set_marks(actor,true))
	# 0.8: a clear hop out of the HQ — up in an arc, a squash on landing.
	var start=home+(from-actor.position)
	var hop=func(t:float):
		if is_instance_valid(model):model.position=start.lerp(home,t)+Vector3.UP*sin(t*PI)*.75
	tween.tween_method(hop,0.0,1.0,STEP_OUT*1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(model,"scale",Vector3.ONE,STEP_OUT*.9)
	tween.tween_property(model,"scale",Vector3(1.15,.82,1.15),.06)
	tween.tween_property(model,"scale",Vector3.ONE,.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():if is_instance_valid(actor) and actor.arena:actor.arena.burst(actor.position,Color("d8cfb4"),.25))

## Staircase build: nearest cell first, inside a cell the sections rise diagonally; each drops in
## from a little above with a short overshoot. A damaged section is never redrawn.
static func build_bricks(arena,later:=0.0):
	var cells=fort_walls(arena)
	for k in range(cells.size()):
		var wall=arena.walls[cells[k]];var batch:MultiMesh=wall.section_batch
		for i in range(16):
			if wall.sections[i]<=0:continue
			batch.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
			var delay=later+BRICKS_AT+(k*.045+((i%4)+int(i/4))*.018)*BRICK_PACE
			var grow=func(p:float):
				if not is_instance_valid(arena) or not arena.walls.has(cells[k]) or arena.walls[cells[k]]!=wall or wall.sections[i]<=0:return
				var t=WALL.section_transform(i,true)
				t.basis=t.basis.scaled(Vector3(1,maxf(.05,p),1));t.origin.y+=(1.0-minf(p,1.0))*.45
				batch.set_instance_transform(i,t)
			var tween=stage_tween(arena);tween.tween_interval(delay)
			tween.tween_method(grow,0.0,1.0,.16*BRICK_PACE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Departure: the soldier walks into the HQ, the HQ drives off on an arc and knocks down the defence
## bricks it passes. `done` runs when it has left the field.
static func outro(arena,done:Callable):
	stop(arena)
	var hq:Node3D=arena.base_model
	if not is_instance_valid(hq):done.call();return
	var rest=hq.position;var s=side(arena)
	var actor=arena.player
	if is_instance_valid(actor) and is_instance_valid(actor.model):
		var model:Node3D=actor.model;set_marks(actor,false);actor.set_meta("stage_hidden",true)
		var board=stage_tween(arena,actor)
		board.tween_property(model,"position",model.position+(rest-actor.position),STEP_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		board.parallel().tween_property(model,"scale",Vector3.ONE*.6,STEP_OUT)
		board.tween_callback(func():if is_instance_valid(model):model.visible=false)
	for node in [arena.base_label,arena.base_bar]:
		if is_instance_valid(node):node.visible=false
	if is_instance_valid(arena.presentation):arena.presentation.swoop_out(s,hq)
	var approach=arena.find_child("FieldApproach",true,false)
	if approach and approach.has_meta("track_right"):
		ramp_departure(arena,hq,approach,rest,hq.rotation.y,s,done)
		return
	# Pull out straight ahead (the HQ faces -s), then curve away toward the camera side.
	var finish=rest+Vector3(-s*6.0,0,3.6);var bend=rest+Vector3(-s*3.0,0,0)
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

## 0.8: the HQ pulls out ahead, turns down the lane on its side of the approach and leaves along that track
## in a wide arc, knocking over defence bricks in its way; surface heights and jolts as on arrival.
static func ramp_departure(arena,hq:Node3D,approach,rest:Vector3,yaw:float,s:float,done:Callable):
	var forward=Vector3(sin(yaw),0,cos(yaw))
	var curve=approach_curve(approach,signf(forward.x) if absf(forward.x)>.1 else -s,rest,forward,false)
	var length=curve.get_baked_length();var bumps=[approach.front,approach.front+approach.LENGTH]
	var fort=fort_walls(arena);var knocked={}
	var drive=func(t:float):
		if not is_instance_valid(hq):return
		var d=t*length;var p=curve.sample_baked(d,true);var ahead=curve.sample_baked(minf(length,d+.9),true)
		var h=approach.path_height(p) if p.z>rest.z+.01 else rest.y
		var h_ahead=approach.path_height(ahead) if ahead.z>rest.z+.01 else rest.y
		var jolt=0.0
		for z in bumps:jolt+=exp(-pow((p.z-z)/.18,2.0))
		hq.position=Vector3(p.x,h+jolt*.05*absf(sin(t*90.0)),p.z)
		var flat=Vector2(ahead.x-p.x,ahead.z-p.z)
		if flat.length()>.001:hq.rotation.y=lerp_angle(hq.rotation.y,atan2(flat.x,flat.y),.3)
		hq.rotation.x=-atan2(h_ahead-h,maxf(.05,flat.length()))+jolt*.05*sin(t*120.0)
		for cell in fort:
			if knocked.has(cell) or not arena.walls.has(cell):continue
			var center=arena.world_pos(cell)
			if Vector3(p.x,center.y,p.z).distance_to(center)>1.35:continue
			knocked[cell]=true;scatter(arena,cell,(center-Vector3(p.x,center.y,p.z)).normalized())
	var tween=stage_tween(arena);tween.tween_interval(STEP_OUT)
	tween.tween_method(drive,0.0,1.0,LEAVE_RAMP).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
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
