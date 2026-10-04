class_name Gun
extends RefCounted
## One hero, one gun (step U1, 2026-10-04): the battle, the hub range and the rooms between fields shoot through
## this module. A mode only provides the floor — the «field» the shots fly over:
##   battle  — the Arena: real enemies, walls, generators (CombatSystem.bullet_hit/rocket_impact);
##   practice — the hub and the rooms (RoomCombat): training targets and their own wall test.
## A field exposes `projectiles`, `phase`, `facing`, `bullet_hit(bullet)`, `rocket_impact(bullet)`; a practice field
## also `gun_targets()` (nodes that take hits), `gun_target_hit(target, amount)`, `gun_blocked(pos)` (walls and props
## stop a round) and `gun_inside(pos)` (the floor a lobbed charge may fly over).
## Its run (arena with `run`) is the field itself in battle, `run_arena()` in a room and none in the hub.
const LOOT=preload("res://scripts/loot_catalog.gd")
const SPREAD:=.10            # radians between pellets
const LOB_WEAPON:="grenade_launcher"
const TARGET_REACH:=.4       # half-size of a training target's hit box
const PRACTICE_SEED:=4100    # visual-only randomness of practice fields

## The run behind a field: the battle arena itself, the room's run arena, or null in the hub.
static func run_of(field):
	if field==null:return null
	if field.has_method("run_arena"):return field.run_arena()
	return field if field.get("run")!=null else null
static func is_battle(field)->bool:return field!=null and run_of(field)==field
## The gun in hand: the run's weapon (crate gun, swap in the backpack), otherwise the hub loadout.
static func weapon_id(field)->String:
	var run_arena=run_of(field)
	var id=str(run_arena.run.weapon) if run_arena!=null else Game.selected_weapon
	return id if id in LOOT.WEAPONS else "pistol"

## Everything the gun does, by ONE formula: CombatStats.weapon (class multiplier, meta upgrades, run cards and the
## rolled crate stats when a run exists) plus the catalog's ballistics. `run_arena` null = the hub loadout.
static func stats(run_arena=null,id:="")->Dictionary:
	if id=="":id=Game.selected_weapon if run_arena==null else str(run_arena.run.weapon)
	var data:Dictionary=LOOT.WEAPONS[id]
	var result:Dictionary=CombatStats.weapon(run_arena,id).duplicate()
	result.merge({"id":id,"pellets":int(data.pellets),"burst":int(data.get("burst",1)),"burst_gap":float(data.get("burst_gap",.07)),
		"speed":float(data.speed),"blast":float(data.blast),"pierce":bool(data.pierce),"lob":id==LOB_WEAPON},true)
	return result

## Practice pull of the trigger (hub, rooms): the shot plus the recoil; returns the cooldown till the next one.
static func trigger(field,shooter:Node3D)->float:
	var id=weapon_id(field)
	fire(field,shooter)
	if id!=LootCatalog.PAWS and not Ammo.dry(run_of(field).run if run_of(field)!=null else null):
		var model=model_of(shooter)
		if is_instance_valid(model) and model.has_method("kick"):model.kick()
	return float(stats(run_of(field),id).interval)

## One pull: the paws scratch, a dry gun hits with its butt, a gun fires a volley (bursts follow on pausable timers).
static func fire(field,shooter:Node3D):
	var battle=is_battle(field);var run_arena=run_of(field)
	var id=weapon_id(field);var data:Dictionary=LOOT.WEAPONS[id]
	# Empty hands (2026-10-03): Space scratches with the paws instead of a shot.
	if id==LootCatalog.PAWS:
		if battle:Melee.strike(field,shooter,shooter.damage*field.effects.modify("shot_damage",1.0,{"actor":shooter}),true)
		else:practice_strike(field,shooter,Melee.damage(run_arena),true)
		return
	# No rounds loaded (T-197): the gun hits with its butt; a reminder now and then.
	if run_arena!=null and Ammo.dry(run_arena.run):
		if battle:
			if field.toast_time<=0:field.toast(Texts.render("Нет боеприпасов — удар прикладом. Заряди в «Снаряжении»"))
			Melee.strike(field,shooter,Melee.damage(field)*Melee.BUTT,false)
		else:practice_strike(field,shooter,Melee.damage(run_arena)*Melee.BUTT,false)
		return
	volley(field,shooter,id)
	# Bursts (SMG): the rest of the pull follows on pausable timers in the facing of that moment.
	for k in range(1,int(data.get("burst",1))):
		field.get_tree().create_timer(float(data.get("burst_gap",.07))*k,false).timeout.connect(func():
			if is_instance_valid(field) and is_instance_valid(shooter) and shooter.get("dead")!=true and field.phase=="combat" and weapon_id(field)==id:
				volley(field,shooter,id)
				if battle:Game.weapon_sound(shooter)
				else:Game.fire_sound(id,shooter))

## One volley: every pellet with its spread, speed, range, pierce and blast; the grenade launcher lobs.
static func volley(field,shooter:Node3D,id:String):
	var data:Dictionary=LOOT.WEAPONS[id];var battle=is_battle(field);var run_arena=run_of(field)
	var damage:float
	var facing:Vector2i=aim(field,shooter)
	if battle:
		var multiplier=field.effects.modify("shot_damage",1.0,{"actor":shooter})
		field.effects.emit("shot",{"actor":shooter})
		damage=shooter.damage*multiplier
	else:damage=float(stats(run_arena,id).damage)
	for i in range(data.pellets):
		var bullet=field.spawn_bullet(shooter,shooter.position,facing,damage,true) if battle else practice_bullet(field,shooter,facing,damage,id)
		var spread=(i-(data.pellets-1)*.5)*SPREAD
		bullet.travel_direction=bullet.travel_direction.rotated(Vector3.UP,spread);bullet.rotation.y=atan2(-bullet.travel_direction.x,-bullet.travel_direction.z)
		bullet.speed=data.speed;bullet.lifetime=data.range*(run_arena.run.range_multiplier if run_arena!=null else 1.0)/data.speed;bullet.piercing=data.pierce;bullet.rocket_radius=data.blast
		if data.blast>0:bullet.scale=Vector3(2,2,2)
		if id==LOB_WEAPON:lob(field,shooter,bullet,data)

## Grenade launcher (T-268, author: «работает как РПГ»): the charge goes over cover in an arc and lands on the first
## target in the line of fire within range, otherwise at full range. The RPG keeps its straight rocket.
static func lob(field,shooter:Node3D,bullet,data:Dictionary):
	var run_arena=run_of(field)
	var reach=float(data.range)*(run_arena.run.range_multiplier if run_arena!=null else 1.0);var distance=reach
	for target in lob_targets(field):
		var offset=target.position-shooter.position;offset.y=0
		var along=offset.dot(bullet.travel_direction)
		if along>.5 and along<distance and (offset-bullet.travel_direction*along).length()<.6:distance=along
	bullet.lobbed=true;bullet.lob_ground=bullet.position.y;bullet.lifetime=distance/bullet.speed
static func lob_targets(field)->Array:
	if is_battle(field):
		return field.room.actors.filter(func(enemy):return is_instance_valid(enemy) and not enemy.dead and not enemy.player_owned and not enemy.allied)
	return field.gun_targets()
## Where a lobbed charge may still fly: inside the battle grid, inside a practice field's floor (`gun_inside`).
static func on_field(field,pos:Vector3)->bool:
	if field.has_method("gun_inside"):return field.gun_inside(pos)
	return not field.has_method("inside") or field.inside(field.grid_pos(pos))

## The facing of the shot: the actor's own in battle, the field's (hub, room walker) in practice.
static func aim(field,shooter)->Vector2i:
	return shooter.facing if shooter.get("facing") is Vector2i else field.facing
static func model_of(shooter)->Node3D:
	return shooter.model if shooter.get("model") is Node3D else shooter

## Loaded ammo extras of a charge's blast (T-114), shared by every field: cluster scatters bomblets around the
## landing spot, napalm leaves a burning patch. `rng` is the fight's in battle, a visual one in practice;
## `blast` is the field's small-explosion function (position, damage).
static func charge_effects(field,bullet,ammo:Dictionary,rng:RandomNumberGenerator,blast:Callable):
	var stats:Dictionary=ammo.stats;var at=bullet.position;at.y=0
	match str(ammo.type):
		"cluster":
			var count=int(stats.get("bomblets",3));var reach=1.6+(.6 if ammo.get("twist",false) else 0.0)
			for i in range(count):
				var angle=TAU*i/count+rng.randf_range(-.3,.3);var spot=at+Vector3(cos(angle),0,sin(angle))*rng.randf_range(.6,reach)
				var hit=bullet.damage*float(stats.get("bomblet_damage",.3))
				field.get_tree().create_timer(.18+i*.07,false).timeout.connect(func():
					if is_instance_valid(field) and field.phase=="combat":blast.call(spot,hit))
		"napalm":
			var patch=preload("res://scripts/combat/napalm_patch.gd").new();patch.arena=field;patch.position=at
			patch.radius=float(stats.get("fire_radius",.8));patch.seconds=float(stats.get("fire_time",2.5));patch.damage=bullet.damage*.6
			field.add_child(patch)

# --- Practice fields (hub range, rooms) ---------------------------------------------------------------------------

## The loaded ammo of the room's run (hub: standard rounds).
static func practice_ammo(field)->Dictionary:
	var run_arena=run_of(field)
	return Ammo.effective(run_arena) if run_arena!=null else Ammo.standard()
## A practice round: the same projectile, muzzle point, sound, flash and casing as in battle.
static func practice_bullet(field,shooter:Node3D,facing:Vector2i,damage:float,id:String):
	Game.fire_sound(id,shooter)
	var bullet=load("res://scenes/projectile.tscn").instantiate()
	bullet.arena=field;bullet.friendly=true;bullet.player_shot=true;bullet.damage=damage;bullet.sniper_visual=id=="sniper"
	bullet.direction=facing;bullet.travel_direction=Vector3(facing.x,0,facing.y)
	var model=model_of(shooter);var height=.55
	if is_instance_valid(model) and model.get("muzzle") is Node3D and is_instance_valid(model.muzzle):height=model.muzzle.global_position.y-shooter.global_position.y
	bullet.position=shooter.position+Vector3(facing.x*.39,height,facing.y*.39)
	field.add_child(bullet);field.projectiles.append(bullet)
	var feel=practice_feel(field)
	feel.muzzle(null,bullet.global_position,bullet.travel_direction);feel.casing(shooter,bullet.travel_direction)
	return bullet
## Muzzle flashes and casings need a CombatFeel on the field; practice fields get a light one on first shot.
static func practice_feel(field)->Node:
	var feel=field.get_node_or_null("CombatFeel")
	if feel==null:
		feel=preload("res://scripts/combat/combat_feel.gd").new();feel.name="CombatFeel";feel.arena=field
		feel.rng.seed=PRACTICE_SEED;field.add_child(feel)
	return feel

## Projectile step on a practice field: training targets take the hit (a charge bursts on them), then the field's
## own wall test stops the round — a charge bursts at the wall too.
static func practice_hit(field,bullet)->bool:
	var pos:Vector3=bullet.position
	for target in field.gun_targets():
		if not is_instance_valid(target) or target in bullet.hit_actors:continue
		if absf(pos.x-target.position.x)<TARGET_REACH and absf(pos.z-target.position.z)<TARGET_REACH:
			if bullet.rocket_radius>0:practice_blast(field,bullet);return true
			bullet.hit_actors.append(target);practice_damage(field,target,bullet.damage)
			if not bullet.piercing:return true
	if field.gun_blocked(pos):
		if bullet.rocket_radius>0:practice_blast(field,bullet)
		else:burst(field,pos,Color("dc9870"),.16)
		return true
	return false
## A charge's blast on a practice field: the same flash, sound and radius; every target inside takes the hit,
## then the loaded ammo's extras (cluster bomblets, napalm) play out exactly as in battle.
static func practice_blast(field,bullet):
	burst(field,bullet.position,Color("e8b957"),bullet.rocket_radius);Game.sound("boom",field)
	for target in field.gun_targets():
		if is_instance_valid(target) and flat(bullet.position,target.position)<=bullet.rocket_radius:practice_damage(field,target,bullet.damage)
	var rng=RandomNumberGenerator.new();rng.seed=PRACTICE_SEED+field.projectiles.size()
	charge_effects(field,bullet,practice_ammo(field),rng,func(spot:Vector3,amount:float):
		GrenadeVisual.explode(field,spot,.6,true);Game.sound("boom",field)
		for target in field.gun_targets():
			if is_instance_valid(target) and flat(spot,target.position)<=.6:practice_damage(field,target,amount))
## A hit on a training target: the loaded ammo's flat damage share and its colour; no crit or status rolls, so no
## run randomness is spent outside battle.
const AMMO_COLORS={"burn":"ff8a3d","cryo":"bff3ff","shock":"86daec","stun":"ffe08a","explosive":"ff8a5a","ricochet":"c9a5ff","ap":"ffe0a0"}
static func practice_damage(field,target:Node3D,amount:float):
	var ammo=practice_ammo(field)
	amount*=1.0+float(ammo.get("damage",0.0))
	if AMMO_COLORS.has(str(ammo.type)):burst(field,target.position+Vector3.UP*.45,Color(AMMO_COLORS[str(ammo.type)]),.3)
	field.gun_target_hit(target,amount)
## Hand-to-hand on a practice field: the battle's swipe; training targets in the arc take the strike.
static func practice_strike(field,shooter:Node3D,amount:float,claws:bool):
	var facing=aim(field,shooter);var forward=Vector3(facing.x,0,facing.y).normalized()
	for target in field.gun_targets():
		if not is_instance_valid(target):continue
		var to=target.position-shooter.position;to.y=0
		if to.length()<=Melee.REACH and (to.length()<=.2 or to.normalized().dot(forward)>=Melee.ARC):field.gun_target_hit(target,amount)
	Melee.swipe(model_of(shooter),field,claws,facing)
static func burst(field:Node3D,pos:Vector3,color:Color,radius:float):
	preload("res://scripts/combat_effect.gd").spawn(field,pos,color,radius)
static func flat(a:Vector3,b:Vector3)->float:return Vector2(a.x-b.x,a.z-b.z).length()
