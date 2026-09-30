extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	Game.selected_class="gunner";Game.class_levels.gunner=7;Game.health_level=3;Game.damage_level=4;Game.mobility_level=5
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=81;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false;arena.phase="upgrade"
	arena.player.set_physics_process(false)
	assert(is_equal_approx(arena.soldier_max_hp,CombatStats.initial_health()))
	for id in Game.LOOT.WEAPONS:
		arena.weapon=id;arena.player.apply_weapon()
		var stats=CombatStats.weapon(arena);var preview=preload("res://scripts/ui/weapon_benchmarks.gd").current_weapon(arena)
		assert(is_equal_approx(arena.player.damage,stats.damage) and is_equal_approx(arena.player.fire_interval,stats.interval))
		assert(is_equal_approx(preview.damage,stats.damage) and is_equal_approx(preview.rate,stats.rate))
		var next=CombatStats.weapon(arena,"",{"damage_bonus":.5}).damage
		arena.reward.apply_trophy_upgrade("damage",0)
		assert(is_equal_approx(arena.player.damage,next))
		assert(is_equal_approx(CombatStats.probability(arena),arena.combat.current_intercept()))
	for origin in ["owned","captured"]:
		var stats=GarageCatalog.stats("tank",arena,origin,2)
		var vehicle=arena.spawn_actor("tank",arena.find_free_near(Vector2i(4,4)),true,false,1,false,"",origin,2)
		var old=arena.player;arena.player=vehicle
		assert(is_equal_approx(vehicle.damage,stats.damage) and is_equal_approx(vehicle.max_hp,stats.hp))
		var next=GarageCatalog.stats("tank",arena,origin,2,{"damage_bonus":.5}).damage
		arena.reward.apply_trophy_upgrade("damage",0)
		assert(is_equal_approx(vehicle.damage,next),"Captured and owned card previews match application")
		arena.player=old;arena.actors.erase(vehicle);vehicle.queue_free()
	arena.weapon="shotgun";arena.player.apply_weapon();arena.run.behavior_cards=BehaviorCards.DATA.keys();arena.run.elapsed=10
	arena.phase="combat";arena.combat.fire_weapon(arena.player)
	assert(arena.projectiles.size()==Game.LOOT.WEAPONS.shotgun.pellets)
	for bullet in arena.projectiles:assert(is_equal_approx(bullet.damage,arena.player.damage*1.4))
	assert(BehaviorCards.shot_multiplier(arena)==1.0)
	arena.run.elapsed+=1.5;assert(BehaviorCards.shot_multiplier(arena)==1.4)
	arena.run.soldier_hp=arena.run.soldier_max_hp*.25;assert(BehaviorCards.rate_multiplier(arena)==1.25)
	arena.player.fire_cooldown=0;arena.player.turn_left=0;assert(arena.player.shoot())
	assert(is_equal_approx(arena.player.fire_cooldown,arena.player.fire_interval/1.25))
	arena.run.soldier_hp=arena.run.soldier_max_hp;assert(BehaviorCards.rate_multiplier(arena)==1)
	BehaviorCards.exited_vehicle(arena);assert(BehaviorCards.speed_multiplier(arena)==1.25)
	var expires=arena.run.dash_until;arena.run.elapsed+=1;BehaviorCards.exited_vehicle(arena);assert(arena.run.dash_until==expires)
	arena.run.elapsed+=3;assert(BehaviorCards.speed_multiplier(arena)==1)
	arena.phase="upgrade";arena.room.upgrade_offers.clear();arena.reward.prepare_upgrade_offers()
	assert(arena.room.upgrade_offers.all(func(o):return o.id not in BehaviorCards.DATA),"No duplicate behavior cards")
	arena.queue_free();await get_tree().process_frame
	print("PASS shared stats: weapons, class health, owned/captured vehicles, previews; 3 behavior triggers, timing and no duplicates")
	get_tree().quit()
