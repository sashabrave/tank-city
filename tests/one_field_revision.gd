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
	print("ONE FIELD: failures=",failures)
	get_tree().quit(1 if failures else 0)
