class_name ChallengeRooms
extends RefCounted
## Special route rooms that reuse the battlefield (HQ is always present).
## cache — a chest in the centre; leaving is allowed at once, opening it calls a veteran ambush,
## surviving it drops a reward chest whose value follows the room difficulty.
## hold — stand in the zone while enemies keep coming; progress grows only while no enemy is inside.
## survive — the field is under artillery fire; dodge the markers until the timer ends (shooting and abilities
## work, T-118).
## maze — a dark concrete maze: only the soldier's surroundings are lit; reach the green flag before the timer.
## When time runs out the lights come on and the exit opens without a reward.
const TITLES={"cache":"Тайник","hold":"Удержание","survive":"Выживание","maze":"Тёмный лабиринт"}
const MAZE_SECONDS=[45,40,35]
const MAZE_REACH=.9
## Maze zombies: slow, unarmed soldiers shambling towards the soldier through the corridors; a bite deals 1.
const ZOMBIES=[2,2,3]
const ZOMBIE_SPEED=.9
const ZOMBIE_BITE=1.0
const ZOMBIE_BITE_PAUSE=1.3
var zombies:Array=[]
const AMBUSH_SIZE=[4,6,8]
const HOLD_SECONDS=[30,40,50]
const HOLD_RADIUS=1.6
const SURVIVE_SECONDS=[25,35,45]
const SHELL_INTERVAL=[1.1,.8,.6]
const SHELL_RADIUS=[1.2,1.4,1.6]
const SHELL_FUSE=1.5
var progress=0.0
var goal=0.0
## Hold: an enemy stands in the zone and the countdown is paused.
var contested_now=false
var zone:Node3D
var shell_timer=0.0
var shells:Array=[]
var wave_cycle=0
var arena
var opened=false
var rewarded=false
var chest:Dictionary={}
var goal_flag:Node3D
var darkness:CanvasLayer
var timed_out=false
func _init(context):
	arena=context
func active()->bool:return arena.room.mode!="battle"
## Rooms that finish by their own rule, not by an empty wave queue.
func blocks_waves()->bool:return arena.room.mode in ["hold","survive","maze"] and not rewarded and not timed_out
func weapons_locked()->bool:return false
## Room change: forget props of the previous challenge (their nodes are freed with the room).
func reset():
	opened=false;rewarded=false;chest={};zone=null;shells.clear();timed_out=false;goal_flag=null
	if is_instance_valid(darkness):darkness.queue_free()
	darkness=null
func start():
	opened=false;rewarded=false;chest={}
	arena.room.spawn_queue.clear();arena.room.wave_roster.clear();arena.room.wave_spawned=0;arena.room.upgrade_offers.clear()
	progress=0.0;goal=0.0;shell_timer=1.5;wave_cycle=0
	for shell in shells:
		if is_instance_valid(shell.node):shell.node.queue_free()
	shells.clear();zone=null
	match arena.room.mode:
		"cache":start_cache()
		"hold":start_hold()
		"survive":start_survive()
		"maze":start_maze()
func start_cache():
	# The exit is open from the start: taking the risk is optional.
	arena.room.room_cleared=true;arena.room.reward_claimed=true;arena.room.next_is_room=true
	arena.flow.place_flag("Выход")
	arena.room.flag_armed=false # the soldier starts on the exit; it arms once he steps away
	var cell=Vector2i(int(arena.room.grid_size/2),int(arena.room.grid_size/2)-1)
	cell=arena.find_free_near(cell)
	var node=Node3D.new();arena.add_child(node);node.position=arena.world_pos(cell)
	var visual=Node3D.new();node.add_child(visual)
	Visuals.box(visual,Vector3(0,.3,0),Vector3(1,.6,.65),Color("5d5a4a"))
	Visuals.box(visual,Vector3(0,.64,0),Vector3(1.05,.14,.7),Color("7b7660"))
	for x in [-.33,.33]:Visuals.box(visual,Vector3(x,.35,-.34),Vector3(.1,.56,.03),Color("d4bd73"))
	Visuals.ring(node,Color("cf613f"),.65)
	Visuals.label3d(node,"Тайник · E",Vector3(0,1.5,0),Color("ffd9b0"),40)
	preload("res://scripts/interaction_prompt.gd").attach(node,arena,"Тайник",Vector3.ZERO,1.65)
	chest={"kind":"cache","node":node,"visual":visual}
	arena.room.pickups.append(chest)
	arena.toast("Тайник. Откроешь — будет засада. Можно уйти через выход")
func nearest_cache()->Dictionary:
	if arena.room.mode!="cache" or chest.is_empty() or opened or not is_instance_valid(chest.get("node")) or not is_instance_valid(arena.room.player):return {}
	return chest if arena.flat_distance(arena.room.player.position,chest.node.position)<1.6 else {}
## Veterans come from both sides; the room stays open to leave.
func open_cache():
	if opened or chest.is_empty():return
	opened=true;Game.sound("chest_open",arena)
	arena.room.pickups.erase(chest);chest.node.queue_free()
	var entries=WaveDirector.build(arena.run.run_seed,arena.room.room_index,2,arena.room.difficulty,arena.room.route_node_id)
	entries=entries.filter(func(e):return e.kind not in ["drone","flyer"]).slice(0,AMBUSH_SIZE[clampi(arena.room.difficulty,0,2)])
	arena.room.wave=2;arena.room.wave_roster.clear();arena.room.wave_spawned=0
	for entry in entries:arena.room.wave_roster.append({"kind":entry.kind,"rank":maxi(2,int(entry.rank)),"weapon":entry.get("weapon",EnemyLoadouts.default_for(entry.kind)),"state":"queued"})
	arena.room.spawn_queue=entries.map(func(e):return e.kind)
	arena.room.spawn_timer=.3
	if is_instance_valid(arena.presentation):arena.presentation.announce("Засада!","Продержись",.8)
func tick(delta:float=0.0):
	match arena.room.mode:
		"cache":
			if opened and not rewarded and arena.room.spawn_queue.is_empty() and arena.enemy_count()==0:
				rewarded=true;record_success();drop_reward()
		"hold":tick_hold(delta)
		"survive":tick_survive(delta)
		"maze":tick_maze(delta)
## Countdown for timed rooms (hold, survive): title, seconds left and done share; empty for other rooms.
func timer()->Dictionary:
	if not active() or arena.room.mode not in ["hold","survive","maze"] or goal<=0 or rewarded or timed_out:return {}
	return {"title":TITLES[arena.room.mode],"left":maxf(0.0,goal-progress),"ratio":clampf(progress/goal,0.0,1.0),"paused":arena.room.mode=="hold" and contested_now}
func status()->String:
	match arena.room.mode:
		"cache":return TITLES.cache+(" · засада" if opened and not rewarded else "")
		"hold","survive":return TITLES[arena.room.mode]+(" · %d / %d с" % [floori(progress),roundi(goal)] if not rewarded else " · готово")
		"maze":return TITLES.maze+(" · готово" if rewarded else " · свет включён" if timed_out else " · %d с" % ceili(goal-progress))
	return ""

func start_hold():
	goal=HOLD_SECONDS[clampi(arena.room.difficulty,0,2)]
	var cell=Vector2i(int(arena.room.grid_size/2),int(arena.room.grid_size/3))
	cell=arena.find_free_near(cell)
	zone=Node3D.new();zone.name="HoldZone";arena.add_child(zone);zone.position=arena.world_pos(cell)
	Visuals.ring(zone,Color("e5b34f"),HOLD_RADIUS)
	Visuals.box(zone,Vector3(0,1,0),Vector3(.08,2,.08),Color("eee9d8"))
	Visuals.box(zone,Vector3(.35,1.7,0),Vector3(.7,.45,.07),Color("e5b34f"))
	Visuals.label3d(zone,"Держи точку",Vector3(0,2.5,0),Color("fff0ce"),32)
	refill_enemies()
	if is_instance_valid(arena.presentation):arena.presentation.announce("Удержание","Стой в зоне, пока враги наступают",.8)
## Enemies keep coming in batches until the zone is held.
func refill_enemies():
	var entries=WaveDirector.build(arena.run.run_seed+wave_cycle*131,arena.room.room_index,wave_cycle%3,arena.room.difficulty,arena.room.route_node_id)
	entries=entries.filter(func(e):return e.kind not in ["drone","flyer"])
	wave_cycle+=1
	arena.room.wave=mini(2,wave_cycle-1);arena.room.wave_roster.clear();arena.room.wave_spawned=0
	for entry in entries:arena.room.wave_roster.append({"kind":entry.kind,"rank":int(entry.rank),"weapon":entry.get("weapon",EnemyLoadouts.default_for(entry.kind)),"state":"queued"})
	arena.room.spawn_queue=entries.map(func(e):return e.kind);arena.room.spawn_timer=.4
func in_zone(pos:Vector3)->bool:return is_instance_valid(zone) and arena.flat_distance(pos,zone.position)<HOLD_RADIUS
func tick_hold(delta:float):
	if rewarded:return
	if arena.room.spawn_queue.is_empty() and arena.enemy_count()<=1:refill_enemies()
	var player=arena.room.player
	var contested=arena.room.actors.any(func(a):return is_instance_valid(a) and not a.dead and not a.player_owned and not a.allied and in_zone(a.position))
	contested_now=contested or not (is_instance_valid(player) and in_zone(player.position))
	if is_instance_valid(player) and in_zone(player.position) and not contested:progress=minf(goal,progress+delta)
	elif not is_instance_valid(player) or not in_zone(player.position):progress=maxf(0,progress-delta*.25)
	if progress>=goal:complete(zone.position)

func start_maze():
	# Time grows with the field: the table is for a 15-cell field.
	goal=roundf(MAZE_SECONDS[clampi(arena.room.difficulty,0,2)]*maxf(1.0,arena.room.grid_size/15.0));timed_out=false
	var cell=ChallengeLayouts.maze_goal(arena.room.grid_size,arena.run_seed+arena.room.room_index*977,arena.room.difficulty)
	goal_flag=Node3D.new();goal_flag.name="MazeGoal";arena.add_child(goal_flag);goal_flag.position=arena.world_pos(cell)
	Visuals.ring(goal_flag,Color("5fc46a"),.7)
	Visuals.box(goal_flag,Vector3(0,1.1,0),Vector3(.08,2.2,.08),Color("eee9d8"))
	Visuals.box(goal_flag,Vector3(.36,1.85,0),Vector3(.7,.45,.06),Color("4fb85c"))
	var glow=OmniLight3D.new();goal_flag.add_child(glow);glow.position=Vector3(0,1.6,0);glow.light_color=Color("7dffa0");glow.light_energy=1.2;glow.omni_range=2.6
	var stash=ChallengeLayouts.maze_chest(arena.room.grid_size,arena.run_seed+arena.room.room_index*977,arena.room.difficulty)
	if stash.x>=0:arena.reward.drop_recipe(stash,{"elite":false})
	spawn_zombies()
	darkness=preload("res://scripts/ui/maze_darkness.gd").new();darkness.arena=arena;arena.add_child(darkness)
	if is_instance_valid(arena.presentation):arena.presentation.announce("Тёмный лабиринт","Найди зелёный флаг до конца отсчёта",.8)
	arena.toast("Темно. Видно только вокруг бойца — ищи зелёный флаг")
## Zombies stand in far corridors (not on the path's first cells, not at the flag or the chest).
func spawn_zombies():
	zombies.clear()
	var plan=ChallengeLayouts.maze_plan(arena.room.grid_size,arena.run_seed+arena.room.room_index*977,arena.room.difficulty)
	var start=arena.grid_pos(arena.room.player.position) if is_instance_valid(arena.room.player) else plan.entry
	var dist=maze_distances(start)
	var spots=dist.keys().filter(func(c):return dist[c]>=7 and c!=plan.goal and c!=plan.chest and plan.open.has(c))
	var rng=arena.run.combat_rng
	for i in range(ZOMBIES[clampi(arena.room.difficulty,0,2)]):
		if spots.is_empty():break
		var cell:Vector2i=spots.pop_at(rng.randi_range(0,spots.size()-1))
		var z=arena.spawn_actor("soldier",cell,false)
		z.set_physics_process(false);z.set_meta("zombie",true);z.max_hp=2.0;z.hp=2.0;z.refresh_health()
		z.set_meta("bite_pause",0.0);z.set_meta("phase",rng.randf()*TAU)
		if is_instance_valid(z.model):
			Visuals.tint_model(z.model,Color("7f9a6a"))
			for gun in z.model.find_children("Weapon*","Node3D",true,false):gun.visible=false
		zombies.append(z)
func maze_distances(from:Vector2i)->Dictionary:
	var dist={from:0};var queue=[from]
	while not queue.is_empty():
		var at:Vector2i=queue.pop_front()
		for d in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			var to=at+d
			if dist.has(to) or not arena.inside(to) or arena.walls.has(to):continue
			dist[to]=dist[at]+1;queue.append(to)
	return dist
## Each zombie steps down the distance field towards the soldier, wobbling; adjacent ones bite now and then.
func tick_zombies(delta:float):
	var player=arena.room.player
	if not is_instance_valid(player) or player.dead:return
	zombies=zombies.filter(func(z):return is_instance_valid(z) and not z.dead)
	if zombies.is_empty():return
	var field=maze_distances(arena.grid_pos(player.position))
	for z in zombies:
		var pause=maxf(0.0,float(z.get_meta("bite_pause"))-delta);z.set_meta("bite_pause",pause)
		if arena.flat_distance(z.position,player.position)<.7:
			z.moving=false
			if pause<=0:player.take_damage(ZOMBIE_BITE,player.position-z.position+Vector3(.01,0,.01),"","melee");z.set_meta("bite_pause",ZOMBIE_BITE_PAUSE);Game.sound("hit_body",z)
			continue
		var here=arena.grid_pos(z.position);var best=here
		for d in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			if field.has(here+d) and int(field[here+d])<int(field.get(best,999)):best=here+d
		var target=arena.world_pos(best) if best!=here else player.position
		var step=(target-z.position);step.y=0
		if step.length()>.02:
			z.position+=step.normalized()*minf(step.length(),ZOMBIE_SPEED*delta);z.cell=arena.grid_pos(z.position);z.moving=true
			z.rotation.y=atan2(-step.x,-step.z)
		var t=arena.run.elapsed*3.2+float(z.get_meta("phase"))
		if is_instance_valid(z.model):z.model.rotation.z=sin(t)*.14;z.model.rotation.x=.12
func tick_maze(delta:float):
	tick_zombies(delta)
	if rewarded or timed_out:return
	progress=minf(goal,progress+delta)
	var player=arena.room.player
	if is_instance_valid(player) and is_instance_valid(goal_flag) and arena.flat_distance(player.position,goal_flag.position)<MAZE_REACH:
		if is_instance_valid(darkness):darkness.lift()
		var at=goal_flag.position;goal_flag.queue_free()
		complete(at)
		# The exit stands right at the flag: no walk back through the maze.
		if is_instance_valid(arena.room.flag):arena.room.flag.position=at;arena.room.flag_armed=false
		return
	if progress>=goal:
		timed_out=true
		if is_instance_valid(darkness):darkness.lift()
		arena.room.room_cleared=true;arena.room.reward_claimed=true;arena.room.next_is_room=true
		arena.flow.place_flag("Выход")
		if is_instance_valid(player):arena.room.flag.position=arena.world_pos(arena.grid_pos(player.position));arena.room.flag_armed=false
		if is_instance_valid(arena.presentation):arena.presentation.announce("Свет включили","Время вышло · награды нет",.8)
func start_survive():
	goal=SURVIVE_SECONDS[clampi(arena.room.difficulty,0,2)]
	if is_instance_valid(arena.presentation):arena.presentation.announce("Вы попали под обстрел!","Продержись %d с · уходи из красных меток" % int(goal),1.6)
	arena.toast("Стрелять и применять способности можно — главное, не стой в красных метках")
func tick_survive(delta:float):
	if rewarded:return
	progress=minf(goal,progress+delta)
	shell_timer-=delta
	if shell_timer<=0:
		shell_timer=SHELL_INTERVAL[clampi(arena.room.difficulty,0,2)];mark_shell()
	for shell in shells.duplicate():
		shell.time-=delta
		if is_instance_valid(shell.node):shell.paint.albedo_color.a=lerpf(.5,.18,clampf(shell.time/SHELL_FUSE,0,1))
		if shell.time<=0:explode_shell(shell)
	if progress>=goal:
		for shell in shells:
			if is_instance_valid(shell.node):shell.node.queue_free()
		shells.clear();complete(arena.world_pos(Vector2i(int(arena.room.grid_size/2),int(arena.room.grid_size/2)-1)))
## Half of the shells aim near the player, the rest anywhere on the field; the HQ surroundings are never targeted.
func mark_shell():
	var rng=arena.run.combat_rng;var g=arena.room.grid_size;var cell=Vector2i.ZERO
	for attempt in range(8):
		if is_instance_valid(arena.room.player) and rng.randf()<.5:
			var center=arena.grid_pos(arena.room.player.position)
			cell=center+Vector2i(rng.randi_range(-2,2),rng.randi_range(-2,2))
		else:cell=Vector2i(rng.randi_range(1,g-2),rng.randi_range(1,g-3))
		if arena.inside(cell) and absi(cell.x-arena.room.base_cell.x)+absi(cell.y-arena.room.base_cell.y)>2:break
	var radius=SHELL_RADIUS[clampi(arena.room.difficulty,0,2)]
	var node=Node3D.new();arena.add_child(node);node.position=arena.world_pos(cell)
	Visuals.ring(node,Color("d8453a"),radius)
	# Filled danger disc; it grows more opaque as the fuse runs out.
	var disc=MeshInstance3D.new();var shape=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=.02;disc.mesh=shape;disc.position.y=.04
	var paint=StandardMaterial3D.new();paint.albedo_color=Color(.85,.27,.23,.18);paint.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;paint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override=paint;node.add_child(disc)
	shells.append({"node":node,"time":SHELL_FUSE,"radius":radius,"paint":paint})
func explode_shell(shell:Dictionary):
	shells.erase(shell)
	if not is_instance_valid(shell.node):return
	var pos=shell.node.position;shell.node.queue_free()
	arena.burst(pos+Vector3.UP*.3,Color("e78331"),shell.radius);Game.sound("explosion_heavy",arena)
	var player=arena.room.player
	if is_instance_valid(player) and not player.dead and arena.flat_distance(pos,player.position)<shell.radius:player.take_damage(1,player.position-pos+Vector3(.01,0,.01),"","blast")
	for cell in arena.room.walls.keys():
		if arena.flat_distance(pos,arena.world_pos(cell))<shell.radius:arena.damage_wall(cell,2)

func complete(pos:Vector3):
	if rewarded:return
	rewarded=true;record_success()
	arena.room.spawn_queue.clear()
	for actor in arena.room.actors.duplicate():
		if is_instance_valid(actor) and not actor.dead and not actor.player_owned and not actor.allied:
			actor.dead=true;arena.room.actors.erase(actor);arena.burst(actor.position,Color("c9cfc4"),.4);actor.queue_free()
	arena.room.room_cleared=true;arena.room.reward_claimed=true;arena.room.next_is_room=true
	arena.flow.place_flag("Выход")
	arena.reward.drop_recipe(arena.grid_pos(pos),{"elite":true})
	var pickup=arena.room.pickups.back();pickup["offers"]=reward_offers(arena.room.difficulty)
	if is_instance_valid(arena.presentation):arena.presentation.announce("Испытание пройдено","Забери награду",.8)
func record_success():
	Game.progression.event("challenge_"+arena.room.mode);Game.progression.event("challenge_any")
	if arena.room.difficulty>=2:Game.progression.event("challenge_hard")
func drop_reward():
	var cell=Vector2i(int(arena.room.grid_size/2),int(arena.room.grid_size/2)-1)
	arena.reward.drop_recipe(cell,{"elite":true})
	var pickup=arena.room.pickups.back();pickup["offers"]=reward_offers(arena.room.difficulty)
	arena.toast("Засада отбита · забери награду")
## ★ simple: alloy and common cards; ★ rare cards or a blueprint; ★★ epic cards, extra alloy or a rare blueprint.
func reward_offers(difficulty:int)->Array:
	var rng=arena.run.combat_rng
	var cards=RunUpgrades.roll_offers(arena,2)
	var tier=clampi(difficulty,0,2)
	var result=[]
	for offer in cards:result.append({"category":"upgrade","id":offer.id,"tier":maxi(tier,int(offer.tier))})
	var extra={"category":"alloy","id":"alloy","amount":EncounterRules.chest_alloy(arena.room.room_index,difficulty),"tier":0}
	if difficulty>=2:extra={"category":"alloy","id":"alloy","amount":extra.amount+Game.DOC_ALLOY,"tier":2}
	if difficulty>=1:
		var recipe=EncounterRules.recipe(difficulty,rng,arena.run.pending_recipes,Campaign.progress_index(arena.room.room_index))
		if not recipe.is_empty() and (difficulty==1 or rng.randf()<.5):extra=recipe
	result.insert(0,extra)
	while result.size()<3:result.append({"category":"alloy","id":"alloy","amount":EncounterRules.chest_alloy(arena.room.room_index,difficulty),"tier":0})
	return result.slice(0,3)
