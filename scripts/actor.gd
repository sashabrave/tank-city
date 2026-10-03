class_name CombatActor
extends Node3D

@export var kind = "soldier"
var arena
var enemy_weapon=""
var volley_hits:Array=[]
var pending_shots=0
var burst_delay=0.0
var burst_direction=Vector2i.UP
var rocket_charge=0.0
var rocket_target=Vector3.ZERO
var wave_slot=-1
var rank=1
## Chevrons next to the HP bar (1–3): how professional the enemy is in this part of the world
## (Professionalism.tier). Display only; stat ranks stay in `rank`.
var chevrons=0
var strength_scale=1.0
var flight_target=Vector3.ZERO
var flight_state="choose"
var flight_timer=0.0
var flight_shots=0
var flight_aim=Vector3.ZERO
var companion=false
var companion_weapon="pistol"
var companion_factor=.5
var parachute_left=0.0
var parachute:Node3D
var force_field:MeshInstance3D
var stun_time=0.0
## Cryo ammo: share of speed lost while slow_time runs.
var slow_time=0.0
var slow_factor=0.0
## Gas sleep (catnip cloud): works like a stun, reads as «Z z z» instead of stars.
var sleep_time=0.0
var shield_phase="ready"
var shield_time=.7
var shield_visual: Node3D
var shield_rest=Basis.IDENTITY
var route_points: Array = []
var footprint=1
var flank=-1
var turret_pivot: Node3D
var turret_yaw=PI
var artillery_timer=10.0
var laser_timer=18.0
var radial_timer=6.0
var radial_charge=0.0
var warning_ring: Node3D
var attack_label: Label3D
var player_owned = false
var allied = false
var hp = 2.0
var max_hp = 2.0
var cell = Vector2i.ZERO
var destination = Vector2i.ZERO
var quarter_destination=Vector3.ZERO
var terrain_direction=Vector2i.ZERO
var terrain_sliding=false
var slide_remaining=0.0
var facing = Vector2i.UP
var moving = false
var turn_left = 0.0
var fire_cooldown = 0.0
var brain_cooldown = 0.0
var burst_steps = 0.0
var burst_index = 0
var movement_pause = 0.0
## Professionalism (scripts/combat/professionalism.gd), fixed per room at spawn: seconds from lining up to the
## first shot, and the multiplier of rests between dashes. Allies keep 0 / 1.
var aim_delay_time=0.0
var pause_scale=1.0
var aim_hold=0.0
var aim_glint:MeshInstance3D
var invulnerable = 0.0
var dead = false
var elite=false # Marks every room commander for existing combat AI.
var commander_elite=false
var commander_support=false
var elite_timer=5.0
var elite_charge=0.0
var elite_star: Label3D
var speed = 2.6
var fire_interval = .65
var damage = 1.0
var model: Node3D
var health_label: Sprite3D
var turn_from = 0.0
var turn_to = 0.0
var sniper_charge=0.0
var sniper_target=Vector3.ZERO
var sniper_line: Node3D
var surprise_spawn=false
var assault_time=0.0
var attention_timer=0.0
var idle_progress_time=0.0
var deepest_row=0
var trench_return_delay=0.0
var trench_time=0.0
var hidden_in_trench=false
var burn_time=0.0
var burn_dps=0.0
var burn_tick=0.0
var occupying_trench=false
var salvaged=false
var vehicle_origin="owned"
var vehicle_zone=1
var killed_by_vehicle=""
var resource_blast=Vector3.ZERO

func _ready():
	attention_timer=(arena.room.surprise_rng if surprise_spawn else arena.combat_rng).randf_range(12,22);deepest_row=cell.y
	add_child(load("res://scripts/actor_audio.gd").new())
	if enemy_weapon.is_empty():enemy_weapon=EnemyLoadouts.default_for(kind)
	var tuning=Balance.CONFIG.enemy(kind)
	var stats=[tuning.health,tuning.move_speed,tuning.fire_interval,tuning.damage]
	max_hp = stats[0]
	hp = max_hp
	speed = stats[1]
	fire_interval = stats[2]
	damage = stats[3]
	if not player_owned and not allied:damage=tuning.enemy_damage
	if not player_owned and not allied:fire_interval=tuning.enemy_interval
	if not player_owned and not allied and rank>=2:
		max_hp*=(2.1 if rank==3 else Balance.CONFIG.combat.rank_health);hp=max_hp;damage*=(1.55 if rank==3 else Balance.CONFIG.combat.rank_damage)
	if not player_owned and not allied:
		strength_scale=Campaign.hp_scale(arena.room_index) if kind!="boss" else 1.0
		max_hp*=strength_scale;hp=max_hp;damage*=Campaign.damage_scale(arena.room_index) if kind!="boss" else 1.0
	if kind=="boss":
		max_hp=Campaign.boss_health()*BossCatalog.encounter(arena.run_seed,arena.room_index).hp;hp=max_hp
		speed=BossCatalog.encounter(arena.run_seed,arena.room_index).speed
		if arena.twin_boss:fire_interval=3.5;radial_timer=9.0+arena.actors.size()*4
	if kind=="mortar":
		fire_interval=Balance.CONFIG.combat.allied_turret_interval if allied else tuning.enemy_interval
		fire_cooldown=1.0 if allied else 4.0
	if player_owned:
		speed=tuning.player_speed
		if kind == "soldier":
			max_hp = arena.soldier_max_hp
			hp = arena.soldier_hp
			speed = Balance.CONFIG.combat.hero_speed
			fire_interval = .6
		damage += (Game.meta_damage() + arena.damage_bonus)*(.25 if kind=="buggy" else 1.0)
		fire_interval *= arena.fire_multiplier
		speed *= arena.speed_multiplier
	if player_owned and kind in arena.vehicle_mods:
		var mods=arena.vehicle_mods[kind];max_hp+=mods.hp;hp=max_hp;damage+=mods.damage;speed*=mods.speed
	if player_owned and kind!="soldier" and Game.selected_class in ["driver","engineer"]:max_hp*=1.15+Game.class_specialization()*.01;hp=max_hp;damage*=1.1+Game.class_specialization()*.01
	if player_owned and kind in GarageCatalog.VEHICLES:
		var vehicle_stats=GarageCatalog.stats(kind,arena,vehicle_origin,vehicle_zone)
		max_hp=vehicle_stats.hp;hp=max_hp;damage=vehicle_stats.damage;fire_interval=vehicle_stats.interval;speed=vehicle_stats.speed
	if player_owned:speed=minf(speed,Balance.speed_cap())
	model = Visuals.model(BossCatalog.encounter(arena.run_seed,arena.room_index).model if kind=="boss" else EnemyLoadouts.model_for(kind,enemy_weapon),self,Vector3.ZERO,"cat" if player_owned or allied else "dog",player_owned)
	if player_owned or UnitKinds.is_vehicle(kind):preload("res://scripts/world_lighting.gd").headlights(model,kind!="soldier")
	if kind=="shield":
		shield_visual=Visuals.named_part(model,"shield_panel_pivot");shield_rest=shield_visual.basis
		shield_visual.basis=shield_rest*Basis(Vector3.RIGHT,.5)
	if UnitKinds.is_infantry(kind):Visuals.equip_model(model,enemy_weapon)
	if kind=="flyer":model.position.y=1.25
	if kind=="boss":
		model.scale=Vector3.ONE*BossCatalog.encounter(arena.run_seed,arena.room_index).scale
		var bounds=Visuals.mesh_bounds(model,Transform3D.IDENTITY)
		model.scale*=float(footprint-.25)/maxf(bounds.size.x,bounds.size.z)
		turret_pivot=Visuals.named_part(model,"boss_main_yaw")
		if arena.boss_room:
			var reach=maxf(1.3,footprint*.58)
			force_field=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=reach;sphere.height=reach*2;force_field.mesh=sphere;force_field.position.y=reach*.65;force_field.visible=false
			var material=StandardMaterial3D.new();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color=Color(.3,.8,1,.16);material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;force_field.material_override=material;add_child(force_field)
		warning_ring=Visuals.ring(self,Color("f8ac48"),2.15);warning_ring.visible=false
		attack_label=Visuals.label3d(self,"Круговой залп",Vector3(0,3.6,0),Color("ffd180"),34);attack_label.visible=false
	if not player_owned and not allied:
		movement_pause=(arena.room.surprise_rng if surprise_spawn else arena.combat_rng).randf_range(.2,.9)
		Visuals.recolor_enemy(model,rank)
		facing = Vector2i.DOWN
	else:
		Visuals.ring(self,Color("f8b542"),.45 if kind == "soldier" else .58)
	model.rotation.y = angle_for(facing)
	health_label=load("res://scripts/health_bar_3d.gd").new();add_child(health_label)
	health_label.position=Vector3(0,{"boss":1.3,"tank":.82,"apc":.81,"buggy":.81,"drone":.67,"soldier":1.14,"shield":1.14,"sniper":1.14,"grenadier":1.14}.get(kind,1.5),0)
	if kind=="flyer":health_label.position.y=2.25
	if not player_owned and not allied:health_label.rank=maxi(chevrons,rank)
	if kind=="drone":health_label.pixel_size=.006

	if player_owned and kind=="soldier":apply_weapon()
	refresh_health()

func refresh_health():
	if health_label:health_label.set_health(hp,max_hp)

func angle_for(dir: Vector2i) -> float:
	return atan2(-float(dir.x),-float(dir.y))

func set_facing(dir: Vector2i):
	if kind=="shield" and shield_phase=="active":return
	if dir == Vector2i.ZERO or dir == facing: return
	facing = dir
	turn_from = model.rotation.y
	turn_to = angle_for(dir)
	turn_left = .105

func _physics_process(delta):
	if dead or not is_instance_valid(arena):return
	if arena.phase!="combat" and not (player_owned and arena.phase=="countdown"):return
	if is_instance_valid(force_field):force_field.visible=arena.boss.shield_active()
	stun_time=maxf(0,stun_time-delta)
	slow_time=maxf(0,slow_time-delta)
	if slow_time<=0:slow_factor=0.0
	sleep_time=maxf(0,sleep_time-delta)
	if not player_owned and not allied:CombatMods.tick_burn(self,delta)
	if dead:return
	if not player_owned and not allied and (stun_time>0 or arena.freeze_time>0):return
	if player_owned and not has_meta("stage_hidden"):
		model.visible=arena.abilities.cloak_time<=0 or fmod(arena.abilities.cloak_time,.25)<.15
	if not player_owned and not allied:
		arena.enemy.attention_tick(self,delta)
		EnemyLoadouts.tick(self,delta)
	if companion:arena.comrade_step(self,delta);return
	if kind=="flyer":
		if allied:arena.allied_flyer_step(self,delta)
		else:arena.flyer_step(self,delta)
		return
	if not player_owned and kind=="soldier" and trench_return_delay<=0 and arena.trenches.has(cell):
		if not occupying_trench and not arena.board.occupy_trench(self,cell):return
		trench_time=fmod(trench_time+delta,5.0)
		hidden_in_trench=trench_time<1.8
		model.position.y=-.85 if hidden_in_trench else -.42
		health_label.visible=not hidden_in_trench
		if hidden_in_trench:return
		fire_cooldown=maxf(0,fire_cooldown-delta)
		var aim=arena.enemy_aim(self)
		if aim!=Vector2i.ZERO and trench_time>2.6 and trench_time<3.6:
			facing=aim;model.rotation.y=angle_for(aim);shoot()
		return
	if kind=="sniper":
		arena.sniper_step(self,delta);return
	if elite:arena.elite_step(self,delta)
	if kind=="shield":update_shield(delta)
	if player_owned and kind=="soldier":speed=minf(Balance.speed_cap(),CombatStats.soldier_speed(arena.run)*arena.effects.modify("move_speed",1.0))
	fire_cooldown = maxf(0,fire_cooldown-delta)
	if enemy_weapon=="rpg" and not player_owned and arena.enemy.rpg_step(self,delta):return
	movement_pause=maxf(0,movement_pause-delta)
	invulnerable = maxf(0,invulnerable-delta)
	# While BattleStage hides the soldier (before the hop-out, after boarding) visibility is left alone.
	if player_owned and not has_meta("stage_hidden"):
		model.visible=arena.star_time<=0 or fmod(arena.elapsed,.18)<.12
		for mesh in model.find_children("*","GeometryInstance3D",true,false):mesh.transparency=.65 if arena.abilities.cloak_time>0 else 0.0
	if turn_left > 0:
		turn_left = maxf(0,turn_left-delta)
		model.rotation.y = lerp_angle(turn_from,turn_to,1.0-turn_left/.105)
		if turn_left == 0: model.rotation.y = turn_to
	if not moving:arena.terrain.begin_slide(self)
	if moving:
		var target=quarter_destination if uses_quarter_steps() or terrain_sliding else arena.actor_world_pos(self,destination)
		var next_position=position.move_toward(target,(minf(speed,Balance.speed_cap()) if player_owned else speed*(1.0-slow_factor))*arena.terrain.speed_factor(self)*delta)
		if arena.can_stand(next_position,self):position=next_position
		else:moving=false
		if position.distance_to(quarter_destination if uses_quarter_steps() or terrain_sliding else arena.actor_world_pos(self,destination)) < .005:
			cell = destination
			moving = false;terrain_sliding=false
			if not player_owned and kind not in ["drone","buggy","mortar"]:
				burst_steps+=.25 if uses_quarter_steps() else 1.0
				var steps=2 if kind in ["apc","grenadier"] or (kind=="soldier" and burst_index%2==1) else 1
				if burst_steps>=steps and assault_time<=0:
					burst_steps=0;burst_index+=1
					movement_pause={"soldier":.8,"apc":1.15,"tank":1.5,"boss":1.8,"drone":.65,"grenadier":1.1,"shield":1.0}.get(kind,1.0)*.8*pause_scale+arena.combat_rng.randf_range(0,.2)
		if kind == "soldier": model.position.y = absf(sin(Time.get_ticks_msec()*.016))*.015
	else: model.position.y = 0
	if not moving:arena.terrain.begin_slide(self)
	health_label.visible=player_owned or not arena.nets.has(arena.grid_pos(position))
	if kind=="mortar":
		arena.mortar_step(self)
		return
	if not player_owned and arena.abilities.cloak_time<=0 and kind=="grenadier" and enemy_weapon!="rpg" and fire_cooldown<=0 and is_instance_valid(arena.player):
		if arena.flat_distance(position,arena.player.position)<=8:
			arena.throw_grenade(self,arena.world_pos(arena.base_cell) if assault_time>0 and arena.flat_distance(position,arena.world_pos(arena.base_cell))<=8 else arena.player.position);model.kick();fire_cooldown=fire_interval
	if not player_owned and kind=="drone":
		arena.drone_step(self)
		return
	if get_meta("generator_guard",false):
		if arena.abilities.cloak_time<=0 and is_instance_valid(arena.player) and arena.flat_distance(position,arena.player.position)<8 and fire_cooldown<=0 and arena.clear_shot(position,arena.player.position,.5):
			var aim=(arena.player.position-position).normalized();aim.y=0
			model.aim(atan2(-aim.x,-aim.z));arena.spawn_free_bullet(self,aim,damage,6,false);fire_cooldown=2.2
		return
	if not player_owned and kind=="boss" and arena.boss_room:
		arena.boss_step(self,delta)
		return
	if not player_owned and kind=="buggy":
		var aim=arena.enemy_aim(self)
		track_aim(aim,delta)
		if aim!=Vector2i.ZERO:
			set_facing(aim)
			if aimed_shot() and aim==Vector2i.DOWN and cell.x==arena.base_cell.x:fire_cooldown=2.4
		elif not moving:
			brain_cooldown-=delta
			if brain_cooldown>0:return
			brain_cooldown=.16
			var dir=arena.path_direction(self);set_facing(dir)
			if turn_left==0:try_move(dir)
		return
	# T-152: no control while the room intro plays (HQ drive-in, hop-out, run to the start cell).
	if player_owned and arena.get_meta("intro_lock",false):return
	if player_owned:
		if occupying_trench:
			var aim=Game.direction()
			if aim!=Vector2i.ZERO:set_facing(aim)
			if Input.is_action_just_pressed("hide_trench"):hidden_in_trench=not hidden_in_trench
			model.position.y=-.85 if hidden_in_trench else -.42
			if Game.wants_fire() and not hidden_in_trench and arena.phase in ["combat","countdown"]:shoot()
			if Game.wants_interact():arena.interact()
			return
		var dir = Game.direction()
		if dir != Vector2i.ZERO:
			set_facing(dir)
			# Finish only the current quarter-step; turning never stalls locomotion.
			if not moving:try_move(dir)
		if Game.wants_fire() and arena.phase in ["combat","countdown"]: shoot()
		if Game.wants_interact(): arena.interact()
	else:
		var lined_up=arena.enemy_aim(self)
		track_aim(lined_up,delta)
		brain_cooldown -= delta
		if not moving and brain_cooldown <= 0:
			brain_cooldown = .04 if uses_quarter_steps() else .16
			var aim = lined_up
			if aim != Vector2i.ZERO:
				set_facing(aim)
				aimed_shot()
			else:
				var dir = arena.path_direction(self)
				set_facing(dir)
				if turn_left == 0: try_move(dir)
		if turn_left == 0 and lined_up == facing: aimed_shot()

## Professionalism: time spent lined up on a target. It drains fast when the line breaks, so a hero who
## steps out of the line gets a fresh aim delay; a glint at the muzzle telegraphs the shot.
func track_aim(aim:Vector2i,delta:float):
	if aim!=Vector2i.ZERO:aim_hold+=delta
	else:aim_hold=maxf(0,aim_hold-delta*3.0)
	var aiming=aim_delay_time>0 and aim!=Vector2i.ZERO and aim_hold<aim_delay_time
	if aiming and not is_instance_valid(aim_glint):
		aim_glint=MeshInstance3D.new();aim_glint.name="AimGlint";var ball=SphereMesh.new();ball.radius=.07;ball.height=.14;ball.radial_segments=8;ball.rings=4;aim_glint.mesh=ball
		aim_glint.material_override=Visuals.material(Color("ffe39a"),true);aim_glint.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(aim_glint)
	if is_instance_valid(aim_glint):
		aim_glint.visible=aiming
		if aiming:
			var t=aim_hold/aim_delay_time
			aim_glint.position=Vector3(facing.x,0,facing.y)*.38*footprint+Vector3.UP*(.55 if uses_quarter_steps() else .45)
			aim_glint.scale=Vector3.ONE*(.4+t*1.1)
func aimed_shot()->bool:
	if aim_hold<aim_delay_time:return false
	return shoot()

func uses_quarter_steps()->bool:
	return player_owned or UnitKinds.is_infantry(kind)

func try_move(dir: Vector2i):
	if kind=="mortar" or dir == Vector2i.ZERO or moving or (not player_owned and kind not in ["drone","buggy"] and movement_pause>0): return
	if uses_quarter_steps():
		var next_position=position+Vector3(dir.x,0,dir.y)*.25
		next_position.x=snappedf(next_position.x,.25);next_position.z=snappedf(next_position.z,.25)
		if arena.can_stand(next_position,self):
			quarter_destination=next_position;destination=arena.grid_pos(next_position);moving=true;terrain_direction=dir;terrain_sliding=false
		return
	var next = cell+dir
	if arena.can_enter(next,self):
		destination = next
		moving = true;terrain_direction=dir;terrain_sliding=false

func shoot() -> bool:
	if (kind=="shield" and shield_phase in ["raising","active"]) or kind in ["grenadier","mortar"] or turn_left > 0 or fire_cooldown > 0 or dead: return false
	if player_owned and not allied and arena.challenges.weapons_locked():
		fire_cooldown=.6
		if arena.toast_time<=0:arena.toast("Патроны кончились")
		return false
	fire_cooldown = fire_interval/(arena.effects.modify("fire_rate",1.0) if player_owned and kind=="soldier" else 1.0)
	if not player_owned and not allied and kind in ["soldier","shield"]:EnemyLoadouts.begin(self)
	elif player_owned and kind=="soldier":arena.fire_weapon(self)
	elif kind=="boss":
		var perpendicular=Vector3(-facing.y,0,facing.x)
		for offset in [-1.2,0.0,1.2]:arena.spawn_bullet(self,position+perpendicular*offset,facing,damage,player_owned)
	else:arena.spawn_bullet(self,position,facing,damage,player_owned)
	if player_owned and kind!="soldier" and arena.run!=null:arena.effects.emit("vehicle_shot",{"actor":self})
	if model.has_method("kick"):model.kick()

	return true

func take_damage(amount: float,blast:Vector3=Vector3.ZERO,vehicle_credit:String="",source:String=""):
	resource_blast=blast
	if kind=="boss" and not arena.room.generator_order.is_empty():
		amount=arena.boss.limit_damage(self,amount)
		if amount<=0:return
	if dead or invulnerable > 0 or hidden_in_trench or (player_owned and arena.star_time>0): return
	if player_owned and arena.abilities.cloak_time>0 and arena.abilities.cloak_ghost:return
	if player_owned and arena.abilities.block_hit():arena.burst(position,Color("86daec"),.5);Game.sound("shield_hit",self);return
	if player_owned and occupying_trench:amount*=.5
	if player_owned and source!="" and arena.run!=null:
		amount=CombatMods.incoming(arena,amount,source)
		if amount<0:
			arena.burst(position+Vector3.UP*.5,Color("d9f2ff"),.3);invulnerable=.25;return
	if player_owned and arena.run!=null and amount>0:amount=arena.effects.modify("incoming_damage",amount,{"actor":self})
	# Legendary «Второе дыхание»: once per field a lethal hit leaves 1 HP.
	if player_owned and kind=="soldier" and arena.run!=null and hp-amount<=0 and arena.effects.modify("second_wind",0.0,{"actor":self})>0:
		arena.burst(position+Vector3.UP*.5,Color("ffd27a"),.8);Game.sound("shield_restore",self);arena.toast("Второе дыхание")
		hp=1.0;arena.soldier_hp=hp;invulnerable=2.0;refresh_health();return
	if player_owned and kind=="soldier" and arena.run!=null and not arena.run.mercy_used and hp>1.0 and hp-amount<=0 and not arena.sandbox:
		# Once per run a lethal hit leaves 1 HP and a moment to escape.
		arena.run.mercy_used=true;amount=hp-1.0;arena.run.damage_taken+=amount
		arena.burst(position+Vector3.UP*.5,Color("fff2c4"),.7);Game.sound("shield_restore",self)
		arena.toast("На волоске! Второго шанса в этой вылазке не будет")
		arena.floating_number(position,-amount);hp=1.0;arena.soldier_hp=hp;invulnerable=1.6;refresh_health()
		preload("res://scripts/status_fx.gd").of(self).hit()
		arena.effects.emit("player_damaged",{"actor":self,"amount":amount})
		var feel=arena.get_node_or_null("CombatFeel")
		if feel:feel.shake(.3);feel.hit_stop(.04)
		return
	if not player_owned and arena.get("reward")!=null:amount=arena.reward.thieves.incoming(self,amount)
	arena.floating_number(position,-minf(hp,amount))
	if amount>0:preload("res://scripts/status_fx.gd").of(self).hit()
	hp = maxf(0,hp-amount)
	if player_owned and amount>0:
		var by=str(arena.get_meta("attacker",""))
		arena.set_meta("hero_hit_by",by if by!="" else {"blast":"blast","melee":"zombie"}.get(source,"blast" if blast.length()>.01 else ""))
	if player_owned:
		if arena.run!=null:arena.run.damage_taken+=amount
		invulnerable = .65
		if kind == "soldier": arena.soldier_hp = maxf(0,hp)
		Game.sound("player_hurt",self)
		arena.effects.emit("player_damaged",{"actor":self,"amount":amount})
		var hit_feel=arena.get_node_or_null("CombatFeel")
		if hit_feel:hit_feel.shake(.3);hit_feel.hit_stop(.04)
	else:Game.sound("hit_body" if UnitKinds.is_infantry(kind) else "hit_metal",self)
	refresh_health()
	if hp>0 and is_instance_valid(model) and model.has_method("flinch"):model.flinch()
	arena.burst(position+Vector3.UP*.4,Color("ffbd61"),.3)
	if hp <= 0:
		killed_by_vehicle=vehicle_credit
		dead = true
		arena.actor_destroyed(self)

func apply_weapon():
	Visuals.equip_model(model,arena.weapon)
	var stats=CombatStats.weapon(arena)
	damage=stats.damage;fire_interval=stats.interval

func update_shield(delta: float):
	shield_time-=delta
	if shield_time>0:return
	match shield_phase:
		"ready":
			if is_instance_valid(arena.player) and arena.flat_distance(position,arena.player.position)<7:
				# T-054/T-055: turn to the soldier first, then plant the shield in front in one readable motion.
				var to=arena.player.position-position
				set_facing(Vector2i(signi(roundi(to.x)),0) if absf(to.x)>absf(to.z) else Vector2i(0,signi(roundi(to.z))))
				shield_phase="raising";shield_time=.55;shield_pose(Vector3(0,.0,-.12),shield_rest,.5)
		"raising":shield_phase="active";shield_time=1.1;shield_pose(Vector3(0,-.04,-.2),shield_rest,.12)
		"active":shield_phase="cooldown";shield_time=2.2;shield_pose(Vector3.ZERO,shield_rest*Basis(Vector3.RIGHT,.5),.35)
		"cooldown":shield_phase="ready";shield_time=0
## Smoothly moves the shield panel to a pose (offset from its rest position, rotation) instead of snapping.
var shield_origin=Vector3.INF
func shield_pose(offset:Vector3,basis:Basis,time:float):
	if not is_instance_valid(shield_visual):return
	if shield_origin==Vector3.INF:shield_origin=shield_visual.position
	var tween=shield_visual.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(shield_visual,"position",shield_origin+offset,time)
	tween.tween_property(shield_visual,"basis",basis,time)

func blocks_shot(travel: Vector3) -> bool:
	return kind=="shield" and shield_phase=="active" and travel.normalized().dot(Vector3(facing.x,0,facing.y))<-.7

func class_weapon_multiplier()->float:
	return CombatStats.class_weapon_multiplier(arena.weapon)
func pressure()->float:
	if companion:return arena.player_pressure()*companion_factor
	if player_owned:return arena.player_pressure()
	return Balance.CONFIG.enemy(kind).pressure*(1.4 if rank==3 else Balance.CONFIG.combat.rank_pressure if rank==2 else 1.0)
