extends Node3D
# Combat stats and card rarity: crit, dodge, protection, pierce, statuses, luck migration,
# per-card rarity by stage and luck, family attraction. Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func bullet_from(owner,damage:float):
	var b=load("res://scenes/projectile.tscn").instantiate();b.friendly=true;b.owner_actor=owner;b.damage=damage;return b
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=17;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	var player=arena.player;player.set_physics_process(false)
	var enemy=arena.spawn_actor("soldier",Vector2i(3,1),false);enemy.set_physics_process(false);enemy.hp=999;enemy.max_hp=999
	var tank=arena.spawn_actor("tank",Vector2i(6,1),false);tank.set_physics_process(false);tank.hp=999;tank.max_hp=999
	var run=arena.run
	# Crit and electric
	run.crit_chance=1.0;run.crit_damage=2.0
	check(is_equal_approx(CombatMods.outgoing(arena,bullet_from(player,1.0),enemy),2.0*(1.0)),"guaranteed crit doubles damage")
	check(CombatMods.crit_chance(arena)<=CombatMods.CAPS.crit_chance,"crit chance is capped")
	run.crit_chance=0.0;run.crit_damage=1.5;Game.luck_level=0
	run.shock_bonus=.5
	check(is_equal_approx(CombatMods.outgoing(arena,bullet_from(player,1.0),tank),1.5),"electric rounds hit machines harder")
	check(is_equal_approx(CombatMods.outgoing(arena,bullet_from(player,1.0),enemy),1.0),"electric rounds do not boost infantry")
	run.shock_bonus=0.0
	# Stealth ambush: unhurt target only
	run.stealth=.1
	check(is_equal_approx(CombatMods.outgoing(arena,bullet_from(player,1.0),enemy),1.2),"stealth ambush on an unhurt enemy")
	enemy.hp=500
	check(is_equal_approx(CombatMods.outgoing(arena,bullet_from(player,1.0),enemy),1.0),"no ambush on a hurt enemy")
	check(is_equal_approx(CombatMods.engage_range(arena,10.0),9.0),"stealth shortens enemy engage range")
	run.stealth=0.0
	# Statuses
	run.burn_chance=1.0
	for i in range(20):
		if enemy.burn_time<=0:CombatMods.outgoing(arena,bullet_from(player,2.0),enemy)
	check(enemy.burn_time>0 and enemy.burn_dps>0,"incendiary rounds ignite")
	var before=enemy.hp;CombatMods.tick_burn(enemy,.6)
	check(enemy.hp<before,"burning deals damage over time")
	run.burn_chance=0.0;run.stun_chance=1.0
	for i in range(20):
		if enemy.stun_time<=0:CombatMods.outgoing(arena,bullet_from(player,1.0),enemy)
	check(enemy.stun_time>0,"concussion stuns")
	run.stun_chance=0.0
	# Incoming: dodge cap and protection by source
	run.dodge=1.0;var dodged=0
	for i in range(400):
		if CombatMods.incoming(arena,1.0,"bullet")<0:dodged+=1
	check(dodged>150 and dodged<250,"dodge is capped at 50%% (%d/400)" % dodged)
	check(CombatMods.incoming(arena,1.0,"blast")>0,"blasts cannot be dodged")
	run.dodge=0.0;run.guard_blast=.3;run.guard_bullet=.9
	check(is_equal_approx(CombatMods.incoming(arena,1.0,"blast"),.7),"blast protection")
	check(is_equal_approx(CombatMods.incoming(arena,1.0,"bullet"),1.0-CombatMods.CAPS.guard),"protection is capped")
	check(CombatMods.bullet_source(bullet_from(tank,1.0))=="vehicle","tank shells count as vehicle fire")
	run.guard_blast=0.0;run.guard_bullet=0.0
	# Pierce charges on player bullets
	run.pierce=2
	var shot=arena.spawn_bullet(player,player.position,Vector2i.UP,1.0,true)
	check(shot.pierce_left==2 and arena.combat.pierce_on(shot) and arena.combat.pierce_on(shot) and not arena.combat.pierce_on(shot),"pierce passes through two enemies")
	shot.queue_free();run.pierce=0
	# Rarity by stage and luck
	var counts=[0,0,0,0]
	for i in range(4000):counts[RunUpgrades.roll_tier(arena)]+=1
	check(counts[1]>150 and counts[1]<450 and counts[2]<120 and counts[3]<25,"start: rare cards are rare %s" % str(counts))
	Game.luck_level=20;var lucky=[0,0,0,0]
	for i in range(4000):lucky[RunUpgrades.roll_tier(arena)]+=1
	check(lucky[1]+lucky[2]+lucky[3]>counts[1]+counts[2]+counts[3],"luck raises rarity %s" % str(lucky))
	Game.luck_level=0
	# Legendary cards only at their rarity
	for offer in RunUpgrades.roll_offers(arena,3):
		check(int(offer.tier)>=UpgradeRegistry.get_def(offer.id).min_tier,"card rarity respects its minimum: "+offer.id)
	# Favourite family and attraction
	Game.selected_class="gunner";run.upgrade_history.clear()
	var first=RunUpgrades.roll_offers(arena,3)
	check(UpgradeRegistry.get_def(first[0].id).family=="ammo","first offer holds the shell's favourite family")
	var ammo_before=0;var ammo_after=0
	for i in range(300):
		run.upgrade_history=[{"id":"damage","tier":0}]
		for offer in RunUpgrades.roll_offers(arena,3):ammo_before+=int(UpgradeRegistry.get_def(offer.id).family=="ammo")
		run.upgrade_history=[{"id":"burn","tier":0},{"id":"shock","tier":0},{"id":"stun","tier":0}]
		for offer in RunUpgrades.roll_offers(arena,3):ammo_after+=int(UpgradeRegistry.get_def(offer.id).family=="ammo")
	check(ammo_after>ammo_before,"taken family attracts its cards (%d → %d)" % [ammo_before,ammo_after])
	Game.selected_class="recruit"
	# Flag cards
	RunUpgrades.apply(arena,"crit_stun",2)
	check("crit_stun" in run.behavior_cards and not RunUpgrades.eligible(arena,UpgradeRegistry.get_def("crit_stun")),"flag card taken once")
	# One luck: the former rarity branch folds into luck
	Game.apply_profile({"luck":2,"rarity":3,"branch_unlocks":["health","rarity"]})
	check(Game.luck_level==5 and Game.rarity_level==0 and "luck" in Game.branch_unlocks and "rarity" not in Game.branch_unlocks,"rarity levels move into luck")
	print("COMBAT STATS: %d failures" % failures)
	get_tree().quit(failures)
