extends Node3D
## Bullet effects come only from run cards: station «Жар/Разряд/Оглушение» never switch an effect on,
## enhancement cards appear after the base card, chain fire owns spreading, old station levels refund once.
## Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func bullet_from(owner,damage:float):
	var b=load("res://scenes/projectile.tscn").instantiate();b.friendly=true;b.owner_actor=owner;b.damage=damage;return b
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	Game.selected_class="recruit"
	Game.stat_levels={"burn_power":5,"shock_power":5,"stun_power":5}
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=23;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	var player=arena.player;player.set_physics_process(false);var run=arena.run
	check(run.burn_chance==0.0 and run.stun_chance==0.0 and run.shock_bonus==0.0,"maxed station effects do not switch effects on")
	check(is_equal_approx(run.burn_power,.3) and is_equal_approx(run.stun_duration,.25) and is_equal_approx(run.shock_power,.25),"station gives small base strength")
	var tank=arena.spawn_actor("tank",Vector2i(6,1),false);tank.set_physics_process(false);tank.hp=999;tank.max_hp=999
	run.crit_chance=0.0
	check(is_equal_approx(CombatMods.outgoing(arena,bullet_from(player,1.0),tank),1.0),"station EMP alone adds no damage to machines")
	for id in ["burn_heat","burn_long","chain_fire","stun_long","stun_often","crit_stun","shock_overload","shock_short","shock_arc"]:
		check(not RunUpgrades.eligible(arena,UpgradeRegistry.get_def(id)),id+" waits for its base card")
	for id in ["burn","stun","shock"]:check(RunUpgrades.eligible(arena,UpgradeRegistry.get_def(id)),id+" base card is offered")
	RunUpgrades.apply(arena,"burn",0)
	# Ammo v2: the base ammo card can drop again (another roll); it loads, it does not stack (T-112).
	check(Ammo.active(run)=="burn","base card loads incendiary ammo")
	check(RunUpgrades.eligible(arena,UpgradeRegistry.get_def("burn_heat")) and RunUpgrades.eligible(arena,UpgradeRegistry.get_def("chain_fire")),"fire enhancements open after the base card")
	check(not RunUpgrades.eligible(arena,UpgradeRegistry.get_def("stun_long")),"other effects stay closed")
	# Burn strength and duration.
	var enemy=arena.spawn_actor("soldier",Vector2i(3,1),false);enemy.set_physics_process(false);enemy.hp=999;enemy.max_hp=999
	CombatMods.ignite(enemy,2.0,run)
	check(is_equal_approx(enemy.burn_dps,2.0*.35*1.3) and is_equal_approx(enemy.burn_time,3.0),"station heat raises burn damage")
	RunUpgrades.apply(arena,"burn_long",0);enemy.burn_time=0;CombatMods.ignite(enemy,2.0,run)
	check(enemy.burn_time>3.0,"long flame burns longer")
	# Spreading needs chain fire.
	var near=arena.spawn_actor("soldier",Vector2i(3,2),false);near.set_physics_process(false);near.hp=999;near.max_hp=999;near.position=enemy.position+Vector3(.6,0,0)
	for i in range(60):enemy.burn_time=3.0;enemy.burn_tick=0;CombatMods.tick_burn(enemy,.1)
	check(near.burn_time<=0,"without chain fire the fire does not spread")
	RunUpgrades.apply(arena,"chain_fire",1)
	for i in range(60):enemy.burn_time=3.0;enemy.burn_tick=0;CombatMods.tick_burn(enemy,.1)
	check(near.burn_time>0,"chain fire spreads to a neighbour")
	# EMP card + station power.
	RunUpgrades.apply(arena,"shock",0)
	check(is_equal_approx(CombatMods.outgoing(arena,bullet_from(player,1.0),tank),1.0+float(Ammo.item(run).stats.bonus)+run.shock_power),"EMP item plus station power")
	# Class: gunner no longer burns by default.
	check(not ClassCatalog.info("gunner").modifiers.any(func(m):return m.stat in ["burn_chance","stun_chance","shock_bonus"]),"gunner has no default effect")
	# Profile migration refunds the old station effect levels once.
	var schema=preload("res://scripts/profile/schema.gd")
	var old=Game.serialize_progress();old.version=12;old.credits=100;old.notifications=[];old.stat_levels={"burn_chance":2,"stun_chance":1,"crit_chance":3}
	var migrated=schema.validate(old)
	check(migrated.ok and int(migrated.data.credits)==100+70+105+80,"old effect levels refunded: %s" % str(migrated.data.get("credits")))
	check(migrated.ok and not migrated.data.stat_levels.has("burn_chance") and int(migrated.data.stat_levels.crit_chance)==3,"other station levels kept")
	check(migrated.ok and migrated.data.notifications.size()==1,"player is told about the refund")
	Game.stat_levels={}
	print("EFFECT CARDS: %d failures" % failures);get_tree().quit(1 if failures else 0)
