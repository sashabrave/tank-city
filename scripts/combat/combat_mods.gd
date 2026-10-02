class_name CombatMods
extends RefCounted
## Run combat stats beyond damage/rate: crit, dodge, protection by source, pierce, incendiary,
## electric, concussion, stealth ambush, marauder, field repair and luck. All rolls use the run's
## combat RNG so a seed replays the same fight; visuals never consume it.
const MACHINES=["buggy","apc","tank","mortar","drone","flyer","boss"]
const CAPS={"crit_chance":.6,"dodge":.5,"guard":.6,"burn_chance":.8,"stun_chance":.4,"stealth":.5,"shock_bonus":2.0,"marauder":1.0}
## Extreme builds stay meaningful: what goes over a cap flows into a neighbouring stat instead of being lost.
## Every 10% of crit chance over the cap adds 5% crit damage; every 10% of dodge over the cap adds 5% protection.
const OVERFLOW=.5
static func crit_overflow(arena)->float:return maxf(0.0,arena.run.crit_chance+luck(arena)*.002-CAPS.crit_chance)*OVERFLOW
static func dodge_overflow(arena)->float:return maxf(0.0,arena.run.dodge-CAPS.dodge)*OVERFLOW
const BURN_TIME=3.0
const STUN_TIME=.8
static func is_machine(kind:String)->bool:return kind in MACHINES
## Meta luck (station) plus luck cards of this run.
static func luck(arena)->int:return Game.luck_level+(int(arena.run.luck) if arena!=null and arena.run!=null else 0)
static func crit_chance(arena)->float:
	var landing=.5 if arena.run.elapsed<arena.run.landing_until else 0.0
	return minf(CAPS.crit_chance+landing,arena.run.crit_chance+luck(arena)*.002+landing)
static func player_bullet(bullet)->bool:
	return bullet.friendly and is_instance_valid(bullet.owner_actor) and bullet.owner_actor.player_owned
## Damage of a player bullet against one target, with its side effects (statuses, crit flash).
static func outgoing(arena,bullet,target)->float:
	var run=arena.run;var amount=float(bullet.damage)
	# Soldier + vehicle synergies and context cards (behavior_cards flags).
	var shooter=bullet.owner_actor;var in_vehicle=shooter.kind in GarageCatalog.VEHICLES
	if in_vehicle and "crew" in run.behavior_cards:amount*=1.2
	if in_vehicle and "boarding" in run.behavior_cards and shooter.vehicle_origin=="captured":amount*=1.3
	if bullet.opening:amount*=1.4
	if "last_stand" in run.behavior_cards:
		var ratio=(shooter.hp/maxf(1.0,shooter.max_hp)) if in_vehicle else (run.soldier_hp/maxf(1.0,float(run.soldier_max_hp)))
		if ratio<=.25:amount*=1.3
	if is_machine(target.kind) and run.shock_bonus>0:amount*=1.0+minf(CAPS.shock_bonus,run.shock_bonus+run.shock_power)
	if run.stealth>0 and target.hp>=target.max_hp:amount*=1.0+minf(CAPS.stealth,run.stealth)*2.0
	var rng=run.combat_rng
	var crit=rng.randf()<crit_chance(arena)
	if crit:
		amount*=run.crit_damage+crit_overflow(arena)
		arena.burst(target.position+Vector3.UP*.5,Color("ffd166"),.35)
		if "crit_stun" in run.behavior_cards:stun(target,stun_time(run))
	if run.burn_chance>0 and rng.randf()<minf(CAPS.burn_chance,run.burn_chance):ignite(target,bullet.damage,run)
	if run.stun_chance>0 and rng.randf()<minf(CAPS.stun_chance,run.stun_chance):stun(target,stun_time(run))
	if run.shock_bonus>0 and is_machine(target.kind):
		arena.burst(target.position+Vector3.UP*.4,Color("86daec"),.25)
		if "shock_short" in run.behavior_cards and rng.randf()<.25:stun(target,.6)
		if "shock_arc" in run.behavior_cards:arc(arena,target,amount*.4)
	return amount
static func stun_time(run)->float:return STUN_TIME+(run.stun_duration if run!=null else 0.0)
static func burn_time(run)->float:return BURN_TIME+(run.burn_duration if run!=null else 0.0)
## Burn damage per second from the hit that lit it; «Жар» (station and cards) raises it.
static func ignite(target,base_damage:float,run=null):
	var power=1.0+(run.burn_power if run!=null else 0.0)
	target.burn_time=maxf(target.burn_time,burn_time(run));target.burn_dps=maxf(target.burn_dps,base_damage*.35*power)
## «Разряд»: an EMP hit on a machine jolts other machines nearby.
static func arc(arena,source,damage:float):
	for other in arena.room.actors.duplicate():
		if is_instance_valid(other) and other!=source and not other.dead and not other.player_owned and not other.allied and is_machine(other.kind) and arena.flat_distance(other.position,source.position)<1.5:
			other.take_damage(damage,Vector3.ZERO,"");arena.burst(other.position+Vector3.UP*.4,Color("86daec"),.2)
static func stun(target,seconds:float):
	target.stun_time=maxf(target.stun_time,seconds*(.3 if target.kind=="boss" else 1.0))
## Incoming damage to the player: dodge first, then protection by source ("bullet", "vehicle", "blast").
## Returns -1 when the hit was dodged.
static func incoming(arena,amount:float,source:String)->float:
	var run=arena.run
	if source in ["bullet","vehicle"] and run.elapsed<run.landing_until:return -1.0
	if source in ["bullet","vehicle"] and run.dodge>0 and run.combat_rng.randf()<minf(CAPS.dodge,run.dodge):return -1.0
	var guard={"bullet":run.guard_bullet,"vehicle":run.guard_vehicle,"blast":run.guard_blast}.get(source,0.0)
	return amount*(1.0-minf(CAPS.guard,guard+dodge_overflow(arena)))
## Source of a bullet that hit the player: shells from machines count as vehicle fire.
static func bullet_source(bullet)->String:
	return "vehicle" if is_instance_valid(bullet.owner_actor) and is_machine(bullet.owner_actor.kind) else "bullet"
## Enemies engage the player at a shorter range with stealth.
static func engage_range(arena,distance:float)->float:return distance*(1.0-minf(CAPS.stealth,arena.run.stealth))
static func loot_multiplier(arena)->float:return 1.0+minf(CAPS.marauder,arena.run.marauder)
## Kill by the player: field repair, chain fire.
static func on_kill(arena,actor):
	var run=arena.run
	if run.field_repair>0:
		if not arena.room.boss_room and arena.headquarters.has_method("repair"):arena.headquarters.repair(run.field_repair)
		var player=arena.room.player
		if is_instance_valid(player) and player.kind in GarageCatalog.VEHICLES and player.hp<player.max_hp:
			player.hp=minf(player.max_hp,player.hp+run.field_repair);player.refresh_health()
	if "chain_fire" in run.behavior_cards and actor.burn_time>0:
		arena.burst(actor.position,Color("ff8a3d"),1.1)
		for other in arena.room.actors.duplicate():
			if is_instance_valid(other) and other!=actor and not other.dead and not other.player_owned and not other.allied and arena.flat_distance(other.position,actor.position)<1.6:
				other.take_damage(actor.burn_dps*2.0,Vector3.ZERO,"")
				ignite(other,actor.burn_dps/.35,run)
## Burning: ticks twice a second; with «Цепная реакция» it may spread to a neighbour.
static func tick_burn(actor,delta:float):
	if actor.burn_time<=0:return
	actor.burn_time-=delta;actor.burn_tick-=delta
	if actor.burn_tick>0:return
	actor.burn_tick=.5
	var arena=actor.arena
	arena.burst(actor.position+Vector3.UP*.5,Color("ff8a3d"),.22)
	actor.take_damage(actor.burn_dps*.5,Vector3.ZERO,"")
	if actor.dead or arena.run==null:return
	if "chain_fire" in arena.run.behavior_cards and arena.run.combat_rng.randf()<.2:
		for other in arena.room.actors:
			if is_instance_valid(other) and other!=actor and not other.dead and not other.player_owned and not other.allied and other.burn_time<=0 and arena.flat_distance(other.position,actor.position)<1.3:
				# The spreading fire keeps its strength; dps already holds «Жар».
				other.burn_time=maxf(other.burn_time,burn_time(arena.run));other.burn_dps=maxf(other.burn_dps,actor.burn_dps);break
