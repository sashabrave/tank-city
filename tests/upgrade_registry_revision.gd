extends Node3D
# Upgrade registry: every card loads, previews equal the real effect, caps hide useless cards,
# behaviour cards run through the event bus. Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	var defs=UpgradeRegistry.all()
	check(defs.size()>=15,"registry loads all card files")
	for def in defs:
		# Ammo items (T-112) carry rolled values instead of modifiers.
		check(def.id!="" and def.title!="" and (def.modifiers.size()>0 or def.effect!=null or def.flag or def.id in Ammo.TYPES),"card is complete: "+def.id)
		for modifier in def.modifiers:check(modifier.has("stat") and str(modifier.get("op","add")) in ["add","add_round","scale","pow"],"modifier readable: "+def.id)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=81;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false;arena.phase="upgrade"
	arena.player.set_physics_process(false)
	arena.abilities.slots=["grenade"]
	for def in defs:
		if def.preview=="" or def.id in Ammo.TYPES:continue  # ammo items show rolled values, not a stat preview
		for tier in range(3):
			var change=RunUpgrades.measure_change(arena,def,Balance.tier_power(tier))
			var before=RunUpgrades.measure(arena,def.preview)
			check(is_equal_approx(change[0],before),"preview does not change the run: "+def.id)
			RunUpgrades.apply(arena,def.id,tier)
			check(is_equal_approx(RunUpgrades.measure(arena,def.preview),change[1]),"preview equals applied value: %s tier %d" % [def.id,tier])
	var shown=CombatStats.probability(arena,"soldier",arena.run.weapon)*100
	check(RunUpgrades.preview_text(arena,"intercept",0).begins_with("Перехват: "+UiKit.number(shown)),"interception preview starts from the real chance")
	for i in range(40):RunUpgrades.apply(arena,"speed",2)
	check(not RunUpgrades.eligible(arena,UpgradeRegistry.get_def("speed")),"capped speed is not offered")
	check(is_equal_approx(arena.run.speed_multiplier,Balance.speed_multiplier_cap()),"speed stops at balance cap")
	for i in range(20):RunUpgrades.apply(arena,"intercept",2)
	check(not RunUpgrades.eligible(arena,UpgradeRegistry.get_def("intercept")),"capped interception is not offered")
	check(not RunUpgrades.eligible(arena,UpgradeRegistry.get_def("weapon_damage")),"weight 0 cards stay out of offers")
	arena.abilities.slots=[]
	check(not RunUpgrades.eligible(arena,UpgradeRegistry.get_def("device_power")),"device cards need an ability")
	RunUpgrades.apply(arena,"exit_dash",0)
	check("exit_dash" in arena.run.behavior_cards and not RunUpgrades.eligible(arena,UpgradeRegistry.get_def("exit_dash")),"behaviour card taken once")
	arena.run.elapsed=20;arena.effects.emit("vehicle_exit")
	check(is_equal_approx(arena.effects.modify("move_speed",1.0),1.25),"event bus drives behaviour effect")
	arena.run.elapsed=24
	check(is_equal_approx(arena.effects.modify("move_speed",1.0),1.0),"effect expires")
	arena.room.upgrade_offers.clear();arena.room.next_is_room=false;arena.reward.prepare_upgrade_offers()
	var ids=arena.room.upgrade_offers.map(func(o):return o.id)
	check(ids.size()==3 and ids.all(func(id):return UpgradeRegistry.has(id) and RunUpgrades.eligible(arena,UpgradeRegistry.get_def(id))),"offers are eligible registry cards")
	check(ids.size()==Array(ids).reduce(func(acc,id):return acc if id in acc else acc+[id],[]).size(),"offers do not repeat")
	arena.queue_free();await get_tree().process_frame
	await stats_behavior_checks()
	await effect_cards_checks()
	await legend_rules_checks()
	await feel_checks()
	Game.reset_upgrades();Campaign.configure(1)
	print("UPGRADE REGISTRY: %d failures" % failures);get_tree().quit(1 if failures else 0)

func new_arena(seed_value:=-1):
	var arena=load("res://scenes/arena.tscn").instantiate()
	if seed_value>=0:arena.run_seed=seed_value
	add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	return arena

# from stats_behavior_v19: shared stats for weapons, class health, owned/captured vehicles; three behaviour cards.
func stats_behavior_checks():
	Game.reset_upgrades();Campaign.configure(1)
	Game.selected_class="gunner";Game.class_levels.gunner=7;Game.health_level=3;Game.damage_level=4;Game.mobility_level=5
	var arena=new_arena(81);arena.phase="upgrade";arena.player.set_physics_process(false)
	check(is_equal_approx(arena.soldier_max_hp,CombatStats.initial_health()),"soldier health comes from CombatStats")
	for id in Game.LOOT.gun_ids():
		arena.weapon=id;arena.player.apply_weapon()
		var stats=CombatStats.weapon(arena);var preview=preload("res://scripts/ui/weapon_benchmarks.gd").current_weapon(arena)
		check(is_equal_approx(arena.player.damage,stats.damage) and is_equal_approx(arena.player.fire_interval,stats.interval),"weapon stats applied: "+id)
		check(is_equal_approx(preview.damage,stats.damage) and is_equal_approx(preview.rate,stats.rate),"weapon benchmark equals stats: "+id)
		var next=CombatStats.weapon(arena,"",{"damage_bonus":.5}).damage
		arena.reward.apply_trophy_upgrade("damage",0)
		check(is_equal_approx(arena.player.damage,next),"damage card preview equals application: "+id)
		check(is_equal_approx(CombatStats.probability(arena),arena.combat.current_intercept()),"interception chance is shared: "+id)
	for origin in ["owned","captured"]:
		var stats=GarageCatalog.stats("tank",arena,origin,2)
		var vehicle=arena.spawn_actor("tank",arena.find_free_near(Vector2i(4,4)),true,false,1,false,"",origin,2)
		var old=arena.player;arena.player=vehicle
		check(is_equal_approx(vehicle.damage,stats.damage) and is_equal_approx(vehicle.max_hp,stats.hp),"vehicle stats from catalog: "+origin)
		var next=GarageCatalog.stats("tank",arena,origin,2,{"damage_bonus":.5}).damage
		arena.reward.apply_trophy_upgrade("damage",0)
		check(is_equal_approx(vehicle.damage,next),"vehicle card preview matches application: "+origin)
		arena.player=old;arena.actors.erase(vehicle);vehicle.queue_free()
	# Выдержка: volley after 1.5 s of silence (+40%); Последний рубеж: +30% at <=25% health; Смена позиции: 3 s dash.
	arena.weapon="shotgun";arena.player.apply_weapon();arena.run.behavior_cards=["opening_shot","last_stand","exit_dash"];arena.run.elapsed=10
	arena.phase="combat";arena.combat.fire_weapon(arena.player)
	check(arena.projectiles.size()==Game.LOOT.WEAPONS.shotgun.pellets,"shotgun fires all pellets")
	check(arena.projectiles.all(func(bullet):return bullet.opening and is_equal_approx(bullet.damage,arena.player.damage)),"first volley after silence is an opening shot")
	arena.run.elapsed+=.1;arena.combat.fire_weapon(arena.player);check(not arena.projectiles.back().opening,"opening shot needs a pause")
	arena.run.elapsed+=1.6;arena.combat.fire_weapon(arena.player);check(arena.projectiles.back().opening,"opening shot returns after 1.5 s")
	var target=arena.spawn_actor("soldier",arena.find_free_near(Vector2i(2,2)),false);target.set_physics_process(false)
	var plain=arena.projectiles[arena.projectiles.size()-Game.LOOT.WEAPONS.shotgun.pellets-1]
	arena.run.crit_chance=0;arena.run.landing_until=0
	var full=CombatMods.outgoing(arena,plain,target)
	check(not plain.opening and is_equal_approx(CombatMods.outgoing(arena,arena.projectiles.back(),target),full*1.4),"opening shot deals +40%")
	arena.run.soldier_hp=arena.run.soldier_max_hp*.25;check(is_equal_approx(CombatMods.outgoing(arena,plain,target),full*1.3),"last stand +30% at 25% health")
	arena.run.soldier_hp=arena.run.soldier_max_hp;check(is_equal_approx(CombatMods.outgoing(arena,plain,target),full),"last stand off at full health")
	arena.actors.erase(target);target.queue_free()
	BehaviorCards.exited_vehicle(arena);check(BehaviorCards.speed_multiplier(arena)==1.25,"exit dash gives +25% speed")
	var expires=arena.run.dash_until;arena.run.elapsed+=1;BehaviorCards.exited_vehicle(arena);check(arena.run.dash_until==expires,"exit dash does not refresh while active")
	arena.run.elapsed+=3;check(BehaviorCards.speed_multiplier(arena)==1,"exit dash expires")
	arena.phase="upgrade";arena.room.upgrade_offers.clear();arena.reward.prepare_upgrade_offers()
	check(arena.room.upgrade_offers.all(func(o):return o.id not in arena.run.behavior_cards),"no duplicate behaviour cards")
	arena.queue_free();await get_tree().process_frame

func bullet_from(owner,damage:float):
	var b=load("res://scenes/projectile.tscn").instantiate();b.friendly=true;b.owner_actor=owner;b.damage=damage;return b

# from effect_cards_revision: bullet effects only from run cards, enhancements after the base card, chain fire, refund migration.
func effect_cards_checks():
	Game.reset_upgrades();Campaign.configure(1)
	Game.selected_class="recruit";Game.stat_levels={"burn_power":5,"shock_power":5,"stun_power":5}
	var arena=new_arena(23)
	var player=arena.player;player.set_physics_process(false);var run=arena.run
	check(run.burn_chance==0.0 and run.stun_chance==0.0 and run.shock_bonus==0.0,"maxed station effects do not switch effects on")
	check(is_equal_approx(run.burn_power,.3) and is_equal_approx(run.stun_duration,.25) and is_equal_approx(run.shock_power,.25),"station gives small base strength")
	var tank=arena.spawn_actor("tank",Vector2i(6,1),false);tank.set_physics_process(false);tank.hp=999;tank.max_hp=999
	run.crit_chance=0.0
	var probe=bullet_from(player,1.0)
	check(is_equal_approx(CombatMods.outgoing(arena,probe,tank),1.0),"station EMP alone adds no damage to machines");probe.free()
	for id in ["burn_heat","burn_long","chain_fire","stun_long","stun_often","crit_stun","shock_overload","shock_short","shock_arc"]:
		check(not RunUpgrades.eligible(arena,UpgradeRegistry.get_def(id)),id+" waits for its base card")
	for id in ["burn","stun","shock"]:check(RunUpgrades.eligible(arena,UpgradeRegistry.get_def(id)),id+" base card is offered")
	RunUpgrades.apply(arena,"burn",0)
	check(Ammo.active(run)=="burn","base card loads incendiary ammo")
	check(RunUpgrades.eligible(arena,UpgradeRegistry.get_def("burn_heat")) and RunUpgrades.eligible(arena,UpgradeRegistry.get_def("chain_fire")),"fire enhancements open after the base card")
	check(not RunUpgrades.eligible(arena,UpgradeRegistry.get_def("stun_long")),"other effects stay closed")
	var enemy=arena.spawn_actor("soldier",Vector2i(3,1),false);enemy.set_physics_process(false);enemy.hp=999;enemy.max_hp=999
	CombatMods.ignite(enemy,2.0,run)
	check(is_equal_approx(enemy.burn_dps,2.0*.35*1.3) and is_equal_approx(enemy.burn_time,3.0),"station heat raises burn damage")
	RunUpgrades.apply(arena,"burn_long",0);enemy.burn_time=0;CombatMods.ignite(enemy,2.0,run)
	check(enemy.burn_time>3.0,"long flame burns longer")
	var near=arena.spawn_actor("soldier",Vector2i(3,2),false);near.set_physics_process(false);near.hp=999;near.max_hp=999;near.position=enemy.position+Vector3(.6,0,0)
	for i in range(60):enemy.burn_time=3.0;enemy.burn_tick=0;CombatMods.tick_burn(enemy,.1)
	check(near.burn_time<=0,"without chain fire the fire does not spread")
	RunUpgrades.apply(arena,"chain_fire",1)
	for i in range(60):enemy.burn_time=3.0;enemy.burn_tick=0;CombatMods.tick_burn(enemy,.1)
	check(near.burn_time>0,"chain fire spreads to a neighbour")
	RunUpgrades.apply(arena,"shock",0)
	probe=bullet_from(player,1.0)
	check(is_equal_approx(CombatMods.outgoing(arena,probe,tank),1.0+float(Ammo.item(run).stats.bonus)+run.shock_power),"EMP item plus station power");probe.free()
	check(not ClassCatalog.info("gunner").modifiers.any(func(m):return m.stat in ["burn_chance","stun_chance","shock_bonus"]),"gunner has no default effect")
	var schema=preload("res://scripts/profile/schema.gd")
	var old=Game.serialize_progress();old.version=12;old.credits=100;old.notifications=[];old.stat_levels={"burn_chance":2,"stun_chance":1,"crit_chance":3}
	var migrated=schema.validate(old)
	check(migrated.ok and int(migrated.data.credits)==100+70+105+80,"old effect levels refunded: %s" % str(migrated.data.get("credits")))
	check(migrated.ok and not migrated.data.stat_levels.has("burn_chance") and int(migrated.data.stat_levels.crit_chance)==3,"other station levels kept")
	check(migrated.ok and migrated.data.notifications.size()==1,"player is told about the refund")
	Game.stat_levels={}
	arena.queue_free();await get_tree().process_frame

func legend_enemy(arena,kind:String,cell:Vector2i,hp:=20.0):
	var a=arena.spawn_actor(kind,cell,false);a.set_physics_process(false);a.hp=hp;a.max_hp=hp;return a

# from legend_rules_revision: legendary rules only from the command post, one post per route, each rule works.
func legend_rules_checks():
	Game.reset_upgrades();Campaign.configure(1)
	var ids=preload("res://scripts/legend_stop.gd").legendary_ids()
	check(ids.size()==8,"eight legendary rules")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=11;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().process_frame;arena.set_physics_process(false);arena.phase="combat"
	check(not ids.any(func(id):return RunUpgrades.eligible(arena,UpgradeRegistry.get_def(id))),"legends never appear in ordinary offers")
	var plans=0
	for seed_value in range(20):
		var plan=RoutePlan.build(seed_value);var posts=0
		for stage in plan:
			for node in stage:if node.type=="command_post":posts+=1
		if posts==1:plans+=1
	check(plans==20,"every world 1 route has one captured command post")
	var g=Vector2i(arena.grid_size/2,4)
	RunUpgrades.apply(arena,"legend_fury",3);for i in 4:arena.effects.emit("kill",{"actor":null})
	check(is_equal_approx(arena.effects.modify("shot_damage",1.0),1.2),"fury: +5% per kill")
	RunUpgrades.apply(arena,"legend_second_wind",3);var hero=arena.player;hero.hp=1.0;hero.invulnerable=0
	hero.take_damage(5.0);check(not hero.dead and is_equal_approx(hero.hp,1.0),"second wind saves a lethal hit once per field")
	RunUpgrades.apply(arena,"legend_detonator",3);var a=legend_enemy(arena,"soldier",g);var b=legend_enemy(arena,"soldier",g+Vector2i(1,0));b.position=a.position+Vector3(.6,0,0)
	arena.effects.emit("kill",{"actor":a});check(b.hp<20.0,"detonator hurts neighbours")
	RunUpgrades.apply(arena,"legend_ricochet",3);var c=legend_enemy(arena,"soldier",g+Vector2i(0,2));var hp_c=c.hp
	for i in 3:arena.effects.emit("enemy_hit",{"target":a,"damage":5.0})
	check(c.hp<hp_c or b.hp<20.0-1.5,"every third hit ricochets")
	var tank=arena.spawn_actor("tank",g+Vector2i(3,3),true);tank.set_physics_process(false);arena.room.player=tank
	RunUpgrades.apply(arena,"legend_iron_will",3);arena.effects.emit("vehicle_shot",{"actor":tank})
	check(is_equal_approx(arena.effects.modify("incoming_damage",10.0,{"actor":tank}),3.0),"iron will: -70% while firing")
	RunUpgrades.apply(arena,"legend_field_workshop",3);tank.hp=tank.max_hp-2;var before=tank.hp
	for i in 4:arena.effects.emit("tick",{"delta":1.0})
	check(tank.hp>before,"workshop on wheels repairs armour")
	RunUpgrades.apply(arena,"legend_volley",3);var shells=[0]
	arena.child_entered_tree.connect(func(n):if n.get("friendly")==true:shells[0]+=1)
	arena.effects.emit("vehicle_shot",{"actor":tank});check(shells[0]==2,"volley adds two shells")
	RunUpgrades.apply(arena,"legend_ram",3);var victim=legend_enemy(arena,"soldier",tank.cell);victim.position=tank.position;tank.moving=true
	arena.effects.emit("tick",{"delta":.016});check(victim.hp<=0 or victim.dead,"ram crushes infantry")
	arena.queue_free();await get_tree().process_frame

# from feel_revision: mercy hit, rare-card pity, kill series.
func feel_checks():
	Game.reset_upgrades();Campaign.configure(1)
	var arena=new_arena();arena.begin_room(1);arena.phase="combat"
	var p=arena.player;p.hp=3;arena.soldier_hp=3;p.invulnerable=0
	p.take_damage(10)
	check(not p.dead and is_equal_approx(p.hp,1.0) and arena.run.mercy_used,"first lethal hit leaves 1 HP")
	p.invulnerable=0;p.take_damage(10)
	check(p.dead,"second lethal hit kills")
	arena.queue_free()
	var arena2=new_arena();arena2.begin_room(0);arena2.phase="combat"
	var dry_max=0;var pity_ok=true
	for i in range(40):
		var before=arena2.run.dry_offers
		var offers=RunUpgrades.roll_offers(arena2,3)
		if before>=2:pity_ok=pity_ok and offers.any(func(o):return o.tier>=1)
		dry_max=maxi(dry_max,arena2.run.dry_offers)
	check(pity_ok,"third dry screen guarantees a rare")
	check(dry_max<=2,"never more than two dry screens in a row")
	arena2.run.series=0;arena2.run.series_at=-10
	var dummy=arena2.spawn_actor("soldier",Vector2i(2,2),false);dummy.set_physics_process(false)
	var labels=func():return arena2.get_children().filter(func(n):return n is Label3D and n.text.begins_with("×")).size()
	for i in range(3):arena2.reward.kill_series(dummy)
	check(arena2.run.series==3 and labels.call()>=2,"kill series shows ×N")
	arena2.elapsed+=5;arena2.reward.kill_series(dummy)
	check(arena2.run.series==1,"series resets after a pause")
	arena2.queue_free();await get_tree().process_frame
