extends Node
var checks=0
var failures=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _ready():call_deferred("run_test")
func run_test():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;Game.reset_upgrades();var profile_research=Game.research_unlocks.duplicate()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.player.set_physics_process(false)
	var changes=[];arena.flow.changed.connect(func(previous,current):changes.append([previous,current]))
	arena.phase="combat";arena.pause_battle();arena.pause_battle()
	check(changes==[["countdown","combat"],["combat","paused"],["paused","combat"]],"single transition event per phase change")
	arena.phase="combat";check(changes.size()==3,"same phase does not emit twice")
	arena.damage_bonus=3.5;check(arena.run.damage_bonus==3.5,"compatibility write reaches run state")
	arena.run.damage_bonus=4.0;check(arena.damage_bonus==4.0,"run state reaches compatibility read")
	arena.weapon_mods.pistol.damage=.25;check(arena.run.weapon_mods.pistol.damage==.25,"nested dictionaries have one owner")
	var snapshot_script=load("res://scripts/ui/battle_snapshot.gd");var rng_state=arena.combat_rng.state
	arena.abilities.slots.append("shield");arena.abilities.select("shield");var slots=arena.abilities.slots.duplicate()
	var snapshot=snapshot_script.capture(arena);snapshot.hero_hp=-999;snapshot.skills.clear()
	check(arena.soldier_hp>0 and arena.abilities.slots==slots,"HUD snapshot cannot mutate domain state")
	check(arena.combat_rng.state==rng_state,"render snapshot does not consume random numbers")
	arena.next_is_room=false;arena.upgrade_offers.clear();arena.reward.prepare_upgrade_offers();var offers=arena.upgrade_offers.duplicate(true);rng_state=arena.combat_rng.state
	arena.reward.prepare_upgrade_offers();arena.hud.show_upgrades();arena.hud.show_upgrades()
	check(arena.upgrade_offers==offers and arena.combat_rng.state==rng_state,"reopening cards preserves reward and random stream")
	arena.pending_recipes=[{"category":"research","id":"rescue"}];arena.vehicle_mods.tank.damage=2;arena.abilities.select("barrier");arena.abilities.level.power=2
	# Next room: the first later stage whose default node is an ordinary battle.
	var plan=RoutePlan.build(arena.run_seed);var next_room=range(1,plan.size()).filter(func(s):return plan[s][0].type=="battle" and s not in Campaign.BOSSES)[0]
	var old_player=arena.player;arena.begin_room(next_room);arena.set_physics_process(false);arena.player.set_physics_process(false)
	check(arena.run.damage_bonus==4 and arena.pending_recipes.size()==1 and arena.vehicle_mods.tank.damage==2 and arena.abilities.level.power==2,"room transition preserves run progress")
	check(arena.room.room_index==next_room and arena.wave==0 and arena.phase=="countdown" and arena.room.generators.is_empty(),"new room initializes encounter")
	await get_tree().process_frame
	check(not is_instance_valid(old_player),"previous player scene released")
	var service=load("res://scripts/service_room.gd").new();service.arena=arena;service.index=4;service.branch="vehicle";add_child(service);service.set_physics_process(false)
	# The mechanic upgrades the vehicle the hero drives or will get (buggy when none).
	# The run seed is random here: take the damage card so the check does not depend on the draw.
	service.offers=[{"id":"damage","tier":0}]+service.offers
	var kind=service.vehicle;var before=arena.vehicle_mods[kind].damage;service.claim(0);var after=arena.vehicle_mods[kind].damage;service.claim(0)
	check(after>before and arena.vehicle_mods[kind].damage==after,"service reward remains one-time")
	check(arena.pending_vehicle==kind,"service delivery staged in run state")
	service.queue_free();arena.queue_free();await get_tree().process_frame
	var fresh=load("res://scenes/arena.tscn").instantiate();add_child(fresh);fresh.auto_pause_enabled=false;fresh.set_physics_process(false)
	check(fresh.damage_bonus==0 and fresh.pending_recipes.is_empty() and fresh.vehicle_mods.apc.damage==0,"new run isolates previous run data")
	check(Game.damage_level==0 and Game.research_unlocks==profile_research,"run upgrades do not leak into permanent profile")
	fresh.queue_free();await get_tree().process_frame
	await drone_cooldown_checks()
	print("REFACTOR STATE: ",checks," checks, ",failures," failures");get_tree().quit(1 if failures else 0)

# from drone_background_cooldown: background drone timer bounds, combat-only ticking, and its own RNG (battle RNG untouched).
func drone_cooldown_checks():
	Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false)
	for actor in arena.actors:actor.set_physics_process(false)
	arena.phase="combat";arena.room.surprise_initialized=false;arena.room.combat_elapsed=0;arena.surprises.start_wave()
	check(arena.room.surprise_timer>=15 and arena.room.surprise_timer<=30,"background drone: initial delay 15-30 seconds")
	arena.room.surprise_timer=0;arena.room.combat_elapsed=14.99
	var count=arena.actors.size();arena.surprises.tick(.01);check(arena.actors.size()==count,"background drone: none before 15 s of combat")
	arena.room.combat_elapsed=16;var combat_rng=arena.combat_rng.state
	arena.surprises.tick(.01);check(arena.actors.size()==count+1,"background drone: cooldown dispatches a drone")
	check(arena.room.surprise_timer>=18 and arena.room.surprise_timer<=30,"background drone: repeat cooldown 18-30 seconds")
	check(combat_rng==arena.combat_rng.state,"background drone randomness does not touch the battle RNG")
	var timer=arena.room.surprise_timer
	for phase in ["upgrade","paused","countdown"]:
		arena.phase=phase;arena.surprises.tick(10);check(arena.room.surprise_timer==timer,"background drone timer does not tick in "+phase)
	arena.room.wave=1;arena.surprises.start_wave();check(arena.room.surprise_timer==timer,"background drone: next wave keeps the cooldown")
	arena.queue_free();await get_tree().process_frame
