extends Node
## One field engine, step 1 (guides/02_development/07_one_world.md): the upgrade rooms and the merchant are the run's
## Arena in service mode. A run card and the loaded ammo change the hero's shot the same way in battle and in a room
## (the same actor numbers, the same Gun.stats, the same bullet damage on a target), an ability cast in a room is the
## battle's RunAbility with the same cooldown, the room's props block like walls, the hero takes no damage there and
## his vehicle waits for the next field. Profile and settings writes are off.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
## The hero's shot right now: cooldown after a pull, the volley's bullet damage, what a fixed roll deals to `target`.
func shot(arena,target)->Dictionary:
	var hero=arena.player
	hero.fire_cooldown=0.0;hero.turn_left=0.0
	var flying=arena.projectiles.size()
	hero.shoot()
	var bullet=arena.projectiles[flying] if arena.projectiles.size()>flying else null
	var result={"cooldown":hero.fire_cooldown,"interval":hero.fire_interval,"damage":hero.damage,"gun":Gun.stats(arena).damage,"bullet":bullet.damage if bullet else -1.0,"ammo":Ammo.effective(arena).duplicate(true)}
	if bullet and is_instance_valid(target):
		arena.run.combat_rng.seed=99;result["hit"]=CombatMods.outgoing(arena,bullet,target)
	for b in arena.projectiles.duplicate():
		if is_instance_valid(b):b.consume()
	return result
func same(a:Dictionary,b:Dictionary,keys:Array)->bool:
	for key in keys:
		if typeof(a[key])==TYPE_FLOAT:
			if not is_equal_approx(a[key],b[key]):return false
		elif a[key]!=b[key]:return false
	return true
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=41;add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	await get_tree().process_frame
	arena.player.set_physics_process(false);arena.phase="combat"
	arena.run.weapon="pistol";arena.run.weapon_stats={};Ammo.ensure(arena.run,"pistol");RunUpgrades.refresh_player(arena)
	# A run card and a loaded ammo item, taken in battle.
	var base_interval=arena.player.fire_interval
	RunUpgrades.apply(arena,"fire",1)
	Ammo.load_item(arena.run,Ammo.roll("ap",2,7));RunUpgrades.refresh_player(arena)
	var enemy=arena.spawn_actor("soldier",arena.find_free_near(Vector2i(2,2)),false)
	var battle=shot(arena,enemy)
	check(battle.bullet>0 and battle.ammo.type=="ap" and battle.interval<base_interval and is_equal_approx(battle.cooldown,battle.interval/arena.effects.modify("fire_rate",1.0)),"battle: the card shortens the pause, the ap rounds are loaded")
	arena.abilities.slots=["grenade"];arena.abilities.states.clear();arena.abilities.selected="";arena.abilities.select("grenade");arena.abilities.cooldown=0.0
	check(arena.abilities.cast_slot(0),"battle: the grenade is thrown")
	var battle_cooldown=arena.abilities.cooldown
	# The instructor's room on the same arena.
	var room=load("res://scripts/service_room.gd").new();room.branch="ability"
	arena.begin_service(2,room);await get_tree().process_frame
	arena.player.set_physics_process(false)
	check(arena.peaceful() and arena.room.mode=="service" and arena.playground==room and room.get_parent()==arena,"the room is the arena in service mode with the room as its playground")
	check(room.avatar==arena.player and arena.player.kind=="soldier" and arena.player.player_owned,"the room hero is the arena's own hero actor")
	check(not room.targets.is_empty() and room.targets.all(func(t):return t in arena.room.actors and not t.player_owned),"the instructor's stands are real targets on the field")
	var target=room.targets[0]
	var in_room=shot(arena,target)
	check(same(battle,in_room,["cooldown","interval","damage","gun","bullet"]),"one system: «Темп огня» gives the same pause and damage in battle and in the room (%.3f / %.3f s, %.3f / %.3f)" % [battle.cooldown,in_room.cooldown,battle.bullet,in_room.bullet])
	check(battle.ammo==in_room.ammo and is_equal_approx(battle.hit,in_room.hit),"one system: the loaded ammo hits a room target exactly like an enemy (%.3f / %.3f)" % [battle.hit,in_room.hit])
	# A real hit on the stand: the arena's bullet code, the stand never falls.
	var hero=arena.player;hero.fire_cooldown=0.0;hero.turn_left=0.0;var flying=arena.projectiles.size();hero.shoot()
	var bullet=arena.projectiles[flying];bullet.position=target.position;target.hp=target.max_hp
	arena.run.combat_rng.seed=99;var expected=CombatMods.outgoing(arena,bullet,target)
	target.hp=target.max_hp;arena.run.combat_rng.seed=99
	arena.bullet_hit(bullet)
	check(is_equal_approx(target.max_hp-target.hp,minf(expected,target.max_hp)),"a room bullet hits the stand through the battle's bullet code")
	bullet.consume()
	target.take_damage(target.max_hp*5)
	check(not target.dead and target.hp==target.max_hp and target in arena.room.actors,"a practice target never falls: it refills")
	# A card taken in the room changes the hero at once — and the next field keeps it.
	var before=arena.player.fire_interval
	RunUpgrades.apply(arena,"fire",1)
	var after=arena.player.fire_interval
	check(after<before,"a card taken in the room changes the hero at once (%.3f → %.3f)" % [before,after])
	# The ability in the room is the same RunAbility: same cast, same cooldown.
	arena.abilities.cooldown=0.0;var grenades=arena.grenades.size()
	check(arena.abilities.cast_slot(0) and arena.grenades.size()==grenades+1,"the grenade flies in the room through RunAbility")
	check(is_equal_approx(arena.abilities.cooldown,battle_cooldown),"the ability cooldown is the battle's (%.2f / %.2f s)" % [arena.abilities.cooldown,battle_cooldown])
	# No damage to the hero, props are solid, the exit opens with the choice.
	var hp=arena.player.hp;arena.player.take_damage(3.0,Vector3.ZERO,"","bullet")
	check(arena.player.hp==hp,"nothing hurts the hero in a room")
	check(not arena.can_stand(Vector3(0,0,-1),arena.player) and not arena.can_stand(RoomLayout.WEAPON_CRATE,arena.player),"the station and the crate block like walls")
	var exit=Vector3(room.dressing.EXIT_CELL.x,0,room.dressing.EXIT_CELL.y)
	check(not arena.can_stand(exit,arena.player),"the exit is closed before the choice")
	room.skip_choice()
	check(room.claimed and arena.can_stand(exit,arena.player),"the exit cell opens on the field after the choice")
	# The hero's vehicle from the field before waits for the next one.
	var garage=load("res://scripts/service_room.gd").new();garage.branch="vehicle"
	arena.end_service();arena.begin_room(3);arena.set_physics_process(false);await get_tree().process_frame
	var cell=arena.find_free_near(arena.player.cell);arena.player.queue_free();arena.room.actors.erase(arena.player)
	arena.player=arena.spawn_actor("buggy",cell,true);arena.player.hp=2.0
	arena.begin_service(4,garage);await get_tree().process_frame
	check(arena.player.kind=="soldier" and arena.hero_kind()=="buggy" and garage.vehicle=="buggy","in the room the hero walks; his buggy waits outside")
	var saved=preload("res://scripts/profile/run_checkpoint.gd").capture(arena,4,"map",{})
	check(saved.hero.kind=="buggy" and is_equal_approx(float(saved.hero.hp),2.0),"the checkpoint after a room keeps the buggy and its armour")
	arena.end_service();arena.begin_room(5);await get_tree().process_frame
	var parked=arena.wrecks.filter(func(w):return is_instance_valid(w) and w.kind=="buggy" and not w.spent)
	check(parked.size()==1 and arena.player.kind=="soldier","the buggy is parked at the start of the next field")
	check(arena.room.mode=="battle" and arena.playground==null and not arena.peaceful(),"the next field is a battle again")
	arena.queue_free();await get_tree().process_frame
	await hub_practice()
	print("ONE FIELD: failures=",failures)
	get_tree().quit(1 if failures else 0)

## Step 2: the hub is the practice run's arena (hub mode). The practice hero starts exactly as a sortie would start
## from the same hub loadout; a run card, ammo and an ability act the same in the hub, in a room and in battle; a
## station change reaches the practice hero at once; the hub's tank is the VehicleSystem's machine.
func start_state(field)->Dictionary:
	var hero=field.player
	return {"gun":Gun.stats(field).duplicate(),"damage":hero.damage,"interval":hero.fire_interval,"hp":hero.max_hp,"speed":CombatStats.soldier_speed(field.run),
		"slots":field.abilities.slots.duplicate(),"ability":ability_interval(field),"modules":field.headquarters.modules.duplicate(),"weapon":field.weapon,"crit":field.run.crit_chance}
func ability_interval(field)->float:
	if field.abilities.slots.is_empty():return 0.0
	field.abilities.select(field.abilities.slots[0]);return field.abilities.interval()
func hub_practice():
	Game.reset_upgrades();Campaign.configure(1)
	Engine.set_meta("hub_calls_off",true)
	for id in ["weapons","range","yard","garage","headquarters"]:
		if id not in Game.built_workshops:Game.built_workshops.append(id)
	Game.weapon_unlocks=Game.LOOT.gun_ids();Game.selected_weapon="rifle"
	Game.class_levels["recruit"]=4  # the class ability on Q (grenade) from class level 3
	Game.garage.owned=["tank"];Game.garage.selected="tank"
	var hub=preload("res://scripts/hub.gd").open_practice(self)
	await get_tree().create_timer(.8).timeout
	var practice=hub.arena
	practice.set_physics_process(false)
	check(practice.practice and practice.room.mode=="hub" and practice.peaceful() and practice.playground==hub and hub.get_parent()==practice,"the hub is a playground of a practice-run arena in hub mode")
	check(hub.avatar==practice.player and practice.player.kind=="soldier" and practice.player.player_owned,"the hub hero is the arena's own hero actor")
	check(get_tree().get_nodes_in_group("profile_hub").has(hub) and hub.phase=="combat","the hub keeps its stations' state (profile hub, phase)")
	# The same start as a sortie: a battle arena from the same profile gives the same hero, gun and abilities.
	var battle=load("res://scenes/arena.tscn").instantiate();battle.run_seed=43;battle.auto_pause_enabled=false;add_child(battle);battle.set_physics_process(false)
	await get_tree().process_frame
	var hub_start=start_state(practice);var battle_start=start_state(battle)
	check(str(hub_start)==str(battle_start),"one source: the practice hero starts as the sortie hero (%s / %s)" % [hub_start,battle_start])
	check(hub_start.slots.has("grenade") and hub_start.weapon=="rifle","the class ability and the Arsenal weapon are in the practice run")
	# The same card and ammo on both: identical pause, damage and hit on a target (the hub's range dummy / an enemy).
	check(is_instance_valid(hub.dummy) and hub.dummy in practice.room.actors and hub.dummy.has_meta("practice_target"),"the range dummy is a real practice target of the arena")
	for field in [practice,battle]:
		field.player.set_physics_process(false);field.phase="combat"
		RunUpgrades.apply(field,"fire",1)
		Ammo.load_item(field.run,Ammo.roll("ap",2,7));RunUpgrades.refresh_player(field)
	var enemy=battle.spawn_actor("soldier",battle.find_free_near(Vector2i(2,2)),false)
	var at_hub=shot(practice,hub.dummy);var at_battle=shot(battle,enemy)
	check(same(at_hub,at_battle,["cooldown","interval","damage","gun","bullet"]) and at_hub.ammo==at_battle.ammo,"one system: the card and ammo give the same pause and damage in the hub and in battle (%.3f / %.3f s, %.3f / %.3f)" % [at_hub.cooldown,at_battle.cooldown,at_hub.bullet,at_battle.bullet])
	check(is_equal_approx(at_hub.hit,at_battle.hit),"the hub dummy takes the same hit as an enemy (%.3f / %.3f)" % [at_hub.hit,at_battle.hit])
	# …and in a room on the battle's arena.
	var room=load("res://scripts/service_room.gd").new();room.branch="ability"
	battle.begin_service(2,room);await get_tree().process_frame
	battle.player.set_physics_process(false);RunUpgrades.refresh_player(battle)
	var at_room=shot(battle,room.targets[0])
	check(same(at_hub,at_room,["cooldown","interval","damage","gun","bullet"]) and is_equal_approx(at_hub.hit,at_room.hit),"one system: hub, room and battle shoot alike (%.3f / %.3f)" % [at_hub.bullet,at_room.bullet])
	# The class ability: the same RunAbility with the same cooldown.
	for field in [practice,battle]:
		field.abilities.select("grenade");field.abilities.cooldown=0.0
	var thrown=practice.grenades.size()
	check(practice.abilities.cast_slot(practice.abilities.slots.find("grenade")) and practice.grenades.size()==thrown+1,"Q in the hub throws the battle's grenade (RunAbility)")
	check(battle.abilities.cast_slot(battle.abilities.slots.find("grenade")) and is_equal_approx(practice.abilities.cooldown,battle.abilities.cooldown),"the ability cooldown is the same in the hub and on the field (%.2f / %.2f s)" % [practice.abilities.cooldown,battle.abilities.cooldown])
	battle.queue_free()
	# Nothing hurts the hero; the hangar walls are walls; the floor is walkable.
	var hp=practice.player.hp;practice.player.take_damage(3.0,Vector3.ZERO,"","bullet")
	check(practice.player.hp==hp,"nothing hurts the hero in the hub")
	check(not practice.can_stand(Vector3(2,0,-3),practice.player) and not practice.can_stand(Vector3(-4,0,1),practice.player) and practice.can_stand(Vector3(2,0,1),practice.player),"the back wall and the command centre block, the hangar floor is free")
	# A station change reaches the practice hero at once.
	var credits=Game.credits
	Game.selected_weapon="smg";hub.refresh()
	check(practice.weapon=="smg" and Gun.stats(practice).id=="smg" and practice.player.model.weapon_id=="smg","the Arsenal weapon reaches the practice hero at once")
	check(practice.run.upgrade_history.is_empty() and str(Ammo.effective(practice).type)=="standard","a station change rebuilds the practice run from the loadout (the card and ammo are gone)")
	var recruit_hp=practice.player.max_hp
	Game.selected_class="heavy";hub.refresh()
	check(not practice.abilities.slots.has("grenade") and not is_equal_approx(practice.player.max_hp,recruit_hp),"the Barracks class reaches the practice hero at once (abilities, health %.1f → %.1f)" % [recruit_hp,practice.player.max_hp])
	Game.selected_class="recruit";Game.selected_weapon="rifle";hub.refresh()
	var again=start_state(practice)
	check(str(again)==str(hub_start),"back to the first loadout: the practice hero is the first one again (%s)" % again)
	check(Game.credits==credits,"practice earns and spends nothing")
	# The hub's tank: the arena's VehicleSystem, the garage's stats.
	var parked=practice.wrecks.filter(func(w):return is_instance_valid(w) and w.kind=="tank" and not w.spent)
	check(parked.size()==1 and parked[0].get_meta("hub_parked",false),"the garage tank waits on the parking bay as a vehicle of the arena")
	Game.garage.levels["tank_gun"]=3;Game.garage.levels["tank_armor"]=2;hub.refresh()
	parked=practice.wrecks.filter(func(w):return is_instance_valid(w) and w.kind=="tank" and not w.spent)
	hub.place_hero(parked[0].position+Vector3(-1,0,0));hub.interact()
	var tank=practice.player;var garage=GarageCatalog.stats("tank",practice,"owned",1)
	check(tank.kind=="tank" and tank.player_owned and hub.riding(),"E boards the hub tank through VehicleSystem")
	check(is_equal_approx(tank.damage,garage.damage) and is_equal_approx(tank.fire_interval,garage.interval) and is_equal_approx(tank.max_hp,garage.hp) and is_equal_approx(tank.speed,garage.speed),"the hub tank has the garage's stats with upgrades (%.2f dmg, %.2f s, %.1f hp)" % [tank.damage,tank.fire_interval,tank.max_hp])
	tank.fire_cooldown=0.0;tank.turn_left=0.0;var flying=practice.projectiles.size()
	check(tank.shoot() and practice.projectiles.size()>flying and is_equal_approx(practice.projectiles[flying].damage,garage.damage),"the hub tank fires the battle's vehicle round")
	hub.interact()
	check(practice.player.kind=="soldier" and hub.on_foot(),"E again: out of the tank, on foot")
	# Freeing the hub frees its practice arena.
	hub.queue_free();await get_tree().process_frame;await get_tree().process_frame
	check(not is_instance_valid(practice),"the practice arena goes with the hub")
	Engine.remove_meta("hub_calls_off")
