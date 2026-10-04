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
	var hits=[]
	for i in range(60):hits.append(CombatMods.outgoing(arena,bullet_from(player,1.0),enemy))
	# Crit chance over the 60% cap flows into crit damage: (1.0-.6)*.5 = +.2.
	var crit_hit=2.0+CombatMods.crit_overflow(arena)
	check(hits.any(func(h):return is_equal_approx(h,crit_hit)) and hits.has(1.0) and is_equal_approx(crit_hit,2.2),"crit doubles damage (+overflow) and stays below certainty")
	check(CombatMods.crit_chance(arena)<=CombatMods.CAPS.crit_chance,"crit chance is capped")
	run.crit_chance=0.0;run.crit_damage=1.5;Game.luck_level=0
	# Effects work only through the loaded ammo (T-109): load a zero-roll item, the run stat does the rest.
	var load_ammo=func(type:String):Ammo.ensure(run,arena.weapon);run.ammo_slots[0]={"type":type,"rarity":0,"stats":{},"damage":0.0,"twist":false};run.ammo_active=0
	load_ammo.call("shock")
	run.shock_bonus=.5
	check(is_equal_approx(CombatMods.outgoing(arena,bullet_from(player,1.0),tank),1.5),"electric rounds hit machines harder")
	check(is_equal_approx(CombatMods.outgoing(arena,bullet_from(player,1.0),enemy),1.0),"electric rounds do not boost infantry")
	check(enemy.slow_time>=CombatMods.SHOCK_SLOW_TIME-.01 and enemy.slow_factor>=CombatMods.SHOCK_SLOW,"electric rounds briefly slow infantry (T-231)")
	enemy.slow_time=0.0;enemy.slow_factor=0.0
	run.shock_bonus=0.0
	# Stealth ambush: unhurt target only
	run.stealth=.1
	check(is_equal_approx(CombatMods.outgoing(arena,bullet_from(player,1.0),enemy),1.2),"stealth ambush on an unhurt enemy")
	enemy.hp=500
	check(is_equal_approx(CombatMods.outgoing(arena,bullet_from(player,1.0),enemy),1.0),"no ambush on a hurt enemy")
	check(is_equal_approx(CombatMods.engage_range(arena,10.0),9.0),"stealth shortens enemy engage range")
	run.stealth=0.0
	# Statuses
	load_ammo.call("burn")
	run.burn_chance=1.0
	for i in range(20):
		if enemy.burn_time<=0:CombatMods.outgoing(arena,bullet_from(player,2.0),enemy)
	check(enemy.burn_time>0 and enemy.burn_dps>0,"incendiary rounds ignite")
	var before=enemy.hp;CombatMods.tick_burn(enemy,.6)
	check(enemy.hp<before,"burning deals damage over time")
	run.burn_chance=0.0;run.stun_chance=1.0;load_ammo.call("stun")
	for i in range(20):
		if enemy.stun_time<=0:CombatMods.outgoing(arena,bullet_from(player,1.0),enemy)
	check(enemy.stun_time>0,"concussion stuns")
	run.stun_chance=0.0;load_ammo.call("standard")
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
	# T-221: a commander/boss chest leans harder to the build — incendiary loaded: fire cards, not a concussion box.
	var slots_before=run.ammo_slots.duplicate(true)
	run.upgrade_history=[{"id":"burn","tier":0}];Ammo.ensure(run,arena.weapon);run.ammo_slots[0]=Ammo.roll("burn",0,3)
	var pull=RunUpgrades.family_counts(arena)
	var heat_def=UpgradeRegistry.get_def("burn_heat");var stun_box=UpgradeRegistry.get_def("stun")
	check(RunUpgrades.attracted_weight(arena,heat_def,pull,true)>=2.9*RunUpgrades.attracted_weight(arena,heat_def,pull) and RunUpgrades.attracted_weight(arena,stun_box,pull,true)<RunUpgrades.attracted_weight(arena,stun_box,pull),"chest: fire improvement ×3+, other ammo box weaker")
	var fire_wave=0;var fire_chest=0
	for i in range(200):
		for offer in RunUpgrades.roll_offers(arena,2):fire_wave+=int(Ammo.type_of(offer.id)=="burn")
		for offer in RunUpgrades.roll_offers(arena,2,true):fire_chest+=int(Ammo.type_of(offer.id)=="burn")
	check(fire_chest>fire_wave*1.5,"chest offers more fire cards with incendiary loaded (%d → %d)" % [fire_wave,fire_chest])
	run.ammo_slots=slots_before;run.upgrade_history.clear()
	Game.selected_class="recruit"
	# Flag cards
	RunUpgrades.apply(arena,"crit_stun",2)
	check("crit_stun" in run.behavior_cards and not RunUpgrades.eligible(arena,UpgradeRegistry.get_def("crit_stun")),"flag card taken once")
	# One luck: the former rarity branch folds into luck
	Game.apply_profile({"luck":2,"rarity":3,"branch_unlocks":["health","rarity"]})
	check(Game.luck_level==5 and Game.rarity_level==0 and "luck" in Game.branch_unlocks and "rarity" not in Game.branch_unlocks,"rarity levels move into luck")
	# Registry: every stat file is saved in checkpoints and shown in the dossier
	var keys=preload("res://scripts/profile/run_checkpoint.gd").keys()
	check(StatRegistry.all().all(func(d):return d.run_field in keys),"checkpoint saves every registry stat")
	check(preload("res://scripts/ui/stat_snapshot.gd").registry(arena).size()==StatRegistry.all().size(),"dossier lists every registry stat")
	# Meta stage 4: «Выучка» is gone — old station levels are refunded on load and no longer apply.
	Game.stat_levels={"dodge":2,"future_stat":4};var credits_before=Game.credits
	var saved=Game.serialize_progress();Game.apply_profile(saved)
	check(Game.stat_levels.is_empty() and Game.credits>credits_before,"old station levels are refunded")
	var fresh=preload("res://scripts/state/run_state.gd").new();StatRegistry.apply_meta(fresh)
	check(is_equal_approx(fresh.dodge,0.0),"no station levels at run start")
	# Backpack safe: the first slots always survive a death, the rest roll the HQ insurance
	var carried=[{"id":"a"},{"id":"b"},{"id":"c"}]
	var kept=preload("res://scripts/recipe_extraction.gd").survivors(carried,false,0,arena.run.combat_rng,2)
	check(kept.size()==2 and kept[0].id=="a" and kept[1].id=="b","safe slots keep their blueprints")
	arena.queue_free();await get_tree().process_frame
	await grenadier_checks()
	await friendly_fire_checks()
	await smg_burst_checks()
	await difficulty_checks()
	Game.reset_upgrades();Campaign.configure(1)
	print("COMBAT STATS: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

# from grenadier_environment: an enemy grenade hurts the base and a nearby brick once; far and solid blocks untouched.
func grenadier_checks():
	Game.reset_upgrades();Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat"
	var center=arena.base_cell
	var near=center+Vector2i.LEFT;var far=center+Vector2i(3,0);var solid=center+Vector2i.RIGHT
	for cell in [near,far,solid]:
		if arena.walls.has(cell):arena.walls[cell].node.queue_free();arena.walls.erase(cell)
	arena.add_wall(near,10);arena.add_wall(far,10);arena.add_wall(solid,-1)
	var enemy=arena.spawn_actor("grenadier",Vector2i(3,3),false);enemy.set_physics_process(false)
	var amount=enemy.damage;check(amount>0,"grenadier has damage")
	var hp=arena.base_hp
	arena.throw_grenade(enemy,arena.world_pos(center))
	var grenade=arena.grenades.back();grenade.set_physics_process(false)
	check(is_equal_approx(grenade.damage,amount) and not grenade.friendly,"enemy grenade carries the grenadier damage")
	grenade._physics_process(grenade.flight_time+.01)
	check(grenade.spent and is_equal_approx(arena.base_hp,hp-amount),"enemy grenade damages the base once")
	check(is_equal_approx(arena.walls[near].hp,10-amount),"enemy grenade damages a nearby brick")
	check(arena.walls[far].hp==10 and arena.walls[solid].hp==-1,"distant and solid blocks are untouched")
	grenade._physics_process(1);check(is_equal_approx(arena.base_hp,hp-amount),"no duplicate explosion")
	arena.queue_free();await get_tree().process_frame

# from friendly_fire_revision (T-165): own explosives bite allies a little, own bullets never do; hub comrade blocks its cell.
func friendly_fire_checks():
	Game.reset_upgrades();Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena)
	await get_tree().create_timer(.6).timeout;arena.set_physics_process(false);arena.phase="combat"
	arena.summon_comrade(.5,0);var buddy=arena.actors.back();buddy.set_physics_process(false);buddy.parachute_left=0
	var hp=buddy.hp
	arena.grenade_explosion(buddy.position,5.0,true,1.2)
	check(buddy.hp==hp-1.0,"own grenade bites the comrade by 1 (%s → %s)" % [hp,buddy.hp])
	hp=buddy.hp
	var bullet=load("res://scenes/projectile.tscn").instantiate();bullet.arena=arena;bullet.owner_actor=arena.player;bullet.friendly=true;bullet.damage=3.0;bullet.position=buddy.position+Vector3.UP*.5;arena.add_child(bullet)
	arena.bullet_hit(bullet)
	check(buddy.hp==hp,"own bullets pass the comrade")
	arena.queue_free();await get_tree().process_frame
	Game.selected_class="recruit"
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);await get_tree().create_timer(.5).timeout
	var effect=load("res://scripts/hub_ability_effect.gd").new();effect.hub=hub;effect.kind="comrade";hub.add_child(effect)
	check(effect.accepted and effect.deployed_cell in hub.training_barriers and not hub.hub_free(effect.deployed_cell),"hub comrade blocks its cell")
	var taken=effect.deployed_cell
	effect.queue_free();await get_tree().process_frame
	check(taken not in hub.training_barriers,"the cell frees when the comrade leaves")
	hub.queue_free();await get_tree().process_frame

# from smg_burst_revision: pistol and SMG share a short range; one SMG pull fires a 3-shot burst; rate counts every shot.
func smg_burst_checks():
	Game.reset_upgrades();Campaign.configure(1)
	var W=Game.LOOT.WEAPONS
	check(is_equal_approx(W.pistol.range,W.smg.range) and W.pistol.range<W.rifle.range,"pistol and SMG: same shorter range")
	check(int(W.smg.burst)==3 and int(W.pistol.burst)==1,"SMG fires bursts of 3")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=5;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().process_frame
	arena.run.weapon="smg";arena.phase="combat"
	var spawned=[0]
	arena.child_entered_tree.connect(func(n):if n.get("friendly")==true:spawned[0]+=1)
	arena.fire_weapon(arena.player)
	check(spawned[0]==1,"first shot of the burst is immediate")
	await get_tree().create_timer(.25).timeout
	check(spawned[0]==3,"two more shots follow (%d)" % spawned[0])
	var stats=CombatStats.weapon(arena,"smg")
	check(is_equal_approx(stats.rate,3.0/stats.interval),"rate counts every shot of the burst")
	arena.queue_free();await get_tree().process_frame

# T-266: world difficulty scales hostile health and damage once at spawn (×0.75 / ×1 / ×1.25), hard pays
# 20% more alloy, normal is today's game; allies are untouched; an old profile without the field loads as normal.
func difficulty_checks():
	Game.reset_upgrades();Campaign.configure(1)
	check(Campaign.difficulty=="normal" and Game.world_difficulty=="normal","normal by default")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=23;add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	var stats={};var column=1
	for id in ["normal","hard","easy"]:
		Campaign.difficulty=id
		var foe=arena.spawn_actor("tank",Vector2i(column,1),false);foe.set_physics_process(false)
		var ally=arena.spawn_actor("soldier",Vector2i(column,3),false,true);ally.set_physics_process(false)
		stats[id]={"hp":foe.max_hp,"damage":foe.damage,"ally":ally.max_hp,"kill":EncounterRules.kill_alloy("tank",1,3),"chest":EncounterRules.chest_alloy(3,2)}
		column+=2
	Campaign.difficulty="normal"
	check(is_equal_approx(stats.hard.hp,stats.normal.hp*1.25) and is_equal_approx(stats.hard.damage,stats.normal.damage*1.25),"hard: enemy health and damage ×1.25")
	check(is_equal_approx(stats.easy.hp,stats.normal.hp*.75) and is_equal_approx(stats.easy.damage,stats.normal.damage*.75),"easy: enemy health and damage ×0.75")
	check(stats.normal.ally==stats.hard.ally and stats.normal.ally==stats.easy.ally,"allies are not scaled")
	check(stats.easy.kill==stats.normal.kill and stats.easy.chest==stats.normal.chest,"easy keeps alloy")
	check(absi(stats.hard.kill-roundi(stats.normal.kill*1.2))<=1 and absi(stats.hard.chest-roundi(stats.normal.chest*1.2))<=1 and stats.hard.chest>stats.normal.chest,"hard: alloy ×1.2 (%d→%d, %d→%d)" % [stats.normal.kill,stats.hard.kill,stats.normal.chest,stats.hard.chest])
	arena.queue_free();await get_tree().process_frame
	# Profile and checkpoint.
	Game.world_difficulty="hard";var profile=Game.serialize_progress()
	check(preload("res://scripts/profile/schema.gd").validate(profile).ok and profile.world_difficulty=="hard","profile keeps the difficulty")
	Game.world_difficulty="normal";Game.apply_profile(profile);check(Game.world_difficulty=="hard","difficulty restored from the profile")
	profile.erase("world_difficulty");Game.apply_profile(profile);check(Game.world_difficulty=="normal","old profile without the field loads as normal")
	profile.world_difficulty="brutal";Game.apply_profile(profile);check(Game.world_difficulty=="normal","unknown difficulty falls back to normal")
	Campaign.difficulty="hard"
	var cp=preload("res://scripts/profile/run_checkpoint.gd").capture(null,0,"map",{})
	check(cp.get("difficulty")=="hard","checkpoint carries the run difficulty")
	Campaign.configure(1,true,true);check(Campaign.difficulty=="normal","daily run is always normal")
	Game.reset_upgrades();Campaign.configure(1)
