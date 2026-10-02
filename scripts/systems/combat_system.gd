extends RefCounted
## Combat system. Owns rules; Arena remains the scene coordinator.
var arena

func _init(context):
	arena=context

func spawn_bullet(owner_actor,pos: Vector3,dir: Vector2i,damage: float,friendly: bool):
	Game.weapon_sound(owner_actor)
	var bullet = load("res://scenes/projectile.tscn").instantiate()
	bullet.arena=arena
	bullet.owner_actor=owner_actor
	bullet.sniper_visual=(arena.run.weapon=="sniper" if owner_actor.player_owned and owner_actor.kind=="soldier" else owner_actor.enemy_weapon=="sniper")
	bullet.wall_width=1.0 if owner_actor.kind in ["buggy","apc","tank","boss","mortar"] else .5
	bullet.vehicle_credit=owner_actor.kind if owner_actor.player_owned and owner_actor.kind in GarageCatalog.VEHICLES else ""
	bullet.direction=dir
	bullet.travel_direction=Vector3(dir.x,0,dir.y)
	bullet.piercing=friendly and owner_actor.kind=="tank"
	bullet.star_power=friendly and owner_actor.player_owned and arena.room.star_time>0
	bullet.damage=damage
	bullet.friendly=friendly
	bullet.player_shot=owner_actor.player_owned
	if friendly and owner_actor.player_owned and arena.run!=null:
		bullet.pierce_left=int(arena.run.pierce)
		# Выдержка: a volley after 1.5 s of silence is marked; every pellet of it keeps the bonus.
		var run=arena.run
		if "opening_shot" in run.behavior_cards and run.elapsed-run.last_player_shot>=1.5:run.opening_until=run.elapsed+.05
		bullet.opening=run.elapsed<=run.opening_until;run.last_player_shot=run.elapsed
	var muzzle=2.15 if is_instance_valid(owner_actor) and owner_actor.kind=="boss" else .39
	var muzzle_height=.55
	if is_instance_valid(owner_actor.model) and owner_actor.model.get("muzzle")!=null:
		muzzle_height=owner_actor.model.muzzle.global_position.y-owner_actor.position.y
	bullet.position=pos+Vector3(dir.x*muzzle,muzzle_height,dir.y*muzzle)
	bullet.speed = 20.0 if owner_actor.kind=="buggy" else (13.0 if friendly else 7.5)
	arena.add_child(bullet)
	arena.room.projectiles.append(bullet)
	var feel=arena.get_node_or_null("CombatFeel")
	if feel:
		feel.muzzle(owner_actor,bullet.global_position,bullet.travel_direction)
		if owner_actor.player_owned and owner_actor.kind=="soldier":feel.casing(owner_actor,bullet.travel_direction)
	return bullet

func bullet_hit(bullet) -> bool:
	var pos: Vector3=bullet.position
	var cell=arena.grid_pos(pos)
	if not arena.inside(cell): return true
	if bullet.friendly and arena.room.generators.has(cell):arena.damage_generator(cell,bullet.damage);return true
	if bullet.friendly:
		for flying in arena.room.actors.duplicate():
			if is_instance_valid(flying) and not flying.dead and not flying.allied and not flying.player_owned and flying.kind=="flyer" and flying not in bullet.hit_actors and arena.flat_distance(pos,flying.position)<.38:
				bullet.hit_actors.append(flying);flying.take_damage(flying.max_hp if bullet.star_power else (CombatMods.outgoing(arena,bullet,flying) if CombatMods.player_bullet(bullet) else bullet.damage),Vector3.ZERO,bullet.vehicle_credit)
				if not pierce_on(bullet):return true
	if bullet.piercing and arena.room.nets.has(cell):
		arena.shred_net(cell)
	if bullet.sniper_round:
		# Elevated shot: cover is passed over, never damaged. Each target is hit once.
		if not bullet.friendly and not arena.room.boss_room and cell==arena.room.base_cell and not bullet.hit_base:
			bullet.hit_base=true;damage_base(bullet.damage)
		var target=arena.room.player
		if is_instance_valid(target) and not target.dead and target not in bullet.hit_actors and not (arena.abilities.cloak_time>0 and arena.abilities.cloak_ghost) and arena.flat_distance(pos,target.position)<.38:
			bullet.hit_actors.append(target);target.take_damage(bullet.damage,Vector3.ZERO,"","bullet")
		return false
	if bullet.rocket_radius>0:
		var impact=not arena.wall_contacts(pos,bullet.travel_direction,bullet.wall_width).is_empty() or (not bullet.friendly and not arena.room.boss_room and cell==arena.room.base_cell)
		for enemy in arena.room.actors:
			if is_instance_valid(enemy) and not enemy.dead and (enemy.player_owned or enemy.allied)!=bullet.friendly and enemy!=bullet.owner_actor and arena.flat_distance(pos,enemy.position)<(.9 if enemy.kind=="boss" else .4):impact=true
		if impact:rocket_impact(bullet);return true
	if arena.room.generators.has(cell):return true
	var contacts=arena.wall_contacts(pos,bullet.travel_direction,bullet.wall_width) if not bullet.flyer_round else []
	if not contacts.is_empty():
		for contact in contacts:
			if bullet.star_power:
				arena.room.walls[contact].node.queue_free();arena.room.walls.erase(contact);arena.navigation.invalidate(contact)
			else:
				Game.sound("ricochet" if arena.room.walls[contact].hp<0 else "hit",arena)
				var wall_damage=bullet.damage
				if arena.room.walls[contact].get("barrel",false) and CombatMods.player_bullet(bullet) and arena.run.burn_chance>0:wall_damage=arena.room.walls[contact].hp
				arena.board.damage_wall(contact,wall_damage,pos,bullet.travel_direction,bullet.wall_width)
		arena.burst(pos,Color("dc9870"),.16)
		return true
	for other in arena.room.projectiles.duplicate():
		if not is_instance_valid(other) or other==bullet or other.spent or other.friendly==bullet.friendly:continue
		if arena.flat_distance(pos,other.position)<.20:
			resolve_interception(bullet,other)
			if bullet.spent:return true
	for wreck in arena.room.wrecks.duplicate():
		if is_instance_valid(wreck) and not wreck.spent and arena.flat_distance(pos,wreck.position)<.44:
			wreck.take_damage(bullet.damage); return true
	for actor in arena.room.actors.duplicate():
		if actor==arena.room.player and arena.abilities.cloak_time>0 and arena.abilities.cloak_ghost:continue
		if not is_instance_valid(actor) or actor.dead or actor.hidden_in_trench or actor in bullet.hit_actors or actor==bullet.owner_actor or (actor.player_owned or actor.allied)==bullet.friendly: continue
		var hit=absf(pos.x-actor.position.x)<actor.footprint*.5-.1 and absf(pos.z-actor.position.z)<actor.footprint*.5-.1 if actor.footprint>1 else (absf(pos.x-actor.position.x)<.85 and absf(pos.z-actor.position.z)<.85) if actor.elite else arena.flat_distance(pos,actor.position)<(.30 if actor.kind in ["soldier","drone"] else .46)
		if hit:
			if not bullet.star_power and actor.blocks_shot(bullet.travel_direction):
				arena.burst(pos,Color("9eb6c3"),.3);Game.sound("ricochet",arena);return true
			bullet.hit_actors.append(actor)
			actor.resource_blast=Vector3.ZERO
			var amount=actor.max_hp if bullet.star_power else bullet.damage
			if not bullet.star_power and CombatMods.player_bullet(bullet):amount=CombatMods.outgoing(arena,bullet,actor)
			actor.take_damage(amount,Vector3.ZERO,bullet.vehicle_credit,CombatMods.bullet_source(bullet) if actor.player_owned else "")
			if CombatMods.player_bullet(bullet) and not actor.player_owned:arena.effects.emit("enemy_hit",{"target":actor,"bullet":bullet,"damage":amount})
			var feel=arena.get_node_or_null("CombatFeel")
			if feel and not actor.player_owned:feel.impact(actor,actor.position)
			if not pierce_on(bullet):return true
	if not arena.room.boss_room and not bullet.friendly and cell==arena.room.base_cell:
		damage_base(bullet.damage)
		return true
	return false

func damage_base(amount: float):
	if arena.room.boss_room or arena.phase != "combat" or arena.headquarters.shield_time>0: return
	if is_instance_valid(arena.base_model):
		var alert=arena.base_model.get_node_or_null("BaseAlert")
		if alert:alert.trigger()
	arena.headquarters.hit_delay=6.0
	arena.floating_number(arena.world_pos(arena.room.base_cell),-minf(arena.room.base_hp,amount))
	arena.room.base_hp=maxf(0,arena.room.base_hp-amount)
	if is_instance_valid(arena.room.base_bar):arena.room.base_bar.set_health(arena.room.base_hp,arena.room.base_max_hp)
	arena.burst(arena.world_pos(arena.room.base_cell)+Vector3.UP*.5,Color("e97437"),.8)
	Game.sound("base_hit",arena)
	arena.toast("База под огнём!")
	if arena.room.base_hp<=0: arena.finish_run(false,"База уничтожена")

func actor_destroyed(actor):
	var feel=arena.get_node_or_null("CombatFeel")
	if feel and not actor.player_owned:
		if actor.kind=="boss" or actor.elite:feel.shake(.55);feel.hit_stop(.12)
		elif UnitKinds.is_vehicle(actor.kind):feel.shake(.35);feel.hit_stop(.05)
	Game.sound("infantry_down" if UnitKinds.is_infantry(actor.kind) else "vehicle_destroy",actor)
	if is_instance_valid(actor.sniper_line):actor.sniper_line.queue_free()
	if actor.wave_slot>=0 and actor.wave_slot<arena.room.wave_roster.size():arena.room.wave_roster[actor.wave_slot].state="dead"
	arena.room.actors.erase(actor)
	if actor.allied:
		arena.burst(actor.position,Color("d69a54"),.7)
	elif actor.player_owned:
		if actor.kind=="soldier":
			arena.finish_run(false,"Котик выбыл")
			arena.room.player=null
		else:
			var cell=actor.cell
			arena.make_wreck(actor.kind,cell,actor.facing,true)
			var safe=arena.find_free_near(cell)
			arena.room.player=arena.spawn_actor("soldier",safe,true)
			arena.room.player.invulnerable=1.4
			arena.toast("Броня потеряна. Отойди от корпуса!")
	else:
		arena.reward.award_kill(actor)
		if actor.kind in ["drone","flyer"]:drone_death_explosion(actor.position)
		elif UnitKinds.is_vehicle(actor.kind):
			var wreck=arena.make_wreck(actor.kind,actor.cell,actor.facing,false,arena.vehicle.player_armor(actor.kind,"captured",Campaign.zone(arena.room_index))*.5,"captured",Campaign.zone(arena.room_index));wreck.salvaged=true
			mark_trophy(wreck)
			bail_out(actor,wreck)
		else: arena.burst(actor.position,Color("d69a54"),.8 if actor.kind=="boss" else .4)
		if actor.kind=="boss":
			if not arena.room.actors.any(func(a):return is_instance_valid(a) and not a.dead and a.kind=="boss") and arena.room.spawn_queue.is_empty():
				arena.room.boss_defeated=true;arena.room.reinforcement_timer=INF
				for support in arena.room.actors.duplicate():
					if not support.player_owned and not support.allied:support.dead=true;arena.room.actors.erase(support);support.queue_free()
				arena.drop_recipe(actor.cell,{});Game.music_stinger("boss_victory");arena.toast("Победа! Забери сундук командира")
		else:
			arena.reward.drop_enemy_loot(actor)
	if not actor.player_owned:leave_body(actor)
	actor.queue_free()

func leave_body(actor):
	# Visual only, cartoon: the knocked-out enemy flops, then vanishes in a puff (no lying bodies).
	var body=actor.model
	if not is_instance_valid(body) or not body.has_method("has_death") or not body.has_death():return
	body.reparent(arena);body.play_death()
	var tween=body.create_tween()
	tween.tween_interval(.55)
	tween.tween_callback(func():poof(body.global_position+Vector3.UP*.3))
	tween.tween_property(body,"scale",Vector3.ONE*.01,.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(body.queue_free)

## Soft white puff where a knocked-out enemy disappears.
func poof(pos:Vector3):
	for i in range(3):
		var ball=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=.14;mesh.height=.28;mesh.radial_segments=10;mesh.rings=5;ball.mesh=mesh
		var mat=StandardMaterial3D.new();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color=Color(.96,.95,.9,.8);ball.material_override=mat;ball.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arena.add_child(ball);var offset=Vector3(cos(i*2.1),.1*i,sin(i*2.1))*.14;ball.global_position=pos+offset
		var tween=ball.create_tween().set_parallel()
		tween.tween_property(ball,"scale",Vector3.ONE*(1.8+i*.3),.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(ball,"global_position",pos+offset*2.2+Vector3.UP*.25,.35).set_ease(Tween.EASE_OUT)
		tween.tween_property(mat,"albedo_color:a",0.0,.35)
		tween.chain().tween_callback(ball.queue_free)

func drone_death_explosion(pos:Vector3):
	var radius=Balance.CONFIG.combat.drone_death_radius
	arena.burst(pos+Vector3.UP*.35,Color("e78331"),radius)
	Game.sound("boom",arena)
	for target in arena.room.actors.duplicate():
		if is_instance_valid(target) and not target.dead and (target.player_owned or target.allied) and arena.flat_distance(pos,target.position)<=radius:
			target.take_damage(Balance.CONFIG.combat.drone_death_damage,Vector3.ZERO,"","blast")

func pressure_flash(pos:Vector3):
	var icon=Sprite3D.new();icon.name="PressureFlash"
	icon.texture=preload("res://assets/icons/v09/pressure.png")
	icon.pixel_size=.256/float(icon.texture.get_width());icon.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	icon.no_depth_test=true;icon.modulate=Color(1,1,1,.85)
	arena.add_child(icon);icon.position=pos+Vector3.UP*.2
	var tween=arena.create_tween()
	tween.tween_interval(.035)
	tween.tween_property(icon,"modulate:a",0.0,.125)
	tween.tween_callback(icon.queue_free)

func explosion(pos: Vector3,amount: float):
	var feel=arena.get_node_or_null("CombatFeel")
	if feel:feel.shake(clampf(.18+amount*.06,.18,.6))
	arena.burst(pos+Vector3.UP*.3,Color("e78331"),1.45)
	Game.sound("explosion_heavy",arena)
	for actor in arena.room.actors.duplicate():
		if is_instance_valid(actor) and not actor.dead and arena.flat_distance(pos,actor.position)<1.45: actor.take_damage(amount,actor.position-pos+Vector3(.01,0,.01),"","blast")
	for cell in arena.room.walls.keys():
		if arena.flat_distance(pos,arena.world_pos(cell))<1.5: arena.damage_wall(cell,amount)
	if not arena.room.boss_room and arena.flat_distance(pos,arena.world_pos(arena.room.base_cell))<1.5: damage_base(amount)
	for wreck in arena.room.wrecks.duplicate():
		if is_instance_valid(wreck) and not wreck.spent and arena.flat_distance(pos,wreck.position)<1.5: wreck.explode()

func resolve_interception(a, b):
	if a.spent or b.spent or a.friendly==b.friendly:return
	var friendly=a if a.friendly else b
	var hostile=b if a.friendly else a
	var chance=friendly.pressure/(friendly.pressure+hostile.pressure)
	var pierced=arena.run.combat_rng.randf()<chance
	arena.burst((a.position+b.position)*.5,Color("e8ce86"),.11)
	Game.sound("pressure" if pierced and friendly.player_shot else "ricochet",arena)
	if pierced:
		pressure_flash((a.position+b.position)*.5)
		hostile.consume()
	else:friendly.consume()

func spawn_free_bullet(actor,travel: Vector3,damage: float,speed: float,orb: bool):
	if not orb:Game.weapon_sound(actor)
	var bullet=load("res://scenes/projectile.tscn").instantiate()
	bullet.arena=arena;bullet.owner_actor=actor;bullet.friendly=false;bullet.damage=damage
	bullet.travel_direction=travel.normalized();bullet.speed=speed;bullet.orb=orb;bullet.lifetime=4.5
	bullet.position=actor.position+travel.normalized()*(actor.footprint*.55 if actor.kind=="boss" else .45)+Vector3.UP*.55
	arena.add_child(bullet);arena.room.projectiles.append(bullet)
	return bullet

func throw_grenade(actor,target: Vector3):
	Game.weapon_sound(actor)
	var grenade=load("res://scenes/grenade.tscn").instantiate()
	grenade.arena=arena;grenade.friendly=actor.allied or actor.player_owned;grenade.source=str(actor.kind)
	grenade.damage=Game.turret_damage() if actor.allied else actor.damage;grenade.target=Vector3(target.x,0,target.z)
	grenade.position=actor.position+Vector3.UP*(1.4 if actor.allied else .9)
	# The mortar lobs from its muzzle (the model is raised to the shot angle by then).
	if is_instance_valid(actor.model) and actor.model.has_method("muzzle_point"):grenade.position=actor.model.muzzle_point()
	grenade.flight_time=1.6 if actor.allied else (3.0 if actor.kind=="mortar" else 2.0)
	arena.add_child(grenade);arena.room.grenades.append(grenade)

func grenade_explosion(pos: Vector3,amount: float,friendly: bool,blast_radius: float=0.0):
	if friendly:
		for cell in arena.room.generators.keys():
			if arena.flat_distance(pos,arena.world_pos(cell))<=maxf(1.15,blast_radius):arena.damage_generator(cell,amount)
	GrenadeVisual.explode(arena,pos,blast_radius if blast_radius>0 else 1.15,friendly)
	Game.sound("boom",arena)
	for actor in arena.room.actors.duplicate():
		if is_instance_valid(actor) and not actor.dead and (actor.player_owned or actor.allied)!=friendly and (arena.flat_distance(pos,actor.position)<=blast_radius if blast_radius>0 else ((absf(pos.x-actor.position.x)<=1.25 and absf(pos.z-actor.position.z)<=1.25) if friendly else arena.flat_distance(pos,actor.position)<1.15)):
			actor.take_damage(amount,actor.position-pos+Vector3(.01,0,.01),"","blast")
	for cell in arena.room.walls.keys():
		if arena.flat_distance(pos,arena.world_pos(cell))<1.15:arena.damage_wall(cell,amount)
	if not friendly and not arena.room.boss_room and arena.flat_distance(pos,arena.world_pos(arena.room.base_cell))<1.15:damage_base(amount)
	for wreck in arena.room.wrecks.duplicate():
		if is_instance_valid(wreck) and not wreck.spent and arena.flat_distance(pos,wreck.position)<1.15:wreck.take_damage(amount)

## Bullets keep flying through enemies while they pierce by weapon or have run pierce charges left.
func pierce_on(bullet)->bool:
	if bullet.piercing:return true
	if CombatMods.player_bullet(bullet) and bullet.pierce_left>0:bullet.pierce_left-=1;return true
	return false
func current_intercept() -> float:
	var pressure=player_pressure();return pressure/(pressure+1.0)
func player_pressure()->float:
	var actor=arena.room.player
	var probability=CombatStats.probability(arena,actor.kind if is_instance_valid(actor) else "soldier",arena.run.weapon,actor.vehicle_origin if is_instance_valid(actor) else "owned")
	return probability/(1-probability)

func fire_weapon(actor):
	var weapon_id=arena.run.weapon;var data=arena.LOOT.WEAPONS[weapon_id]
	volley(actor,data)
	# Bursts (SMG): the rest of the pull follows on pausable timers in the facing of that moment.
	for k in range(1,int(data.get("burst",1))):
		arena.get_tree().create_timer(float(data.get("burst_gap",.07))*k,false).timeout.connect(func():
			if is_instance_valid(actor) and not actor.dead and arena.phase=="combat" and arena.run.weapon==weapon_id:
				volley(actor,data);Game.weapon_sound(actor))
func volley(actor,data:Dictionary):
	var multiplier=arena.effects.modify("shot_damage",1.0,{"actor":actor})
	arena.effects.emit("shot",{"actor":actor})
	for i in range(data.pellets):
		var bullet=spawn_bullet(actor,actor.position,actor.facing,actor.damage*multiplier,true)
		var spread=(i-(data.pellets-1)*.5)*.10
		bullet.travel_direction=bullet.travel_direction.rotated(Vector3.UP,spread);bullet.rotation.y=atan2(-bullet.travel_direction.x,-bullet.travel_direction.z)
		bullet.speed=data.speed;bullet.lifetime=data.range*arena.run.range_multiplier/data.speed;bullet.piercing=data.pierce;bullet.rocket_radius=data.blast
		if data.blast>0:bullet.scale=Vector3(2,2,2)
func rocket_impact(bullet):
	if not bullet.friendly and not arena.room.boss_room and arena.flat_distance(bullet.position,arena.world_pos(arena.room.base_cell))<=bullet.rocket_radius:damage_base(bullet.damage)
	arena.burst(bullet.position,Color("e8b957"),bullet.rocket_radius);Game.sound("boom",arena)
	for enemy in arena.room.actors.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and (enemy.player_owned or enemy.allied)!=bullet.friendly and enemy!=bullet.owner_actor and arena.flat_distance(bullet.position,enemy.position)<=bullet.rocket_radius:
			enemy.take_damage(enemy.max_hp if bullet.star_power else bullet.damage,Vector3.ZERO,bullet.vehicle_credit,"blast")
	for cell in arena.room.walls.keys():
		if arena.flat_distance(bullet.position,arena.world_pos(cell))<=bullet.rocket_radius:
			if bullet.star_power:arena.room.walls[cell].node.queue_free();arena.room.walls.erase(cell);arena.navigation.invalidate(cell)
			else:arena.damage_wall(cell,bullet.damage)

## Captured hull: beacon, pointer and one short hint while the soldier is on foot.
const TROPHY_HINTS={"buggy":"Трофейный багги: подойди и займи","apc":"Трофейный БТР: подойди и займи","tank":"Трофейный танк: подойди и займи"}
func mark_trophy(wreck):
	var beacon=preload("res://scripts/capture_beacon.gd").new();beacon.wreck=wreck;wreck.add_child(beacon)
	var player=arena.room.player
	if is_instance_valid(player) and player.kind=="soldier":
		arena.toast(TROPHY_HINTS.get(wreck.kind,"Трофей: подойди и займи"));Game.sound("quest_ready",wreck)


## Enemy crews bail out of a knocked-out vehicle: pistol dogs with 1 HP. The first one is the mechanic: he stays
## by the wreck and repairs it (Wreck.REPAIR_TIME) unless he is shot or the hero takes the wreck first.
const CREW={"buggy":[0,1],"apc":[1,2],"tank":[2,2]}
func bail_out(actor,wreck):
	if arena.room.boss_room:return
	var span:Array=CREW.get(actor.kind,[0,0]);var rng=arena.run.combat_rng if arena.run!=null else RandomNumberGenerator.new()
	var count=rng.randi_range(span[0],span[1])
	if actor.kind=="buggy" and rng.randf()<.5:count=1
	for i in range(count):
		var cell=arena.find_free_near(actor.cell)
		var dog=arena.spawn_actor("soldier",cell,false,false,actor.rank,false,"pistol")
		dog.hp=1.0;dog.max_hp=1.0;dog.refresh_health();dog.set_meta("crew",true)
		if i==0:dog.set_meta("mechanic",true);dog.movement_pause=REPAIR_HOLD;wreck.mechanic=dog
	if count>0:Game.sound("enemy_surprise",wreck)
## The mechanic stays put while repairing (no walking away from the wreck).
const REPAIR_HOLD=4.5
