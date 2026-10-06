extends RefCounted
## Enemy system. Owns rules; Arena remains the scene coordinator.
var arena

func _init(context):
	arena=context

var base_lanes:Dictionary={}
var base_lanes_revision=-1
func base_weapon_range(actor)->float:
	return EnemyLoadouts.profile(actor.enemy_weapon).range if actor.kind in ["soldier","shield"] else 7.0
func base_lane_user(actor)->bool:
	return not arena.hq_off_field() and actor.kind in ["soldier","shield","buggy","apc","tank"]
func base_firing_cells(actor)->Array:
	if not base_lane_user(actor):return []
	if base_lanes_revision!=arena.navigation.base_revision:
		base_lanes_revision=arena.navigation.base_revision;base_lanes.clear()
	var width=1.0 if UnitKinds.is_vehicle(actor.kind) else .5
	var reach=base_weapon_range(actor);var key=[width,reach,arena.body_size(actor),actor.kind=="soldier"]
	if base_lanes.has(key):return base_lanes[key]
	var cells=[];var center=arena.world_pos(arena.base_cell)
	# Trace each ray once, starting at the base. A wall stops all farther positions.
	for dir in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:
		var previous=center
		for distance in range(1,floori(reach)+1):
			var cell=arena.base_cell+dir*distance
			if not arena.inside(cell):break
			var position=arena.world_pos(cell)
			if not arena.clear_shot(previous,position,width):break
			if arena.navigation.is_open(position,actor):cells.append(cell)
			previous=position
	base_lanes[key]=cells;return cells
func base_aim(actor)->Vector2i:
	if not base_lane_user(actor):return Vector2i.ZERO
	var delta=arena.world_pos(arena.base_cell)-actor.position
	if delta.length()>base_weapon_range(actor):return Vector2i.ZERO
	var direction=Vector2i.ZERO
	if absf(delta.x)<.26:direction=Vector2i(0,signi(roundi(delta.z)))
	elif absf(delta.z)<.26:direction=Vector2i(signi(roundi(delta.x)),0)
	var width=1.0 if UnitKinds.is_vehicle(actor.kind) else .5
	var key=[actor.position,arena.navigation.base_revision,width,base_weapon_range(actor)]
	var cached:Dictionary=actor.get_meta("base_aim_cache",{})
	if not cached.is_empty() and cached.key==key:return cached.direction
	if direction!=Vector2i.ZERO and not arena.clear_shot(actor.position,actor.position+Vector3(direction.x,0,direction.y)*delta.length(),width):direction=Vector2i.ZERO
	actor.set_meta("base_aim_cache",{"key":key,"direction":direction})
	return direction
func attack_waypoint(actor,fallback:Vector2i)->Vector2i:
	var candidates=base_firing_cells(actor)
	var previous:Vector2i=actor.get_meta("base_attack_cell",Vector2i(-1,-1))
	if previous in candidates and arena.can_stand(arena.actor_world_pos(actor,previous),actor):return previous
	var chosen=fallback;var best=INF
	for cell in candidates:
		var cost=absi(cell.x-actor.cell.x)+absi(cell.y-actor.cell.y)
		if cost>=best:continue
		var position=arena.actor_world_pos(actor,cell)
		if not arena.navigation.is_open(position,actor) or not arena.can_stand(position,actor):continue
		chosen=cell;best=cost
	if best<INF:actor.set_meta("base_attack_cell",chosen)
	elif actor.has_meta("base_attack_cell"):actor.remove_meta("base_attack_cell")
	return chosen

func enemy_aim(actor) -> Vector2i:
	var open_shot=base_aim(actor)
	if open_shot!=Vector2i.ZERO:return open_shot
	var seek_open_lane=not base_firing_cells(actor).is_empty()
	var weapon_range=EnemyLoadouts.profile(actor.enemy_weapon).range if actor.kind in ["soldier","shield"] else 7.0
	if actor.assault_time>0 and not arena.hq_off_field():
		# T-169: an assaulting unit still answers a player standing in its line of fire.
		var answer=player_shot(actor,weapon_range) if actor.kind!="grenadier" else Vector2i.ZERO
		if answer!=Vector2i.ZERO:return answer
		if not seek_open_lane and actor.cell.x==arena.base_cell.x and actor.cell.y>=arena.grid_size-4 and not concrete_to_base(actor.cell):return Vector2i.DOWN
		var next=actor.cell+actor.facing
		return actor.facing if not seek_open_lane and needs_breach(actor) and arena.walls.has(next) and arena.walls[next].hp>0 else Vector2i.ZERO
	for wreck in arena.room.wrecks:
		if not is_instance_valid(wreck) or wreck.spent or wreck.unstable or wreck.husk or wreck.delivery_left>0 or arena.flat_distance(actor.position,wreck.position)>minf(5,weapon_range):continue
		var direction=arena.aligned_direction(actor.cell,wreck.cell)
		if direction!=Vector2i.ZERO and arena.clear_line(actor.cell,wreck.cell):return direction
	if actor.kind=="grenadier":return Vector2i.ZERO
	if not seek_open_lane and actor.kind=="buggy" and not arena.hq_off_field() and actor.cell.x==arena.room.base_cell.x and actor.cell.y>=arena.room.grid_size-4 and not concrete_to_base(actor.cell):return Vector2i.DOWN
	for turret in arena.room.actors:
		if not is_instance_valid(turret) or not turret.allied or turret.dead or arena.flat_distance(actor.position,turret.position)>weapon_range:continue
		var aim=arena.aligned_direction(actor.cell,turret.cell)
		if aim!=Vector2i.ZERO and arena.clear_line(actor.cell,turret.cell):return aim
	var at_player=player_shot(actor,weapon_range)
	if at_player!=Vector2i.ZERO:return at_player
	# Shoot toward the base, including through its destructible cover.
	if not seek_open_lane and not arena.hq_off_field() and actor.cell.x == arena.room.base_cell.x and actor.cell.y >= arena.room.grid_size-4:
		return Vector2i.ZERO if concrete_to_base(actor.cell) else Vector2i.DOWN
	var next = actor.cell+actor.facing
	if not seek_open_lane and needs_breach(actor) and arena.room.walls.has(next) and arena.room.walls[next].hp>0:
		if not actor.uses_quarter_steps() or not arena.can_stand(actor.position+Vector3(actor.facing.x,0,actor.facing.y)*.5,actor,true):return actor.facing
	return Vector2i.ZERO

## Direction to shoot the player when they stand in line and in range with a clear shot, else ZERO.
func player_shot(actor,weapon_range:float)->Vector2i:
	if arena.abilities.cloak_time>0 or not is_instance_valid(arena.room.player) or arena.room.player.dead or arena.room.nets.has(arena.grid_pos(arena.room.player.position)):return Vector2i.ZERO
	var target=arena.player.position;var delta=target-actor.position
	var dir=Vector2i.ZERO
	if absf(delta.x)<.26:dir=Vector2i(0,signi(roundi(delta.z)))
	elif absf(delta.z)<.26:dir=Vector2i(signi(roundi(delta.x)),0)
	var width=1.0 if actor.kind in ["buggy","apc","tank","boss"] else .5
	# Water, vegetation, sand and ice never obstruct a shot; only wall geometry does.
	var end=actor.position+Vector3(dir.x,0,dir.y)*delta.length()
	if dir!=Vector2i.ZERO and delta.length()<=CombatMods.engage_range(arena,weapon_range) and arena.clear_shot(actor.position,end,width):return dir
	return Vector2i.ZERO
## T-002: indestructible cover (concrete, its half-blocks and L-corners) between a cell straight above the HQ
## and the HQ: shooting down would only hit the concrete, so the unit moves on and looks for a real lane.
func concrete_to_base(cell:Vector2i)->bool:
	var p=cell+Vector2i.DOWN
	while p.y<arena.room.base_cell.y:
		if arena.room.walls.has(p) and arena.room.walls[p].hp<0:return true
		p+=Vector2i.DOWN
	return false
func needs_breach(actor)->bool:
	var state:Dictionary=actor.get_meta("quarter_search" if actor.uses_quarter_steps() else "cell_search",{})
	return state.get("done",false) and state.get("path",[]).is_empty()

func path_direction(actor) -> Vector2i:
	if actor.uses_quarter_steps():return quarter_path_direction(actor)
	# Vehicles keep a route and share the same bounded search time as infantry.
	while not actor.route_points.is_empty() and actor.cell==actor.route_points[0]:actor.route_points.pop_front()
	var waypoint=attack_waypoint(actor,actor.route_points[0] if actor.assault_time<=0 and not actor.route_points.is_empty() else Vector2i(-1,-1))
	var start:Vector2i=actor.cell
	var key=[waypoint,arena.navigation.revision,arena.walls.size(),arena.player.cell if arena.hq_off_field() and is_instance_valid(arena.player) else arena.base_cell]
	var state:Dictionary=actor.get_meta("cell_search",{})
	var now=Time.get_ticks_msec()
	# Distant wall hits must not restart every unfinished search. Validate the next
	# step live; refresh cached occupancy when geometry changes during a search.
	if not state.is_empty() and state.key!=key and state.key[0]==key[0] and state.key[3]==key[3]:
		state.key=key
		if state.has("free"):state.free.clear()
	if state.is_empty() or state.key!=key or (state.get("done",false) and now-state.created>10000):
		state={"key":key,"start":start,"queue":[[0,start]],"cost":{start:0},"came":{start:start},"path":[],"done":false,"created":now,"retry":0}
		actor.set_meta("cell_search",state)
	while not state.path.is_empty() and state.path[0]==start:state.path.pop_front()
	if not state.path.is_empty():
		var next:Vector2i=state.path[0]
		if (next-start).length_squared()==1 and arena.can_enter(next,actor):state.erase("jam_since");return next-start
		if not state.has("jam_since"):state.jam_since=now
		if now-state.jam_since>=650:actor.remove_meta("cell_search")
		return Vector2i.ZERO
	if state.done:
		if now>=state.retry:actor.remove_meta("cell_search")
		for dir in arena.DIRS:
			var next=start+dir
			if arena.walls.has(next) and arena.walls[next].hp>0:return dir
		return Vector2i.ZERO
	if state.start!=start:actor.remove_meta("cell_search");return Vector2i.ZERO
	var frame=Engine.get_physics_frames()
	if frame!=path_frame:path_frame=frame;path_budget_usec=0
	if path_budget_usec>=2000:return Vector2i.ZERO
	var began=Time.get_ticks_usec();var expanded=0;var goal=start
	while not state.queue.is_empty() and expanded<96:
		if Time.get_ticks_usec()-began+path_budget_usec>=2000 or Time.get_ticks_usec()-began>=450:break
		var p:Vector2i=frontier_pop(state.queue);expanded+=1
		if (waypoint!=Vector2i(-1,-1) and p==waypoint) or (waypoint==Vector2i(-1,-1) and ((not arena.hq_off_field() and p.x==arena.base_cell.x and p.y>=arena.grid_size-4 and p!=arena.base_cell) or (arena.hq_off_field() and is_instance_valid(arena.player) and arena.aligned_direction(p,arena.player.cell)!=Vector2i.ZERO and arena.clear_line(p,arena.player.cell)))):
			goal=p;state.done=true;break
		for dir in arena.DIRS:
			var next:Vector2i=p+dir
			if not arena.inside(next) or (not arena.hq_off_field() and next==arena.base_cell) or arena.walls.has(next) or arena.terrain.movement_blocked_at_cell(next):continue
			if actor.footprint>1:
				var blocked=false
				for occupied in arena.cells_for(actor,next):
					if not arena.inside(occupied) or arena.walls.has(occupied) or arena.trenches.has(occupied) or arena.terrain.movement_blocked_at_cell(occupied) or occupied==arena.base_cell:blocked=true;break
				if blocked:continue
			if p==start and not arena.can_enter(next,actor):continue
			var cost=float(state.cost[p])+arena.terrain.navigation_cost(arena.actor_world_pos(actor,next),actor,dir)
			if state.cost.has(next) and state.cost[next]<=cost:continue
			state.came[next]=p;state.cost[next]=cost
			var estimate=0 if arena.hq_off_field() and waypoint==Vector2i(-1,-1) else (absi(next.x-waypoint.x)+absi(next.y-waypoint.y) if waypoint!=Vector2i(-1,-1) else absi(next.x-arena.base_cell.x)+maxi(0,arena.grid_size-4-next.y))
			frontier_push(state.queue,[cost+estimate,next])
	path_budget_usec+=Time.get_ticks_usec()-began
	if goal!=start:
		while goal!=start:state.path.push_front(goal);goal=state.came[goal]
		var next:Vector2i=state.path[0]
		return next-start if arena.can_enter(next,actor) else Vector2i.ZERO
	if state.queue.is_empty():
		state.done=true;state.retry=now+400
		if waypoint!=Vector2i(-1,-1) and not actor.route_points.is_empty():actor.route_points.pop_front()
	return Vector2i.ZERO

# Plan infantry against the actual remaining wall sections, including off-center gaps.
# Shared per-physics-frame budget prevents simultaneous infantry searches from stalling rendering.
var path_frame=-1
var path_budget_usec=0
func quarter_path_direction(actor)->Vector2i:
	while not actor.route_points.is_empty() and actor.cell==actor.route_points[0]:actor.route_points.pop_front()
	if not actor.route_points.is_empty() and arena.trenches.has(actor.route_points[0]) and not arena.board.trench_available(actor.route_points[0],actor):actor.route_points.pop_front()
	var waypoint=attack_waypoint(actor,actor.route_points[0] if actor.assault_time<=0 and not actor.route_points.is_empty() else Vector2i(-1,-1))
	var start=Vector2i(roundi(actor.position.x*4),roundi(actor.position.z*4))
	var key=[waypoint,arena.navigation.revision,arena.walls.size(),arena.player.cell if arena.hq_off_field() and is_instance_valid(arena.player) else arena.base_cell]
	var state:Dictionary=actor.get_meta("quarter_search",{})
	var now=Time.get_ticks_msec()
	# Distant wall hits must not restart every unfinished search. Validate the next
	# step live; refresh cached occupancy when geometry changes during a search.
	if not state.is_empty() and state.key!=key and state.key[0]==key[0] and state.key[3]==key[3]:
		state.key=key
		if state.has("free"):state.free.clear()
	if state.is_empty() or state.key!=key or (state.get("done",false) and now-state.created>10000):
		state={"key":key,"start":start,"queue":[[0,start]],"cost":{start:0},"came":{start:start},"free":{},"head":0,"path":[],"done":false,"created":now,"retry":0}
		actor.set_meta("quarter_search",state)
	while not state.path.is_empty() and state.path[0]==start:state.path.pop_front()
	if not state.path.is_empty():
		var next:Vector2i=state.path[0]
		var next_pos=Vector3(next.x*.25,actor.position.y,next.y*.25)
		if (next-start).length_squared()==1 and arena.navigation.is_open(next_pos,actor):
			if arena.can_stand(next_pos,actor):state.erase("jam_since");return next-start
			# Preserve the route while another unit clears the doorway.
			if not state.has("jam_since"):state.jam_since=now
			if now-state.jam_since<650:return Vector2i.ZERO
		actor.remove_meta("quarter_search");return Vector2i.ZERO
	if state.done:
		if now>=state.retry:actor.remove_meta("quarter_search")
		for dir in arena.DIRS:
			var next=actor.cell+dir
			if arena.walls.has(next) and arena.walls[next].hp>0:return dir
		return Vector2i.ZERO
	if state.start!=start:actor.remove_meta("quarter_search");return Vector2i.ZERO
	var frame=Engine.get_physics_frames()
	if frame!=path_frame:path_frame=frame;path_budget_usec=0
	if path_budget_usec>=2000:return Vector2i.ZERO
	var began=Time.get_ticks_usec();var expanded=0;var goal=start
	while not state.queue.is_empty() and expanded<96:
		if Time.get_ticks_usec()-began+path_budget_usec>=2000 or Time.get_ticks_usec()-began>=450:break
		var p:Vector2i=frontier_pop(state.queue);expanded+=1
		var pos=Vector3(p.x*.25,actor.position.y,p.y*.25);var cell=arena.grid_pos(pos)
		# A trench or a base firing cell is reached only at its centre (T-336): standing on the boundary between two
		# rows rounds to the right cell but is half a cell off the base line, so the shot never lines up.
		var centred=pos.is_equal_approx(arena.world_pos(cell))
		var at_waypoint=cell==waypoint and (centred or (not arena.trenches.has(cell) and actor.get_meta("base_attack_cell",Vector2i(-1,-1))!=cell))
		if (waypoint!=Vector2i(-1,-1) and at_waypoint) or (waypoint==Vector2i(-1,-1) and ((not arena.hq_off_field() and cell.x==arena.base_cell.x and cell.y>=arena.grid_size-4 and cell!=arena.base_cell) or (arena.hq_off_field() and is_instance_valid(arena.player) and arena.aligned_direction(cell,arena.player.cell)!=Vector2i.ZERO and arena.clear_line(cell,arena.player.cell)))):
			goal=p;state.done=true;break
		for dir in arena.DIRS:
			var next=p+dir
			var next_pos=Vector3(next.x*.25,actor.position.y,next.y*.25)
			var cost=float(state.cost[p])+arena.terrain.navigation_cost(next_pos,actor,dir)
			if state.cost.has(next) and state.cost[next]<=cost:continue
			if not state.free.has(next):state.free[next]=arena.navigation.is_open(next_pos,actor)
			if not state.free[next]:continue
			if p==start and not arena.can_stand(next_pos,actor):continue
			state.came[next]=p;state.cost[next]=cost
			frontier_push(state.queue,[cost+route_estimate(next,waypoint),next])
	path_budget_usec+=Time.get_ticks_usec()-began
	if goal!=start:
		while goal!=start:state.path.push_front(goal);goal=state.came[goal]
		var next:Vector2i=state.path[0]
		return next-start if arena.can_stand(Vector3(next.x*.25,actor.position.y,next.y*.25),actor) else Vector2i.ZERO
	if state.queue.is_empty():
		state.done=true;state.retry=now+400
		# A destroyed/occupied route waypoint must not strand an otherwise mobile unit.
		if waypoint!=Vector2i(-1,-1) and not actor.route_points.is_empty():actor.route_points.pop_front()
	return Vector2i.ZERO

func route_estimate(point:Vector2i,waypoint:Vector2i)->int:
	if waypoint==Vector2i(-1,-1) and arena.hq_off_field():return 0
	var cell=waypoint if waypoint!=Vector2i(-1,-1) else Vector2i(arena.base_cell.x,arena.grid_size-3)
	var target=arena.world_pos(cell)*4
	# Goal is a cell (or lower base firing lane), so subtract the allowed cell extent.
	var dx=maxi(0,absi(point.x-roundi(target.x))-1)
	var dz=maxi(0,absi(point.y-roundi(target.z))-1) if waypoint!=Vector2i(-1,-1) else maxi(0,roundi(target.z)-5-point.y)
	return dx+dz

func frontier_push(heap:Array,item:Array):
	heap.append(item);var i=heap.size()-1
	while i>0:
		var parent=floori(float(i-1)/2)
		if heap[parent][0]<=item[0]:break
		heap[i]=heap[parent];i=parent
	heap[i]=item

func frontier_pop(heap:Array)->Vector2i:
	var point:Vector2i=heap[0][1];var last=heap.pop_back()
	if heap.is_empty():return point
	var i=0
	while i*2+1<heap.size():
		var child=i*2+1
		if child+1<heap.size() and heap[child+1][0]<heap[child][0]:child+=1
		if last[0]<=heap[child][0]:break
		heap[i]=heap[child];i=child
	heap[i]=last
	return point

func drone_step(actor):
	# Kamikaze (T-027): a drone that touches the soldier blows up on him instead of driving past.
	var player=arena.room.player
	if is_instance_valid(player) and not player.dead and arena.flat_distance(actor.position,player.position)<.75:
		actor.dead=true
		if actor.wave_slot>=0 and actor.wave_slot<arena.room.wave_roster.size():arena.room.wave_roster[actor.wave_slot].state="dead"
		arena.room.actors.erase(actor);arena.explosion(actor.position,3.0*(1.55 if actor.rank==3 else 1.3 if actor.rank==2 else 1.0)*actor.strength_scale);actor.queue_free();return
	if actor.moving:return
	var side=actor.flank
	var wall_cell=Vector2i(arena.room.base_cell.x+side,arena.room.grid_size-1)
	var drop_cell=Vector2i(arena.room.base_cell.x+side*(2 if arena.room.walls.has(wall_cell) else 1),arena.room.grid_size-1)
	if actor.cell==drop_cell:
		var bomb=load("res://scenes/bomb.tscn").instantiate();bomb.arena=arena;bomb.damage=3.0*(1.55 if actor.rank==3 else 1.3 if actor.rank==2 else 1.0)*actor.strength_scale;bomb.position=actor.position
		# T-071: the drone itself becomes the bomb — it digs in instead of dropping a separate shell.
		if is_instance_valid(actor.model):bomb.drone_model=actor.model
		arena.add_child(bomb);arena.room.bombs.append(bomb)
		if actor.wave_slot>=0 and actor.wave_slot<arena.room.wave_roster.size():arena.room.wave_roster[actor.wave_slot].state="dead"
		actor.dead=true;arena.room.actors.erase(actor);actor.queue_free()
		arena.toast("Бомба у "+("левой" if side<0 else "правой")+" стены базы!")
		return
	# Follow the camouflaged outside lane, then approach only the matching side of the base.
	var dir=Vector2i.DOWN if actor.cell.y<arena.room.grid_size-1 else Vector2i(-side,0)
	var ahead=actor.cell+dir
	if arena.room.walls.has(ahead) and arena.room.walls[ahead].get("barrier",false):
		actor.dead=true
		if actor.wave_slot>=0:arena.room.wave_roster[actor.wave_slot].state="dead"
		arena.room.actors.erase(actor);arena.explosion(actor.position,3.0*(1.55 if actor.rank==3 else 1.3 if actor.rank==2 else 1.0)*actor.strength_scale);actor.queue_free();return
	actor.set_facing(dir)
	if actor.turn_left==0:actor.try_move(dir)

func mortar_step(actor):
	if actor.fire_cooldown>0:return
	if actor.allied:
		var target=null;var best=12.0
		for enemy in arena.room.actors:
			if not is_instance_valid(enemy) or enemy.dead or enemy.player_owned or enemy.allied:continue
			var distance=arena.flat_distance(actor.position,enemy.position)
			if distance<best:best=distance;target=enemy
		if target==null:return
		arena.throw_grenade(actor,target.position);lob(actor,target.position)
	else:
		if arena.hq_off_field():
			if not is_instance_valid(arena.room.player):return
			arena.throw_grenade(actor,arena.room.player.position);lob(actor,arena.room.player.position)
		else:arena.throw_grenade(actor,arena.world_pos(arena.room.base_cell));lob(actor,arena.world_pos(arena.room.base_cell))
	actor.fire_cooldown=actor.fire_interval

func lob(actor,target:Vector3):
	if is_instance_valid(actor.model) and actor.model.has_method("lob"):actor.model.lob(target)

## Sniper aim (laser shown) and bullet speed. The room commander sniper (mini-boss) aims 35% faster
## and fires a 40% faster round (T-210).
const SNIPER_AIM=1.5
const SNIPER_BULLET_SPEED=15.0
const COMMANDER_SNIPER_AIM=.975
const COMMANDER_SNIPER_BULLET_SPEED=21.0
func sniper_step(actor,delta: float):
	if not is_instance_valid(arena.room.player) or arena.room.player.dead or arena.abilities.cloak_time>0:return
	actor.fire_cooldown-=delta
	if actor.sniper_charge>0:
		actor.sniper_charge-=delta
		actor.sniper_line.visible=true
		if actor.sniper_charge<=0:
			var bullet=load("res://scenes/projectile.tscn").instantiate()
			bullet.arena=arena;bullet.owner_actor=actor;bullet.sniper_round=true;bullet.damage=actor.damage;bullet.speed=COMMANDER_SNIPER_BULLET_SPEED if actor.elite else SNIPER_BULLET_SPEED;bullet.lifetime=3.0
			bullet.travel_direction=(actor.sniper_target-actor.position).normalized()
			bullet.position=actor.position+Vector3.UP*bullet.SNIPER_HEIGHT+bullet.travel_direction*.4
			arena.add_child(bullet);arena.room.projectiles.append(bullet)
			actor.model.kick()
			actor.sniper_line.queue_free();actor.fire_cooldown=actor.fire_interval  # sniper.tres enemy_interval
			Game.weapon_sound(actor)
	elif actor.fire_cooldown<=0:
		actor.sniper_target=arena.room.player.position
		actor.sniper_charge=COMMANDER_SNIPER_AIM if actor.elite else SNIPER_AIM
		actor.model.rotation.y=atan2(-(actor.sniper_target-actor.position).x,-(actor.sniper_target-actor.position).z)
		var diff=actor.sniper_target-actor.position
		actor.sniper_line=Visuals.box(arena,(actor.position+actor.sniper_target)*.5+Vector3.UP*preload("res://scripts/projectile.gd").SNIPER_HEIGHT,Vector3(.035,.035,diff.length()),Color("f24436"))
		actor.sniper_line.material_override=EffectLighting.laser(Color("ff263f"),false)
		actor.sniper_line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var halo=Visuals.box(actor.sniper_line,Vector3.ZERO,Vector3(.095,.095,diff.length()),Color("ff263f"));halo.material_override=EffectLighting.laser(Color("ff263f"),true);halo.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		actor.sniper_line.rotation.y=atan2(diff.x,diff.z)

func flyer_target(actor):
	var best=null;var score=INF
	for target in arena.room.actors:
		if not is_instance_valid(target) or target.dead or not (target.player_owned or target.allied) or (target.player_owned and arena.abilities.cloak_time>0):continue
		var priority=0.0 if target.allied or target.kind!="soldier" else 100.0
		var candidate=priority+arena.flat_distance(actor.position,target.position)
		if candidate<score:score=candidate;best=target
	return best

func flyer_step(actor,delta: float):
	actor.flight_timer-=delta
	actor.health_label.visible=true
	var target=flyer_target(actor)
	if target==null:return
	if actor.flight_state=="choose":
		var current=arena.grid_pos(actor.position);var target_cell=arena.grid_pos(target.position)
		var diff=target_cell-current
		var dir=Vector2i(signi(diff.x),0) if abs(diff.x)>abs(diff.y) else Vector2i(0,signi(diff.y))
		if dir==Vector2i.ZERO or arena.flat_distance(actor.position,target.position)<2:
			dir=arena.DIRS[arena.run.combat_rng.randi_range(0,3)]
		var distance=mini(arena.run.combat_rng.randi_range(3,5),maxi(1,absi(diff.x) if dir.x else absi(diff.y)))
		var destination=current+dir*distance
		destination.x=clampi(destination.x,0,arena.room.grid_size-1);destination.y=clampi(destination.y,0,arena.room.grid_size-1)
		actor.flight_target=arena.world_pos(destination);actor.facing=dir
		actor.flight_state="travel"
	elif actor.flight_state=="travel":
		actor.position=actor.position.move_toward(actor.flight_target,actor.speed*delta)
		actor.cell=arena.grid_pos(actor.position)
		if arena.flat_distance(actor.position,actor.flight_target)<.03:
			actor.flight_state="burst";actor.flight_shots=0;actor.flight_timer=.7
	elif actor.flight_state=="burst" and actor.flight_timer<=0:
		var diff=target.position-actor.position
		var dir=Vector3(signf(diff.x),0,0) if absf(diff.x)>absf(diff.z) else Vector3(0,0,signf(diff.z))
		if dir==Vector3.ZERO:dir=Vector3.FORWARD
		var bullet=load("res://scenes/projectile.tscn").instantiate();bullet.arena=arena;bullet.owner_actor=actor
		bullet.damage=actor.damage;bullet.speed=7.65;bullet.flyer_round=true
		actor.model.aim(atan2(-dir.x,-dir.z),-.12);actor.model.kick()
		bullet.travel_direction=dir;bullet.position=actor.position+Vector3.UP*.9+dir*.3
		arena.add_child(bullet);arena.room.projectiles.append(bullet)
		Game.weapon_sound(actor)
		actor.flight_shots=1;actor.flight_state="rest";actor.flight_timer=.7
	elif actor.flight_state=="rest" and actor.flight_timer<=0:actor.flight_state="choose"
	actor.model.rotation.y=atan2(-float(actor.facing.x),-float(actor.facing.y))
	actor.model.position.y=1.25+sin(arena.run.elapsed*5)*.06


func rpg_step(actor,delta:float)->bool:
	if actor.rocket_charge>0:
		actor.rocket_charge=maxf(0,actor.rocket_charge-delta)
		if is_instance_valid(actor.sniper_line):actor.sniper_line.visible=fmod(actor.rocket_charge,.24)<.15
		if actor.rocket_charge==0:
			if is_instance_valid(actor.sniper_line):actor.sniper_line.queue_free()
			if arena.abilities.cloak_time<=0:
				var direction=(actor.rocket_target-actor.position).normalized()
				var bullet=arena.spawn_free_bullet(actor,direction,actor.damage,4.5,false)
				bullet.rocket_radius=.8;bullet.lifetime=7.0/4.5;bullet.scale=Vector3.ONE*1.5
				actor.model.kick()
			actor.fire_cooldown=4.8
		return true
	if actor.fire_cooldown>0 or actor.moving or arena.abilities.cloak_time>0 or not is_instance_valid(arena.player):return false
	if arena.flat_distance(actor.position,arena.player.position)>7 or not arena.clear_line(actor.cell,arena.player.cell):return false
	actor.rocket_target=arena.player.position;actor.rocket_target.y=actor.position.y;actor.rocket_charge=.85
	var diff=actor.rocket_target-actor.position
	actor.model.rotation.y=atan2(-diff.x,-diff.z)
	actor.sniper_line=Visuals.box(arena,(actor.position+actor.rocket_target)*.5+Vector3.UP*.05,Vector3(.055,.025,diff.length()),Color("e7a143"))
	actor.sniper_line.rotation.y=atan2(diff.x,diff.z)
	return true

func attention_tick(actor,delta:float):
	if actor.kind not in ["soldier","shield","grenadier","buggy","apc","tank"] or actor.elite or arena.hq_off_field():return
	actor.assault_time=maxf(0,actor.assault_time-delta);actor.trench_return_delay=maxf(0,actor.trench_return_delay-delta)
	actor.attention_timer-=delta
	if actor.cell.y>actor.deepest_row:actor.deepest_row=actor.cell.y;actor.idle_progress_time=0
	# T-169: no "stall" time during an assault — it used to reach 6 s by the end and start the next assault at
	# once, so a stuck unit stayed in assault (and silent) forever.
	elif actor.assault_time<=0:actor.idle_progress_time+=delta
	if actor.assault_time>0:actor.movement_pause=0;return
	var stalled=actor.idle_progress_time>=6 and actor.cell.y<arena.grid_size-4
	if not stalled and actor.attention_timer>0:return
	actor.attention_timer=arena.combat_rng.randf_range(10,16)
	if not stalled and arena.combat_rng.randf()>Professionalism.of(arena,"assault_chance"):return
	actor.assault_time=arena.combat_rng.randf_range(8,11);actor.trench_return_delay=actor.assault_time+6
	actor.idle_progress_time=0;actor.route_points.clear();actor.occupying_trench=false;actor.hidden_in_trench=false;actor.model.position.y=0
	actor.movement_pause=0;actor.brain_cooldown=0;actor.trench_time=0
