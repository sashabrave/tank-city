extends Node
var failures=0
func check(ok,message):
	if not ok:failures+=1;print("FAIL: ",message);push_error(message)
	else:print("PASS: ",message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Game.credits=10000000
	# Current meta: health/damage are uncapped class levels with a rising price; luck and turret are bought
	# branches (turret needs the headquarters) capped at economy.branch_cap.
	Game.branch_unlocks.append_array(["damage","luck","turret"]);Game.built_workshops.append("headquarters")
	var spent=0;var cap=Balance.CONFIG.economy.branch_cap
	for branch in ["health","damage","luck","turret"]:
		for i in range(cap):
			var price=Game.cost(branch);check(Game.purchase(branch),"purchase %s %d" % [branch,i+1]);spent+=price
		if branch in ["luck","turret"]:check(not Game.purchase(branch),"level cap "+branch)
		else:check(Game.upgrade_cap(branch)>10000,"no level cap "+branch)
	check(Game.credits==10000000-spent,"every purchase charges its listed price")
	var e=Balance.CONFIG.economy
	check(Game.meta_damage()==cap*.25 and is_equal_approx(Game.turret_damage(),e.turret_damage+cap*e.turret_damage_per_level),"max damage values")
	check(is_equal_approx(Game.heart_chance(),e.heart_chance+cap*e.luck_per_level) and is_equal_approx(Game.bonus_chance(),e.bonus_chance+cap*e.luck_per_level),"max drop values")
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat"
	check(is_equal_approx(arena.soldier_max_hp,CombatStats.initial_health()) and arena.soldier_max_hp>=Balance.CONFIG.combat.hero_health+2*cap,"health levels raise soldier HP")
	check(is_equal_approx(arena.player.damage,CombatStats.weapon(arena).damage) and arena.player.damage>Game.LOOT.WEAPONS[arena.weapon].damage,"damage levels raise soldier damage")
	arena.player.health_label.set_health(1,4)
	check(is_equal_approx(arena.player.health_label.ratio,.25),"health bar uses proportional fill")
	var low=arena.player.health_label.texture.get_image().get_pixel(3,3)
	arena.player.health_label.set_health(4,4)
	var high=arena.player.health_label.texture.get_image().get_pixel(3,3)
	check(low.r>high.r and high.g>high.r,"health bar shifts red to green")
	var shield=arena.spawn_actor("shield",Vector2i(0,0),false);shield.set_physics_process(false);shield.facing=Vector2i.DOWN
	shield.shield_phase="raising";shield.shield_time=.55
	check(not shield.blocks_shot(Vector3.FORWARD),"raising shield remains vulnerable")
	shield.update_shield(.55)
	check(shield.blocks_shot(Vector3.FORWARD),"active shield blocks frontal shots")
	check(not shield.blocks_shot(Vector3.RIGHT) and not shield.blocks_shot(Vector3.BACK),"flank and rear bypass shield")
	shield.update_shield(1.1);check(not shield.blocks_shot(Vector3.FORWARD) and shield.shield_time==2.2,"shield cooldown exposes front")
	var top=arena.soldier_max_hp;arena.soldier_hp=top-1;arena.player.hp=top-1
	arena.drop_pickup(arena.base_cell,"heart");arena.collect_pickup(arena.pickups.back())
	check(arena.player.hp==top and arena.soldier_hp==top,"heart heals soldier")
	arena.drop_pickup(arena.base_cell,"heart");arena.collect_pickup(arena.pickups.back());check(arena.player.hp==top,"heart cannot exceed cap")
	var ally=arena.spawn_actor("mortar",Vector2i(0,2),false,true);arena.throw_grenade(ally,Vector3.ZERO)
	check(is_equal_approx(arena.grenades.back().damage,Game.turret_damage()),"allied mortar inherits turret meta upgrade")
	var rng=RandomNumberGenerator.new();rng.seed=42;var hearts=0;var bonuses=0
	for i in range(10000):
		if rng.randf()<Game.heart_chance():hearts+=1
		if rng.randf()<Game.bonus_chance():bonuses+=1
	check(absf(hearts-10000*Game.heart_chance())<150 and absf(bonuses-10000*Game.bonus_chance())<150,"drop probabilities within expected range")
	# Round trip only inside a fresh temporary folder (profile, backup and temp files).
	var dir=OS.get_temp_dir().path_join("warcats_meta_%d" % Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(dir)
	var restore={"path":Game.save_path,"selected":Game.profiles.selected,"blocked":Game.save_blocked}
	Game.save_path=dir.path_join("profile.json");Game.profiles.selected=true;Game.save_blocked=false;Game.save_enabled=true;Game.save_progress()
	Game.luck_level=0;Game.turret_level=0;Game.load_progress();check(Game.luck_level==cap and Game.turret_level==cap,"new branches persist")
	Game.reset_upgrades();Game.save_progress();Game.credits=99;Game.health_level=3;Game.load_progress()
	check(Game.credits==0 and Game.health_level+Game.damage_level+Game.luck_level+Game.turret_level==0,"full reset persists zero currency and all branches")
	for file in DirAccess.get_files_at(dir):DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir);Game.save_enabled=false;Game.save_path=restore.path;Game.profiles.selected=restore.selected;Game.save_blocked=restore.blocked
	arena.free()
	# from meta_gates_revision: no base-level gates; permanent upgrades stop only at fixed caps from economy.tres.
	Game.reset_upgrades()
	Game.progression.level=1;Game.credits=10000000;Game.cores=100
	Game.built_workshops=["weapons","headquarters","garage","bonuses","character"]
	Game.weapon_unlocks=["pistol","rifle"]
	for i in range(e.weapon_level_cap+2):Game.upgrade_weapon("rifle")
	check(Game.weapon_level("rifle")==e.weapon_level_cap,"weapon levels up to the fixed cap at base level 1")
	for i in range(e.insurance_cap+2):Game.buy_insurance()
	check(Game.progression.insurance==e.insurance_cap,"insurance up to its cap")
	Game.bonus_unlocks=["heart","repair"]
	for i in range(e.bonus_level_cap+2):Game.upgrade_bonus("repair")
	check(Game.bonus_level("repair")==e.bonus_level_cap,"bonus levels up to their cap")
	check(Game.upgrade_cap("heal")==e.branch_cap and Game.upgrade_cap("supplies")==e.supplies_cap,"branch caps are fixed")
	Game.ability_unlocks.append("laser")
	check(Game.ability_available("laser"),"late gadgets need only the blueprint")
	for id in HQCatalog.DATA:Game.hq_unlocks.append(id)
	check(HQCatalog.DATA.keys().all(func(id):return HQCatalog.available(id)) and HQCatalog.cap()==e.hq_level_cap,"every known HQ technology usable")
	Game.garage.unlocks=["vehicle_buggy","vehicle_apc","vehicle_tank"]
	check(Game.garage.buy("buggy") and Game.garage.buy("apc") and Game.garage.buy("tank"),"vehicles need only blueprint, order and price")
	check(Game.garage.cap("tank")==e.vehicle_equipment_cap,"vehicle equipment cap is fixed")
	# from shell_reset: the shell (general branches) refunds in full; class and camp levels stay.
	Game.reset_upgrades();Game.new_recipes.clear()
	Game.health_level=0;Game.damage_level=0;Game.mobility_level=0;Game.pressure_level=0
	Game.credits=10000;Game.class_levels={"recruit":2};Game.camp_level=2
	var bought=true
	for branch in ["health","health","damage","mobility","pressure"]:bought=Game.purchase(branch) and bought
	check(bought and Game.character_level()==5,"five shell levels bought")
	check(Game.shell_refund()==10000-Game.credits,"the refund equals what was spent")
	var returned=Game.reset_shell()
	check(returned>0 and Game.credits==10000 and Game.character_level()==0,"reset returns all the alloy and zeroes the shell")
	check(Game.class_levels=={"recruit":2} and Game.camp_level==2,"class and camp levels survive the shell reset")
	check(Game.reset_shell()==0 and Game.credits==10000,"a second reset returns nothing")
	var first_price=Game.cost("health")
	check(Game.purchase("health") and Game.character_level()==1 and Game.credits==10000-first_price,"the shell can be bought again at its first price")
	Game.reset_upgrades()
	print("META/SHIELD failures: ",failures);get_tree().quit(1 if failures else 0)
