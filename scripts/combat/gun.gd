class_name Gun
extends RefCounted
## One hero, one gun (step U1, 2026-10-04): every shot of the hero goes through this module, on one field engine
## (guides/02_development/07_one_world.md) — the battle, the rooms between fields (service mode) and the hub
## (the practice run, hub mode) are all the Arena: real targets, walls and blasts (CombatSystem.bullet_hit /
## rocket_impact). The hub's own practice branch is gone (step 2). `Gun.stats(null)` still reads the hub loadout
## for the stations' numbers.
const LOOT=preload("res://scripts/loot_catalog.gd")
const SPREAD:=.10            # radians between pellets
const LOB_WEAPON:="grenade_launcher"

## The run behind a field: the arena itself, or null without one (the stations' numbers).
static func run_of(field):
	if field==null:return null
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

## One pull: the paws scratch, a dry gun hits with its butt, a gun fires a volley (bursts follow on pausable timers).
static func fire(field,shooter:Node3D):
	var id=weapon_id(field);var data:Dictionary=LOOT.WEAPONS[id]
	# Empty hands (2026-10-03): Space scratches with the paws instead of a shot (there is no separate strike key).
	if id==LootCatalog.PAWS:
		hint(field,shooter,"Возьми оружие")
		Melee.strike(field,shooter,shooter.damage*field.effects.modify("shot_damage",1.0,{"actor":shooter}),true)
		return
	# No rounds loaded (T-197): the gun hits with its butt; a small reminder over the hero now and then.
	if Ammo.dry(field.run):
		hint(field,shooter,"Нет боеприпасов")
		Melee.strike(field,shooter,Melee.damage(field)*Melee.BUTT,false)
		return
	volley(field,shooter,id)
	# Bursts (SMG): the rest of the pull follows on pausable timers in the facing of that moment.
	for k in range(1,int(data.get("burst",1))):
		field.get_tree().create_timer(float(data.get("burst_gap",.07))*k,false).timeout.connect(func():
			if is_instance_valid(field) and is_instance_valid(shooter) and shooter.get("dead")!=true and field.phase=="combat" and weapon_id(field)==id:
				volley(field,shooter,id)
				Game.weapon_sound(shooter))

## The small hint of a strike instead of a shot (author, 4 Oct 2026): a short word rising over the hero, at most
## once per HINT_PAUSE seconds — not the big toast. The same in battle, the hub and the rooms. Visual only.
const HINT_PAUSE:=2.5
static func hint(field:Node,shooter:Node3D,text:String):
	if not is_instance_valid(shooter) or not shooter.is_inside_tree() or not field is Node3D:return
	var now=Time.get_ticks_msec()
	if now<int(shooter.get_meta("gun_hint_at",-100000))+int(HINT_PAUSE*1000):return
	shooter.set_meta("gun_hint_at",now)
	var word=Visuals.label3d(field,text,Vector3.ZERO,Color("ffe3a8"),26)
	word.global_position=shooter.global_position+Vector3.UP*1.9
	var t=word.create_tween().set_parallel(true)
	t.tween_property(word,"position:y",word.position.y+.7,.9)
	t.tween_property(word,"modulate:a",0.0,.5).set_delay(.5)
	t.chain().tween_callback(word.queue_free)

## One volley: every pellet with its spread, speed, range, pierce and blast; the grenade launcher lobs.
static func volley(field,shooter:Node3D,id:String):
	var data:Dictionary=LOOT.WEAPONS[id]
	var facing:Vector2i=shooter.facing
	var multiplier=field.effects.modify("shot_damage",1.0,{"actor":shooter})
	field.effects.emit("shot",{"actor":shooter})
	var damage:float=shooter.damage*multiplier
	for i in range(data.pellets):
		var bullet=field.spawn_bullet(shooter,shooter.position,facing,damage,true)
		var spread=(i-(data.pellets-1)*.5)*SPREAD
		bullet.travel_direction=bullet.travel_direction.rotated(Vector3.UP,spread);bullet.rotation.y=atan2(-bullet.travel_direction.x,-bullet.travel_direction.z)
		bullet.speed=data.speed;bullet.lifetime=data.range*field.run.range_multiplier/data.speed;bullet.piercing=data.pierce;bullet.rocket_radius=data.blast
		if data.blast>0:bullet.scale=Vector3(2,2,2)
		if id==LOB_WEAPON:lob(field,shooter,bullet,data)

## Grenade launcher (T-268, author: «работает как РПГ»): the charge goes over cover in an arc and lands on the first
## target in the line of fire within range, otherwise at full range. The RPG keeps its straight rocket.
static func lob(field,shooter:Node3D,bullet,data:Dictionary):
	var reach=float(data.range)*field.run.range_multiplier;var distance=reach
	for target in field.room.actors:
		if not is_instance_valid(target) or target.dead or target.player_owned or target.allied:continue
		var offset=target.position-shooter.position;offset.y=0
		var along=offset.dot(bullet.travel_direction)
		if along>.5 and along<distance and (offset-bullet.travel_direction*along).length()<.6:distance=along
	bullet.lobbed=true;bullet.lob_ground=bullet.position.y;bullet.lifetime=distance/bullet.speed
## Where a lobbed charge may still fly: inside the field's grid.
static func on_field(field,pos:Vector3)->bool:
	return not field.has_method("inside") or field.inside(field.grid_pos(pos))

static func model_of(shooter)->Node3D:
	return shooter.model if shooter.get("model") is Node3D else shooter


## Where a shot leaves the barrel (2026-10-04, author: «снаряды вылетают из тела, а не из ствола»), in world space:
## `spawn` — the round's start: the forward reach and the height of the shouldered gun's «Muzzle», but on the
## shooter's own lane, so a round never drifts sideways off the cell line it aims along; `flash` — the barrel end
## itself (muzzle flash, casing). The gun comes to the shoulder with the shot. Without a gun model: `forward`/`height`.
static func muzzle(shooter:Node3D,facing:Vector2i,forward:=.39,height:=.55)->Dictionary:
	var base:=shooter.global_position;var dir:=Vector3(facing.x,0,facing.y)
	var model=model_of(shooter)
	if is_instance_valid(model) and model.has_method("muzzle_point"):
		var point:Vector3=model.muzzle_point()
		if point!=Vector3.INF:
			model.shoulder()
			forward=clampf((point-base).dot(dir),.2,1.2);height=point.y-base.y
	var spawn:=base+dir*forward+Vector3.UP*height
	return {"spawn":spawn,"flash":spawn,"casing":spawn-dir*minf(.25,forward*.5)}

## Loaded ammo extras of a charge's blast (T-114), shared by every field: cluster scatters bomblets around the
## landing spot, napalm leaves a burning patch. `rng` is the fight's generator;
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
