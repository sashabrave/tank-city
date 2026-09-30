extends Node
var checks=0
var failures=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _ready():call_deferred("run_test")
func run_test():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.player.set_physics_process(false)
	var changes=[];arena.flow.changed.connect(func(previous,current):changes.append([previous,current]))
	arena.phase="combat";arena.pause_battle();arena.pause_battle()
	check(changes==[["countdown","combat"],["combat","paused"],["paused","combat"]],"single transition event per phase change")
	arena.phase="combat";check(changes.size()==3,"same phase does not emit twice")
	arena.damage_bonus=3.5;check(arena.run.damage_bonus==3.5,"compatibility write reaches run state")
	arena.run.damage_bonus=4.0;check(arena.damage_bonus==4.0,"run state reaches compatibility read")
	arena.weapon_mods.pistol.damage=.25;check(arena.run.weapon_mods.pistol.damage==.25,"nested dictionaries have one owner")
	var snapshot_script=load("res://scripts/ui/battle_snapshot.gd");var rng_state=arena.combat_rng.state
	var snapshot=snapshot_script.capture(arena);snapshot.hero_hp=-999;snapshot.skills.clear()
	check(arena.soldier_hp>0 and arena.abilities.slots.size()==1,"HUD snapshot cannot mutate domain state")
	check(arena.combat_rng.state==rng_state,"render snapshot does not consume random numbers")
	arena.next_is_room=false;arena.upgrade_offers.clear();arena.reward.prepare_upgrade_offers();var offers=arena.upgrade_offers.duplicate(true);rng_state=arena.combat_rng.state
	arena.reward.prepare_upgrade_offers();arena.hud.show_upgrades();arena.hud.show_upgrades()
	check(arena.upgrade_offers==offers and arena.combat_rng.state==rng_state,"reopening cards preserves reward and random stream")
	arena.pending_recipes=[{"category":"research","id":"rescue"}];arena.vehicle_mods.tank.damage=2;arena.abilities.select("barrier");arena.abilities.level.power=2
	var old_player=arena.player;arena.begin_room(7);arena.set_physics_process(false);arena.player.set_physics_process(false)
	check(arena.run.damage_bonus==4 and arena.pending_recipes.size()==1 and arena.vehicle_mods.tank.damage==2 and arena.abilities.level.power==2,"room transition preserves run progress")
	check(arena.room.room_index==7 and arena.wave==0 and arena.phase=="countdown" and arena.room.generators.is_empty(),"new room initializes encounter")
	await get_tree().process_frame
	check(not is_instance_valid(old_player),"previous player scene released")
	var service=load("res://scripts/service_room.gd").new();service.arena=arena;service.index=4;service.branch="vehicle";add_child(service);service.set_physics_process(false)
	var before=arena.vehicle_mods.apc.damage;service.claim(0);var after=arena.vehicle_mods.apc.damage;service.claim(0)
	check(after>before and arena.vehicle_mods.apc.damage==after,"service reward remains one-time")
	check(arena.pending_vehicle=="apc","service delivery staged in run state")
	service.queue_free();arena.queue_free();await get_tree().process_frame
	var fresh=load("res://scenes/arena.tscn").instantiate();add_child(fresh);fresh.auto_pause_enabled=false;fresh.set_physics_process(false)
	check(fresh.damage_bonus==0 and fresh.pending_recipes.is_empty() and fresh.vehicle_mods.apc.damage==0,"new run isolates previous run data")
	check(Game.damage_level==0 and Game.research_unlocks.is_empty(),"run upgrades do not leak into permanent profile")
	fresh.queue_free();await get_tree().process_frame
	print("REFACTOR STATE: ",checks," checks, ",failures," failures");get_tree().quit(1 if failures else 0)
