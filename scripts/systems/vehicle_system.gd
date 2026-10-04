extends RefCounted
## Vehicle system. Owns rules; Arena remains the scene coordinator.
var arena

func _init(context):
	arena=context

func make_wreck(kind: String,cell: Vector2i,facing: Vector2i,unstable: bool,armor=0,origin:String="owned",zone:int=1):
	var wreck=load("res://scenes/wreck.tscn").instantiate()
	wreck.arena=arena; wreck.kind=kind; wreck.cell=cell; wreck.facing=facing; wreck.unstable=unstable; wreck.armor=armor;wreck.boardable=not unstable
	wreck.vehicle_origin=origin;wreck.vehicle_zone=zone
	wreck.max_armor=player_armor(kind,origin,zone)
	wreck.position=arena.world_pos(cell)
	arena.add_child(wreck)
	preload("res://scripts/interaction_prompt.gd").attach(wreck,arena,"Занять транспорт",Vector3.ZERO,1.65,func():return is_instance_valid(wreck) and wreck.boardable and not wreck.spent)
	arena.room.wrecks.append(wreck)
	return wreck

func nearest_wreck():
	if not is_instance_valid(arena.room.player): return null
	var best=null; var distance=1.65
	for wreck in arena.room.wrecks:
		if not is_instance_valid(wreck) or wreck.spent or not wreck.boardable or wreck.unstable: continue
		var d=arena.flat_distance(arena.room.player.position,wreck.position)
		if d<distance: best=wreck; distance=d
	return best

func unlocked_vehicle() -> String:
	return ["buggy","apc","tank"][Campaign.world-1] if arena.room.room_index>0 or arena.room.wave>=2 else ""

func install_turret():
	for side in [-1,1]:
		var cell=Vector2i(arena.room.base_cell.x+side*2,arena.room.grid_size-2)
		if arena.room.actors.any(func(a):return is_instance_valid(a) and a.allied and a.cell==cell):continue
		if not arena.can_enter(cell):continue
		var turret=arena.spawn_actor("mortar",cell,false,true)
		turret.max_hp+=arena.effective_bonus_level("turret");turret.hp=turret.max_hp;turret.refresh_health()
		turret.fire_cooldown=1.0
		arena.toast("Гранатная турель установлена "+("слева" if side<0 else "справа"))
		return
	arena.toast("Оба места для турелей заняты или заблокированы")

func allied_flyer_step(actor,delta):
	actor.fire_cooldown=maxf(0,actor.fire_cooldown-delta)
	var target=null;var distance=INF
	for enemy in arena.room.actors:
		if not is_instance_valid(enemy) or enemy.dead or enemy.player_owned or enemy.allied:continue
		var d=arena.flat_distance(actor.position,enemy.position)
		if d<distance:target=enemy;distance=d
	var destination=arena.world_pos(flyer_spot(actor,target,delta))
	# Along the grid like the enemy drones (T-274): one axis at a time, to the centre of a cell.
	destination.y=actor.position.y
	var step=delta*actor.speed
	if absf(destination.x-actor.position.x)>.01:actor.position.x=move_toward(actor.position.x,destination.x,step)
	else:actor.position.z=move_toward(actor.position.z,destination.z,step)
	actor.cell=arena.grid_pos(actor.position)
	if target!=null and distance<7 and actor.fire_cooldown<=0:
		actor.fire_cooldown=1.1;var dir=(target.position-actor.position).normalized()
		actor.model.aim(atan2(-dir.x,-dir.z),-.12);actor.model.kick()
		var bullet=arena.spawn_bullet(actor,actor.position,Vector2i.UP,actor.damage,true);bullet.travel_direction=dir;bullet.flyer_round=true;bullet.position=actor.position+Vector3.UP*.9

## Helper drone posts (T-302, author: «висит ровно за игроком / ровно за врагом»). At rest it scouts: every
## SCOUT_HOLD seconds it moves to the next cell of a ring around the hero; in a fight it circles the target and
## changes its side every ATTACK_HOLD seconds. A fixed cycle (no dice), each drone starting at its own place in it,
## so the combat RNG is untouched.
const SCOUT_SPOTS:=[Vector2i(1,-1),Vector2i(2,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(-2,0),Vector2i(-1,-2),Vector2i(1,-2),Vector2i(2,1)]
const ATTACK_SPOTS:=[Vector2i(0,3),Vector2i(3,0),Vector2i(-2,2),Vector2i(0,-3),Vector2i(-3,0),Vector2i(2,-2),Vector2i(2,2),Vector2i(-2,-2)]
const SCOUT_HOLD:=1.8
const ATTACK_HOLD:=2.6
func flyer_spot(actor,target,delta:float)->Vector2i:
	var plan:Dictionary=actor.get_meta("scout_plan",{})
	if plan.is_empty():
		var order=int(arena.get_meta("scout_drones",0));arena.set_meta("scout_drones",order+1)
		plan={"index":order*3,"timer":0.0,"mode":""}
	var attacking=target!=null
	var mode="attack" if attacking else "scout"
	if plan.mode!=mode:plan.mode=mode;plan.timer=0.0
	plan.timer-=delta
	var anchor:Vector2i=arena.grid_pos(target.position) if attacking else arena.room.player.cell
	var spots:Array=ATTACK_SPOTS if attacking else SCOUT_SPOTS
	if plan.timer<=0:
		plan.timer=ATTACK_HOLD if attacking else SCOUT_HOLD
		# Next post of the cycle that lies on the field (the drone flies over cover, never off the board).
		for i in range(spots.size()):
			plan.index+=1
			if arena.inside(anchor+spots[plan.index%spots.size()]):break
	actor.set_meta("scout_plan",plan)
	var spot:Vector2i=anchor+spots[plan.index%spots.size()]
	return Vector2i(clampi(spot.x,0,arena.room.grid_size-1),clampi(spot.y,0,arena.room.grid_size-1))

func summon_comrade(factor:float,utility:float):
	var buddy=arena.spawn_actor("soldier",arena.find_free_near(arena.room.player.cell),false,true);buddy.companion=true;buddy.companion_factor=factor
	var weapons=arena.LOOT.gun_ids();buddy.companion_weapon=weapons[arena.run.combat_rng.randi_range(0,weapons.size()-1)];var data=arena.LOOT.WEAPONS[buddy.companion_weapon]
	buddy.max_hp=maxf(1,arena.run.soldier_max_hp*factor);buddy.hp=buddy.max_hp;buddy.speed=3.8*.8*(1+utility*.1);buddy.damage=data.damage*(1+Game.damage_level*Game.DAMAGE_PER_LEVEL+arena.run.damage_bonus*.3)*factor;buddy.fire_interval=data.interval
	buddy.parachute_left=maxf(1,3-utility*.3);buddy.model.position.y=5;Visuals.equip_model(buddy.model,buddy.companion_weapon)
	buddy.parachute=Node3D.new();buddy.model.add_child(buddy.parachute)
	Visuals.parachute(buddy.parachute,1.7,.95)
	Visuals.label3d(buddy,"Товарищ",Vector3(0,1.8,0),Color("a6eeb4"),22);buddy.refresh_health()
func comrade_step(buddy,delta):
	if buddy.parachute_left>0:
		buddy.parachute_left=maxf(0,buddy.parachute_left-delta);buddy.model.position.y=buddy.parachute_left*1.7
		if buddy.parachute_left==0:buddy.parachute.queue_free();buddy.model.position.y=0;Game.sound("delivery_land",buddy)
		return
	buddy.fire_cooldown=maxf(0,buddy.fire_cooldown-delta)
	if not buddy.moving:arena.terrain.begin_slide(buddy)
	if buddy.moving:
		var target=buddy.quarter_destination if buddy.terrain_sliding else arena.world_pos(buddy.destination)
		var next=buddy.position.move_toward(target,buddy.speed*arena.terrain.speed_factor(buddy)*delta)
		if arena.can_stand(next,buddy):buddy.position=next
		else:buddy.moving=false;buddy.terrain_sliding=false
		if buddy.position.distance_to(target)<.01:buddy.cell=buddy.destination;buddy.moving=false;buddy.terrain_sliding=false
		return
	buddy.brain_cooldown-=delta
	if buddy.brain_cooldown>0:return
	buddy.brain_cooldown=.2
	# Field cleared: the comrade leaves the vehicle standing for the player (T-258: it kept the car to itself).
	if buddy.kind!="soldier" and arena.room.room_cleared:dismount_comrade(buddy);return
	# T-167: the comrade fights every enemy it can reach, not only the nearest one (it used to stand still when
	# that one was diagonal or behind water), and walks to any cell with a clear line on some enemy.
	var reach=float(arena.LOOT.WEAPONS[buddy.companion_weapon].range) if buddy.kind=="soldier" and buddy.get("companion_weapon")!=null and arena.LOOT.WEAPONS.has(buddy.companion_weapon) else 7.0
	var enemies=arena.room.actors.filter(func(e):return is_instance_valid(e) and not e.dead and not e.player_owned and not e.allied)
	var target=null;var best=INF;var shot=Vector2i.ZERO
	for enemy in enemies:
		var direction=arena.aligned_direction(buddy.cell,enemy.cell);var d=arena.flat_distance(buddy.position,enemy.position)
		if direction!=Vector2i.ZERO and d<=reach and d<best and arena.clear_line(buddy.cell,enemy.cell):best=d;target=enemy;shot=direction
	if target!=null:
		buddy.facing=shot;buddy.model.rotation.y=buddy.angle_for(shot)
		if buddy.fire_cooldown<=0:
			buddy.fire_cooldown=buddy.fire_interval
			if buddy.kind=="soldier":fire_comrade_weapon(buddy)
			else:arena.spawn_bullet(buddy,buddy.position,shot,buddy.damage,true)
		return
	# No shot: with nobody to fight, board a nearby wreck or stay by the player.
	var goal=arena.room.player.cell
	if enemies.is_empty() and buddy.kind=="soldier" and not arena.room.room_cleared:
		for wreck in arena.room.wrecks.duplicate():
			if not is_instance_valid(wreck) or wreck.spent or not wreck.boardable or wreck.unstable:continue
			var d=arena.flat_distance(buddy.position,wreck.position)
			if d<1.6:
				var vehicle=arena.spawn_actor(wreck.kind,buddy.cell,false,true);vehicle.companion=true;vehicle.companion_factor=buddy.companion_factor;vehicle.damage*=1+buddy.companion_factor;vehicle.hp=minf(vehicle.max_hp,maxf(1,wreck.armor if not wreck.unstable else vehicle.max_hp*.6));vehicle.refresh_health()
				# Who drives it, so the same comrade climbs out when the field is cleared (T-258).
				vehicle.set_meta("comrade",{"weapon":buddy.companion_weapon,"max_hp":buddy.max_hp,"hp":buddy.hp,"speed":buddy.speed,"damage":buddy.damage,"interval":buddy.fire_interval})
				wreck.spent=true;arena.room.wrecks.erase(wreck);wreck.queue_free();arena.room.actors.erase(buddy);buddy.queue_free();return
			if d<8:goal=wreck.cell
	var firing_cell=func(cell:Vector2i)->bool:
		for enemy in enemies:
			if arena.aligned_direction(cell,enemy.cell)!=Vector2i.ZERO and arena.flat_distance(arena.world_pos(cell),enemy.position)<=reach and arena.clear_line(cell,enemy.cell):return true
		return false
	var queue=[buddy.cell];var came={buddy.cell:buddy.cell};var head=0;var destination=buddy.cell
	while head<queue.size() and head<600:
		var cell=queue[head];head+=1
		if cell!=buddy.cell and (firing_cell.call(cell) if not enemies.is_empty() else (cell-goal).length()<=1.1):destination=cell;break
		for direction in arena.DIRS:
			var next=cell+direction
			if came.has(next) or not arena.can_enter(next,buddy):continue
			came[next]=cell;queue.append(next)
	if destination!=buddy.cell:
		while came[destination]!=buddy.cell:destination=came[destination]
		buddy.facing=destination-buddy.cell;buddy.model.rotation.y=buddy.angle_for(buddy.facing);buddy.destination=destination;buddy.moving=true;buddy.terrain_direction=buddy.facing;buddy.terrain_sliding=false
## The comrade steps out of the vehicle it drove: the vehicle stays as a free wreck to board, with the armor it has left.
func dismount_comrade(vehicle):
	var info:Dictionary=vehicle.get_meta("comrade",{})
	make_wreck(vehicle.kind,vehicle.cell,vehicle.facing,false,maxf(1,vehicle.hp))
	arena.room.actors.erase(vehicle);vehicle.queue_free()
	var weapon=str(info.get("weapon",arena.LOOT.gun_ids()[0]))
	var buddy=arena.spawn_actor("soldier",arena.find_free_near(vehicle.cell),false,true);buddy.companion=true;buddy.companion_factor=vehicle.companion_factor;buddy.companion_weapon=weapon
	buddy.max_hp=float(info.get("max_hp",maxf(1,arena.run.soldier_max_hp*vehicle.companion_factor)));buddy.hp=clampf(float(info.get("hp",buddy.max_hp)),1,buddy.max_hp)
	buddy.speed=float(info.get("speed",3.0));buddy.damage=float(info.get("damage",arena.LOOT.WEAPONS[weapon].damage));buddy.fire_interval=float(info.get("interval",arena.LOOT.WEAPONS[weapon].interval))
	Visuals.equip_model(buddy.model,weapon);Visuals.label3d(buddy,"Товарищ",Vector3(0,1.8,0),Color("a6eeb4"),22);buddy.refresh_health()

func fire_comrade_weapon(buddy):
	var data=arena.LOOT.WEAPONS[buddy.companion_weapon]
	for i in range(data.pellets):
		var bullet=arena.spawn_bullet(buddy,buddy.position,buddy.facing,buddy.damage,true);bullet.travel_direction=bullet.travel_direction.rotated(Vector3.UP,(i-(data.pellets-1)*.5)*.1);bullet.speed=data.speed;bullet.lifetime=data.range/data.speed;bullet.piercing=data.pierce;bullet.rocket_radius=data.blast

func interact_vehicle():
	# No player between death and respawn (or after the run ended): nothing to board or leave.
	if not is_instance_valid(arena.room.player) or arena.room.player.dead:return
	if arena.room.player.kind!="soldier":
		var safe=arena.find_free_near(arena.room.player.cell)
		if not arena.can_enter(safe): return
		var previous_actor=arena.room.player
		var parked=arena.make_wreck(previous_actor.kind,previous_actor.cell,previous_actor.facing,false,previous_actor.hp,previous_actor.vehicle_origin,previous_actor.vehicle_zone);parked.salvaged=previous_actor.salvaged;parked.position=previous_actor.position
		arena.room.actors.erase(previous_actor)
		previous_actor.dead=true
		arena.room.player=arena.spawn_actor("soldier",safe,true)
		arena.effects.emit("vehicle_exit",{"vehicle":previous_actor})
		if "landing" in arena.run.behavior_cards:arena.run.landing_until=arena.run.elapsed+3.0;arena.toast("Десант · 3 с")
		arena.room.player.invulnerable=.7
		previous_actor.queue_free()
		Game.sound("vehicle_exit",arena);Game.sound("engine_stop",arena)
		arena.toast("Транспорт оставлен")
		return
	var wreck=arena.nearest_wreck()
	if wreck==null or wreck.unstable: return
	var old=arena.room.player
	var cell: Vector2i=wreck.cell
	var dir: Vector2i=wreck.facing
	wreck.spent=true
	arena.room.wrecks.erase(wreck)
	arena.room.actors.erase(old)
	old.dead=true
	arena.room.player=arena.spawn_actor(wreck.kind,cell,true,false,1,false,"",wreck.vehicle_origin,wreck.vehicle_zone)
	arena.room.player.position=wreck.position
	arena.room.player.salvaged=wreck.salvaged
	arena.room.player.hp=maxf(1,ceilf(arena.room.player.max_hp*.6)) if wreck.unstable else clampf(wreck.armor,.25,arena.room.player.max_hp)
	arena.room.player.facing=dir
	arena.room.player.model.rotation.y=arena.room.player.angle_for(dir)
	arena.room.player.invulnerable=.8
	if "boarding" in arena.run.behavior_cards and wreck.vehicle_origin=="captured":arena.room.player.hp=arena.room.player.max_hp;arena.toast("Абордаж · машина починена")
	arena.effects.emit("vehicle_enter",{"vehicle":arena.room.player})
	arena.room.player.refresh_health()
	old.queue_free()
	wreck.queue_free()
	Game.sound("vehicle_enter",arena);Game.sound("engine_start",arena)
	arena.toast("Транспорт занят · броня "+str(arena.room.player.hp))


func upgrade_at_service(kind:String,index:int,offer:Dictionary):
	var n=Balance.tier_power(offer.tier)
	var mods=arena.run.vehicle_mods[kind];mods.hp+=mini(index,6)
	match offer.id:
		"damage":mods.damage+=(.15 if kind=="buggy" else 1.0)*n
		"hp":mods.hp+=roundi(3*n)
		"speed":mods.speed=minf(1.25,mods.speed+.04*n)
		"rate":mods.rate=maxf(.7,float(mods.get("rate",1.0))-.04*n)
		"overhaul":mods.hp+=roundi(1.5*n);mods.damage+=(.08 if kind=="buggy" else .5)*n
	arena.run.pending_vehicle=kind

func player_armor(kind:String,origin:String="owned",zone:int=1)->float:
	return GarageCatalog.stats(kind,arena,origin,zone).hp
