class_name ChallengeRooms
extends RefCounted
## Special route rooms that reuse the battlefield (HQ is always present).
## cache — a chest in the centre; leaving is allowed at once, opening it calls a veteran ambush,
## surviving it drops a reward chest whose value follows the room difficulty.
## hold — stand in the zone while enemies keep coming; progress grows only while no enemy is inside.
## survive — weapons are out of ammo; dodge artillery markers until the timer ends.
const TITLES={"cache":"Тайник","hold":"Удержание","survive":"Выживание"}
const AMBUSH_SIZE=[4,6,8]
const HOLD_SECONDS=[30,40,50]
const HOLD_RADIUS=1.6
const SURVIVE_SECONDS=[25,35,45]
const SHELL_INTERVAL=[1.1,.8,.6]
const SHELL_RADIUS=[1.2,1.4,1.6]
const SHELL_FUSE=1.5
var progress=0.0
var goal=0.0
var zone:Node3D
var shell_timer=0.0
var shells:Array=[]
var wave_cycle=0
var arena
var opened=false
var rewarded=false
var chest:Dictionary={}
func _init(context):
	arena=context
func active()->bool:return arena.room.mode!="battle"
## Rooms that finish by their own rule, not by an empty wave queue.
func blocks_waves()->bool:return arena.room.mode in ["hold","survive"] and not rewarded
func weapons_locked()->bool:return arena.room.mode=="survive" and not rewarded
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
	if chest.is_empty() or opened or not is_instance_valid(arena.room.player):return {}
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
				rewarded=true;drop_reward()
		"hold":tick_hold(delta)
		"survive":tick_survive(delta)
func status()->String:
	match arena.room.mode:
		"cache":return TITLES.cache+(" · засада" if opened and not rewarded else "")
		"hold","survive":return TITLES[arena.room.mode]+(" · %d / %d с" % [floori(progress),roundi(goal)] if not rewarded else " · готово")
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
	if is_instance_valid(player) and in_zone(player.position) and not contested:progress=minf(goal,progress+delta)
	elif not is_instance_valid(player) or not in_zone(player.position):progress=maxf(0,progress-delta*.25)
	if progress>=goal:complete(zone.position)

func start_survive():
	goal=SURVIVE_SECONDS[clampi(arena.room.difficulty,0,2)]
	if is_instance_valid(arena.presentation):arena.presentation.announce("Патроны кончились","Уклоняйся от обстрела",.8)
	arena.toast("Выживание: оружие не стреляет — уходи из красных меток")
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
	if is_instance_valid(player) and not player.dead and arena.flat_distance(pos,player.position)<shell.radius:player.take_damage(1,player.position-pos+Vector3(.01,0,.01))
	for cell in arena.room.walls.keys():
		if arena.flat_distance(pos,arena.world_pos(cell))<shell.radius:arena.damage_wall(cell,2)

## Challenge won: remaining enemies withdraw, the exit and the reward chest appear.
func complete(pos:Vector3):
	if rewarded:return
	rewarded=true
	arena.room.spawn_queue.clear()
	for actor in arena.room.actors.duplicate():
		if is_instance_valid(actor) and not actor.dead and not actor.player_owned and not actor.allied:
			actor.dead=true;arena.room.actors.erase(actor);arena.burst(actor.position,Color("c9cfc4"),.4);actor.queue_free()
	arena.room.room_cleared=true;arena.room.reward_claimed=true;arena.room.next_is_room=true
	arena.flow.place_flag("Выход")
	arena.reward.drop_recipe(arena.grid_pos(pos),{"elite":true})
	var pickup=arena.room.pickups.back();pickup["offers"]=reward_offers(arena.room.difficulty)
	if is_instance_valid(arena.presentation):arena.presentation.announce("Испытание пройдено","Забери награду",.8)
func drop_reward():
	var cell=Vector2i(int(arena.room.grid_size/2),int(arena.room.grid_size/2)-1)
	arena.reward.drop_recipe(cell,{"elite":true})
	var pickup=arena.room.pickups.back();pickup["offers"]=reward_offers(arena.room.difficulty)
	arena.toast("Засада отбита · забери награду")
## ★ simple: alloy and common cards; ★ rare cards or a blueprint; ★★ epic cards, documents or a rare blueprint.
func reward_offers(difficulty:int)->Array:
	var rng=arena.run.combat_rng
	var cards=RunUpgrades.roll(arena,2)
	var tier=clampi(difficulty,0,2)
	var result=[]
	for id in cards:result.append({"category":"upgrade","id":id,"tier":tier})
	var extra={"category":"alloy","id":"alloy","amount":EncounterRules.chest_alloy(arena.room.room_index,difficulty),"tier":0}
	if difficulty>=2:extra={"category":"documents","id":"documents","amount":1,"tier":2}
	if difficulty>=1:
		var recipe=EncounterRules.recipe(difficulty,rng,arena.run.pending_recipes,Campaign.progress_index(arena.room.room_index))
		if not recipe.is_empty() and (difficulty==1 or rng.randf()<.5):extra=recipe
	result.insert(0,extra)
	while result.size()<3:result.append({"category":"alloy","id":"alloy","amount":EncounterRules.chest_alloy(arena.room.room_index,difficulty),"tier":0})
	return result.slice(0,3)
