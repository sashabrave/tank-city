extends RefCounted
## One field engine (guides/02_development/07_one_world.md): the upgrade rooms and the merchant are not separate
## scenes any more but a non-combat mode of the run's Arena — room.mode "service". The arena keeps its hero Actor
## (movement, collision, shooting through Gun/CombatSystem, abilities through RunAbility, the effects bus, HUD,
## pickups and the drop floor); the playground (scripts/playground.gd) only brings its layout and interactables.
## No waves, no HQ on the field, no enemies, no damage to the hero.
var arena
## The hero's battle state before the room (vehicle, armour…): the next field gets it back (begin_room).
var carried:Dictionary={}
## Floor-to-camera framing of the rooms (the old room scenes used the same ortho size).
const CAMERA_SIZE:=11.4
func _init(context):arena=context

func active()->bool:return arena.room.mode=="service"
## The playground on the field now (null in battle and on the route map).
func ground():
	var node=arena.get("playground")
	return node if is_instance_valid(node) else null

## Builds the room field around `playground` (not yet in the tree; its `branch`/`index` set by the caller).
func begin(index:int,playground:Node3D):
	remember_hero()
	arena.ensure_armed(true)
	preload("res://scripts/battle_stage.gd").stop(arena)
	arena.room.base_model=null;arena.room.base_label=null;arena.room.base_bar=null
	if arena.has_meta("arriving_vehicle"):arena.remove_meta("arriving_vehicle")
	for child in arena.get_children():
		if child==arena.presentation or child==arena.hud or child==arena.camera or child is WorldEnvironment or child is DirectionalLight3D or child.name in ["WorldLighting","WorldAtmosphere","SandboxAdmin"]:continue
		arena.remove_child(child);child.queue_free()
	var room=arena.room
	if room.has_meta("pending_flag"):room.remove_meta("pending_flag")
	room.commander_countdown=false;room.room_boss_spawned=false;room.flag=null;room.flag_armed=false;room.upgrade_offers.clear();room.trenches.clear()
	room.resource_drops.clear();room.actors.clear();room.wrecks.clear();room.walls.clear();room.pickups.clear();room.nets.clear();room.projectiles.clear();room.bombs.clear();room.grenades.clear()
	room.spawn_queue.clear();room.wave_roster.clear();room.wave_spawned=0;room.spawn_markers.clear();room.generators.clear()
	room.commander=null;room.commander_help_pool.clear();room.generator_thresholds.clear();room.generator_order.clear()
	room.star_time=0.0;room.freeze_time=0.0;room.pressure_time=0.0;room.recipe_offer={};room.draft_pickup={}
	# room_index stays the last field: the biome around the room and the prizes of its machines follow it.
	room.mode="service";room.boss_room=false;room.boss_defeated=false;room.twin_boss=false
	room.room_cleared=true;room.reward_claimed=true;room.difficulty=0
	arena.challenges.reset()
	room.grid_size=playground.field_size();room.base_cell=Vector2i(int(room.grid_size/2),room.grid_size-1)  # no HQ here (hq_off_field)
	arena.navigation.reset();arena.terrain.patches.clear()
	frame_camera(arena.camera,CAMERA_SIZE)
	playground.arena=arena;arena.playground=playground
	arena.add_child(playground)
	for cell in playground.solid_cells():block(cell)
	var feel=preload("res://scripts/combat/combat_feel.gd").new();arena.add_child(feel);feel.setup(arena)
	var lighting=arena.get_node("WorldLighting");lighting.day_background=Color("bec3b8");lighting.apply()
	var atmosphere=arena.get_node("WorldAtmosphere");atmosphere.clear_clouds();atmosphere.apply()
	preload("res://scripts/world_lighting.gd").reflection_probe(arena,Vector3(room.grid_size+4,6,room.grid_size+4))
	arena.player=arena.spawn_actor("soldier",arena.grid_pos(playground.start_position()),true)
	arena.player.position=playground.start_position()
	arena.phase="combat"
	if is_instance_valid(arena.hud):arena.hud.service_mode(true)
	playground.field_ready()

## The hero's vehicle (or the soldier) before the room: kept for the next field, never lost in the room.
func remember_hero():
	if not carried.is_empty():return
	var p=arena.player
	if is_instance_valid(p) and not p.dead and p.player_owned:
		carried={"kind":str(p.kind),"hp":float(p.hp),"salvaged":bool(p.salvaged),"origin":str(p.vehicle_origin),"zone":int(p.vehicle_zone)}
	elif not arena.resume_checkpoint.is_empty() and not arena.resume_checkpoint.get("hero",{}).is_empty():
		carried=arena.resume_checkpoint.hero.duplicate(true)
	if not arena.resume_checkpoint.is_empty():arena.resume_checkpoint={}
## What the hero brings into the next field: {kind, hp, salvaged, origin, zone}; empty — the soldier as he is.
func hero()->Dictionary:return carried if active() or not carried.is_empty() else {}
## The vehicle the hero rides into the next field ("" on foot).
func vehicle_kind()->String:
	if arena.pending_vehicle in GarageCatalog.VEHICLES:return str(arena.pending_vehicle)
	var kind=str(carried.get("kind",""))
	return kind if kind in GarageCatalog.VEHICLES else ""
## Full armour of the carried vehicle (merchant «Ремонт машины»).
func vehicle_full_armor()->float:
	var kind=str(carried.get("kind",""))
	if kind not in GarageCatalog.VEHICLES:return 0.0
	return float(arena.vehicle.player_armor(kind,str(carried.get("origin","owned")),int(carried.get("zone",1))))
## Hands the carried state to begin_room once (and forgets it).
func take_carried()->Dictionary:
	var result=carried;carried={};return result

## A solid cell of the room (walls, props): the arena's own indestructible wall without a visual, so the hero's
## collision, bullets, blasts and the laser stop there exactly like on a battle field.
func block(world_cell:Vector2i):
	var cell=arena.grid_pos(Vector3(world_cell.x,0,world_cell.y))
	if not arena.inside(cell) or arena.walls.has(cell):return
	var node=Node3D.new();node.name="RoomSolid";arena.add_child(node);node.position=arena.world_pos(cell)
	arena.walls[cell]={"node":node,"hp":-1,"max_hp":-1,"room_solid":true}
	arena.navigation.invalidate(cell)
func unblock(world_cell:Vector2i):
	var cell=arena.grid_pos(Vector3(world_cell.x,0,world_cell.y))
	if not arena.walls.has(cell) or not arena.walls[cell].get("room_solid",false):return
	var wall=arena.walls[cell];arena.walls.erase(cell);arena.navigation.invalidate(cell)
	if is_instance_valid(wall.node):wall.node.queue_free()

## A practice target on a room stand (the instructor's targets): a real field actor of the enemy side — bullets,
## charges, abilities, statuses and card effects hit it exactly as an enemy — that stands still and never falls
## (actor.gd «practice_target»). Its look is the stand of the room model; `model_kind` adds a model of its own.
## Built on the room's own generator (surprise_rng), the run's combat generator is not touched by the spawn.
func spawn_target(at:Vector3,model_kind:=""):
	var target=load("res://scenes/soldier.tscn").instantiate()
	target.set_meta("practice_target",true)
	target.arena=arena;target.player_owned=false;target.allied=false;target.surprise_spawn=true;target.enemy_weapon="pistol"
	var cell=arena.grid_pos(at);target.cell=cell;target.destination=cell;target.position=at
	arena.add_child(target);arena.room.actors.append(target)
	if is_instance_valid(target.model):
		if model_kind!="":
			target.model.queue_free();target.model=Visuals.model(model_kind,target,Vector3.ZERO);target.model.rotation.y=PI
		else:target.model.visible=false
	preload("res://scripts/status_fx.gd").of(target)
	return target

## Room frame: the same fixed orthographic view as Visuals.setup_world around the room's centre.
static func frame_camera(camera:Camera3D,size:float):
	if not is_instance_valid(camera):return
	camera.size=size;camera.h_offset=0;camera.v_offset=0
	camera.position=Vector3(0,19,14).rotated(Vector3.UP,deg_to_rad(10))
	camera.look_at(Vector3.ZERO)

## A frame of the room: what battle runs between waves, minus waves, the HQ and the clock. Windows of the playground
## (cards, the shop, a machine) hold the field like the battle's card screens: phase «upgrade» while one is open.
func tick(delta:float):
	var playground=ground()
	if playground!=null and arena.phase in ["combat","upgrade"]:
		var hold=playground.window_open()
		if hold and arena.phase=="combat":arena.phase="upgrade";Game.reset_input()
		elif not hold and arena.phase=="upgrade":arena.phase="combat";Game.reset_input()
	if arena.phase!="combat":return
	arena.room.freeze_time=maxf(0,arena.room.freeze_time-delta);arena.room.pressure_time=maxf(0,arena.room.pressure_time-delta)
	arena.room.star_time=maxf(0,arena.room.star_time-delta)
	arena.abilities.tick(delta)
	if Input.is_action_just_pressed("ammo_switch") and Ammo.switch(arena):arena.hud.refresh_ammo()
	for slot in range(arena.abilities.slots.size()):
		if Input.is_action_just_pressed(arena.abilities.action_for(slot)):arena.abilities.cast_slot(slot)
	arena.collect_nearby_pickups(delta)

## E on the room field: a dropped item's card answers first, then the playground's spots.
func interact():
	if arena.phase!="combat" or not is_instance_valid(arena.player):return
	var playground=ground()
	if playground!=null:playground.interact()

## The room is over (left to the map): the playground goes, the field stays empty until the next begin_room.
func finish():
	var playground=ground()
	if playground!=null:
		if playground.get_parent()==arena:arena.remove_child(playground)
		playground.queue_free()
	arena.playground=null
	if is_instance_valid(arena.hud):arena.hud.service_mode(false)
