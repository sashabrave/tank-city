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
## «Урон вблизи» (class path) counts within this many cells.
const CLOSE_RANGE=2.5
static func crit_overflow(arena)->float:return maxf(0.0,arena.run.crit_chance+luck(arena)*.002-CAPS.crit_chance)*OVERFLOW
static func dodge_overflow(arena)->float:return maxf(0.0,arena.run.dodge-CAPS.dodge)*OVERFLOW
const BURN_TIME=3.0
const STUN_TIME=.8
## EMP on infantry (T-231): 25% slower for a second.
const SHOCK_SLOW=.25
const SHOCK_SLOW_TIME=1.0
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
	# Штурмовик's class path: «урон вблизи» on the soldier's own shots within 2.5 cells.
	if not in_vehicle and run.close_damage>0 and arena.flat_distance(shooter.position,target.position)<=CLOSE_RANGE:amount*=1.0+run.close_damage
	if "last_stand" in run.behavior_cards:
		var ratio=(shooter.hp/maxf(1.0,shooter.max_hp)) if in_vehicle else (run.soldier_hp/maxf(1.0,float(run.soldier_max_hp)))
		if ratio<=.25:amount*=1.3
	# Only the active ammo of the soldier's weapon works (T-109/T-112): its rolled values plus its improvement
	# cards. Vehicles fire their own shells.
	var ammo=Ammo.effective(arena) if not in_vehicle else Ammo.standard()
	var type:String=ammo.type;var stats:Dictionary=ammo.stats;var twist:bool=ammo.get("twist",false)
	amount*=1.0+float(ammo.get("damage",0.0))
	if is_machine(target.kind):
		if type=="shock":amount*=1.0+minf(CAPS.shock_bonus,float(stats.get("bonus",0.0))+run.shock_bonus+run.shock_power)
		if type=="ap":amount*=1.0+float(stats.get("armor",0.0))
	if run.stealth>0 and target.hp>=target.max_hp:amount*=1.0+minf(CAPS.stealth,run.stealth)*2.0
	var rng=run.combat_rng
	var crit=rng.randf()<crit_chance(arena)
	# Class perks: «Глаз-алмаз» marks a whole volley, «Последний рубеж» answers through the effects bus. The roll
	# above is always made, so a forced crit never shifts the run's random sequence.
	if not crit and (bullet.get("sure_crit")==true or arena.effects.modify("sure_crit",0.0,{"shooter":shooter})>0):crit=true
	target.set_meta("crit_hit",crit)
	if crit:
		amount*=run.crit_damage+crit_overflow(arena)
		arena.burst(target.position+Vector3.UP*.5,Color("ffd166"),.35)
		if type=="stun" and ("crit_stun" in run.behavior_cards or twist):stun(target,stun_time(run,ammo))
	match type:
		"burn":
			if rng.randf()<minf(CAPS.burn_chance,float(stats.get("chance",0.0))+run.burn_chance):ignite(target,bullet.damage,run,float(stats.get("power",0.0)))
		"stun":
			if rng.randf()<minf(CAPS.stun_chance,float(stats.get("chance",0.0))+run.stun_chance):stun(target,stun_time(run,ammo))
		"shock":
			if is_machine(target.kind):
				arena.burst(target.position+Vector3.UP*.4,Color("86daec"),.25)
				if rng.randf()<float(stats.get("jolt",0.0))+(.25 if "shock_short" in run.behavior_cards else 0.0):stun(target,.6)
				if "shock_arc" in run.behavior_cards or twist:arc(arena,target,amount*.4)
			else:
				# T-231: EMP rounds were useless on infantry — a short jolt now slows a soldier down.
				target.slow_time=maxf(target.slow_time,SHOCK_SLOW_TIME);target.slow_factor=maxf(target.slow_factor,SHOCK_SLOW)
				arena.burst(target.position+Vector3.UP*.4,Color("86daec"),.18)
		"explosive":
			# A small blast around the target; the target itself takes the bullet.
			var radius=float(stats.get("radius",.6));var splash=amount*float(stats.get("splash",.3))
			arena.burst(target.position+Vector3.UP*.3,Color("ff8a5a"),.45+radius*.4)
			for other in arena.room.actors.duplicate():
				if is_instance_valid(other) and other!=target and not other.dead and not other.player_owned and not other.allied and arena.flat_distance(other.position,target.position)<=radius:
					other.take_damage(splash,other.position-target.position+Vector3(.01,0,.01),"","blast")
		"ricochet":
			ricochet(arena,bullet,target,amount*float(stats.get("bounce_damage",.5)),int(stats.get("bounces",1))+(1 if twist else 0))
		"cryo":
			target.slow_time=maxf(target.slow_time,2.0);target.slow_factor=maxf(target.slow_factor,float(stats.get("slow",.2)))
			if rng.randf()<float(stats.get("freeze",0.0)):stun(target,1.0);target.set_meta("frozen_by_cryo",true)
			arena.burst(target.position+Vector3.UP*.4,Color("bff3ff"),.25)
	run.best_hit=maxf(run.best_hit,amount)
	return amount
static func stun_time(run,ammo:Dictionary={})->float:
	var base=float(ammo.get("stats",{}).get("time",STUN_TIME)) if ammo.get("type","")=="stun" else STUN_TIME
	return base+(run.stun_duration if run!=null else 0.0)
static func burn_time(run)->float:return BURN_TIME+(run.burn_duration if run!=null else 0.0)
## Burn damage per second from the hit that lit it; «Жар» (station and cards) raises it.
static func ignite(target,base_damage:float,run=null,ammo_power:=0.0):
	var power=1.0+ammo_power+(run.burn_power if run!=null else 0.0)
	target.burn_time=maxf(target.burn_time,burn_time(run));target.burn_dps=maxf(target.burn_dps,base_damage*.35*power)
## «Разряд»: an EMP hit on a machine jolts other machines nearby.
static func arc(arena,source,damage:float):
	for other in arena.room.actors.duplicate():
		if is_instance_valid(other) and other!=source and not other.dead and not other.player_owned and not other.allied and is_machine(other.kind) and arena.flat_distance(other.position,source.position)<1.5:
			other.take_damage(damage,Vector3.ZERO,"");arena.burst(other.position+Vector3.UP*.4,Color("86daec"),.2)
static func stun(target,seconds:float):
	target.stun_time=maxf(target.stun_time,seconds*(.3 if target.kind=="boss" else 1.0))
## Incoming damage to the player: dodge first, then protection by source ("bullet", "vehicle", "blast").
## Returns DODGED when the dodge roll succeeded and LANDING during the landing cover (both negative).
const DODGED=-1.0
const LANDING=-2.0
static func incoming(arena,amount:float,source:String)->float:
	var run=arena.run
	if source in ["bullet","vehicle"] and run.elapsed<run.landing_until:return LANDING
	if source in ["bullet","vehicle"] and run.dodge>0 and run.combat_rng.randf()<minf(CAPS.dodge,run.dodge):return DODGED
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
	var ammo=Ammo.effective(arena);var twist:bool=ammo.get("twist",false)
	if twist and ammo.type=="explosive":
		arena.burst(actor.position+Vector3.UP*.3,Color("ff6a3a"),1.0)
		for other in arena.room.actors.duplicate():
			if is_instance_valid(other) and other!=actor and not other.dead and not other.player_owned and not other.allied and arena.flat_distance(other.position,actor.position)<1.2:other.take_damage(1.0,other.position-actor.position+Vector3(.01,0,.01),"","blast")
	if twist and ammo.type=="cryo" and actor.has_meta("frozen_by_cryo"):
		arena.burst(actor.position+Vector3.UP*.4,Color("dff8ff"),1.0)
		for other in arena.room.actors.duplicate():
			if is_instance_valid(other) and other!=actor and not other.dead and not other.player_owned and not other.allied and arena.flat_distance(other.position,actor.position)<1.4:other.take_damage(.8,Vector3.ZERO,"","blast")
	if ("chain_fire" in run.behavior_cards or (twist and ammo.type=="burn")) and actor.burn_time>0:
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
## Рикошет: the bullet hops to the nearest other enemy within 3.5 cells with part of its damage.
static func ricochet(arena,bullet,target,damage:float,bounces:int):
	var left=int(bullet.get_meta("bounces_left",bounces))
	if left<=0 or damage<.05:return
	var best=null;var best_d=3.5
	for other in arena.room.actors:
		if not is_instance_valid(other) or other==target or other.dead or other.player_owned or other.allied or other in bullet.hit_actors:continue
		var d=arena.flat_distance(other.position,target.position)
		if d<best_d:best=other;best_d=d
	if best==null:return
	var dir=(best.position-target.position);dir.y=0
	var hop=arena.spawn_free_bullet(bullet.owner_actor,dir,damage,9.0,false)
	hop.friendly=true;hop.player_shot=true;hop.position=target.position+dir.normalized()*.35+Vector3.UP*.55
	hop.hit_actors=bullet.hit_actors.duplicate();hop.hit_actors.append(target);hop.set_meta("bounces_left",left-1)
	arena.burst(target.position+Vector3.UP*.5,Color("c9a5ff"),.25)
