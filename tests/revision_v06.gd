extends Node
var checks=0
var failures=0
var arena
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	check(Game.branch_unlocks==["health"] and Game.weapon_unlocks==["pistol"] and Game.bonus_unlocks==["heart"] and Game.ability_unlocks==["barrier","shield"],"first entry unlocked in each workshop")
	Game.credits=1000;check(not Game.purchase("luck"),"locked stat cannot be upgraded")
	var before=Game.credits;check(Game.unlock_branch("luck") and Game.credits==before-Game.UNLOCK_COSTS.luck,"branch opens for a one-time price")
	check(Game.purchase("luck"),"unlocked stat upgrades normally")
	# Recipes: one per sortie backpack slot, early research first, then only the open tier, never a duplicate.
	var rng=RandomNumberGenerator.new();rng.seed=4
	for i in range(400):
		var pending=[];Game.discover_recipe(rng,pending);Game.bank_recipes(pending)
	var clean=Game.duplicate_recipes.is_empty() and ["weapons","headquarters","garage"].all(func(id):return id in Game.research_unlocks)
	for category in ["weapon","bonus","ability","hq"]:
		var owned=Game.recipe_owned(category)
		for id in Game.recipe_catalog(category):clean=clean and owned.count(id)<=1 and (id in owned or Game.TIERS.weight(id,0)==0)
	Game.new_recipes.clear()
	check(clean and Game.weapon_unlocks.size()>1 and Game.bonus_unlocks.size()>1,"open-tier recipes discoverable without duplicates")
	Game.credits=1000;Game.built_workshops.append("weapons")
	for i in range(Balance.CONFIG.economy.bonus_level_cap):check(Game.upgrade_bonus("heart"),"small bonus level purchased")
	check(not Game.upgrade_bonus("heart") and is_equal_approx(Game.bonus_power("heart"),1.0+Balance.CONFIG.economy.bonus_level_cap*.1),"bonus capped at small levels")
	# Profile round trip only inside a fresh temporary folder (profile, backups and slot index).
	var weapons=Game.weapon_unlocks.duplicate()
	Game.profiles.directory="/tmp/war-cats-rev06-%d" % Time.get_ticks_usec();DirAccess.make_dir_recursive_absolute(Game.profiles.directory);Game.profiles.active=1;Game.profiles.selected=true;Game.save_path=Game.profiles.path(1)
	Game.save_enabled=true;Game.save_progress();Game.weapon_unlocks=["pistol"];Game.bonus_unlocks=["heart"];Game.bonus_levels={};Game.load_progress()
	check(Game.weapon_unlocks==weapons and Game.bonus_level("heart")==Balance.CONFIG.economy.bonus_level_cap,"recipes and bonus levels persist")
	Game.save_enabled=false
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat";arena.spawn_queue.clear()
	for wall in arena.walls.values():wall.node.queue_free()
	arena.walls.clear();arena.trenches.clear()
	var flyer=arena.spawn_actor("flyer",Vector2i(0,0),false)
	arena.flyer_step(flyer,.1)
	var difference=flyer.flight_target-flyer.position
	check(is_zero_approx(difference.x) or is_zero_approx(difference.z),"flyer movement cardinal")
	flyer.flight_state="burst";flyer.flight_timer=0;var count=arena.projectiles.size();arena.flyer_step(flyer,.1)
	var shot=arena.projectiles.back()
	check(arena.projectiles.size()==count+1 and flyer.flight_state=="rest" and flyer.flight_shots==1,"one flyer shot then reposition")
	check(is_equal_approx(shot.speed,7.65) and (is_zero_approx(shot.travel_direction.x) or is_zero_approx(shot.travel_direction.z)),"flyer shot cardinal and ten percent slower")
	check(shot.flyer_round and shot.owner_actor==flyer,"flyer round flies over walls")
	arena.room_index=2;var first=arena.spawn_actor("soldier",Vector2i(1,1),false,false,2)
	arena.room_index=3;var second=arena.spawn_actor("soldier",Vector2i(2,1),false,false,2)
	check(Campaign.hp_scale(3)>Campaign.hp_scale(2) and is_equal_approx(second.hp/first.hp,Campaign.hp_scale(3)/Campaign.hp_scale(2)) and is_equal_approx(second.damage/first.damage,Campaign.damage_scale(3)/Campaign.damage_scale(2)),"same rank grows by the campaign field curve")
	Game.bonus_unlocks=["heart"];arena.room_index=2;arena.start_wave(0)
	check(arena.pickups.is_empty(),"locked turret absent from scheduled supplies")
	arena.start_wave(2);check(arena.pickups.is_empty(),"locked vehicle absent from scheduled supplies")
	arena.room_index=0;arena.spawn_room_boss();var elite=arena.actors.filter(func(a):return a.elite)[0]
	var peer=arena.spawn_actor(elite.kind,Vector2i(3,1),false,false,elite.rank)
	check(elite.footprint==1 and elite.model.scale==peer.model.scale and elite.speed==peer.speed,"miniboss retains ordinary size and movement")
	check(is_equal_approx(elite.max_hp,peer.max_hp*preload("res://scripts/systems/boss_system.gd").COMMANDER_HP[arena.room.difficulty]),"commander health scales from type by difficulty")
	var valid=true
	for room in range(6):
		for wave in range(3):
			for seed_value in range(100):
				var entries=WaveDirector.build(seed_value,room,wave);var cost=0
				for entry in entries:cost+=WaveDirector.rank_cost(entry.kind,entry.rank)
				valid=valid and entries.size()==WaveDirector.wave_size(room,wave)
	check(valid and Campaign.active_cap(0)==mini(Balance.CONFIG.campaign.active_cap,Balance.CONFIG.campaign.active_base+Campaign.world),"1800 waves match the tuned wave size; active cap follows the tuning")
	var shapes={};var colors={}
	for id in Game.LOOT.BONUSES:
		shapes[Game.LOOT.BONUSES[id].shape]=true;colors[Game.LOOT.BONUSES[id].color]=true;arena.drop_pickup(Vector2i.ZERO,id)
	var bonus_count=Game.LOOT.BONUSES.size()
	check(shapes.size()==bonus_count and colors.size()==bonus_count and arena.pickups.size()==bonus_count,"distinct bonus shapes, colors and pickups")
	Game.weapon_unlocks=["pistol"];arena.next_is_room=true;arena.phase="upgrade";arena.upgrade_offers.clear();arena.reward.prepare_upgrade_offers()
	check(not arena.upgrade_offers.is_empty() and arena.upgrade_offers.all(func(o):return o.id not in Game.LOOT.WEAPONS or o.id in Game.weapon_unlocks),"no unowned weapon offered without recipe")
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);hub.set_physics_process(false)
	await get_tree().create_timer(.8).timeout
	hub.avatar.position=hub.printer_pos+Vector3.FORWARD;hub.interact()
	check(is_instance_valid(hub.build_menu) and not hub.dpad.enabled,"bench opens a station and locks movement")
	hub.close_station();check(not is_instance_valid(hub.build_menu) and hub.dpad.enabled,"station closes")
	print("REV06: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
