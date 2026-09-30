class_name ChallengeRooms
extends RefCounted
## Special route rooms that reuse the battlefield (HQ is always present).
## cache — a chest in the centre; leaving is allowed at once, opening it calls a veteran ambush,
## surviving it drops a reward chest whose value follows the room difficulty.
const TITLES={"cache":"Тайник"}
const AMBUSH_SIZE=[4,6,8]
var arena
var opened=false
var rewarded=false
var chest:Dictionary={}
func _init(context):
	arena=context
func active()->bool:return arena.room.mode!="battle"
func start():
	opened=false;rewarded=false;chest={}
	arena.room.spawn_queue.clear();arena.room.wave_roster.clear();arena.room.wave_spawned=0;arena.room.upgrade_offers.clear()
	match arena.room.mode:
		"cache":start_cache()
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
func tick():
	if arena.room.mode=="cache" and opened and not rewarded and arena.room.spawn_queue.is_empty() and arena.enemy_count()==0:
		rewarded=true;drop_reward()
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
