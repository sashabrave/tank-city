extends Node
var failures=0
func check(ok,message):
	if not ok:failures+=1;push_error(message)
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
	arena.free();print("META/SHIELD failures: ",failures);get_tree().quit(failures)
