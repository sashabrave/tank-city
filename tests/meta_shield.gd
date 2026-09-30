extends Node
var failures=0
func check(ok,message):
	if not ok:failures+=1;push_error(message)
	else:print("PASS: ",message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades();Game.credits=10000
	for branch in ["health","damage","luck","turret"]:
		for i in range(20):check(Game.purchase(branch),"purchase %s %d" % [branch,i+1])
		check(not Game.purchase(branch),"level cap "+branch)
	check(Game.credits==6000,"full profile costs 4000 alloy")
	check(Game.meta_damage()==5 and is_equal_approx(Game.turret_damage(),1.5),"max damage values")
	check(is_equal_approx(Game.heart_chance(),.16) and is_equal_approx(Game.bonus_chance(),.22),"max drop values")
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat"
	check(arena.soldier_max_hp==23 and arena.player.damage==6 and arena.base_max_hp==9,"max profile soldier")
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
	arena.soldier_hp=22;arena.player.hp=22
	arena.drop_pickup(arena.base_cell,"heart");arena.collect_pickup(arena.pickups.back())
	check(arena.player.hp==23 and arena.soldier_hp==23,"heart heals soldier")
	arena.drop_pickup(arena.base_cell,"heart");arena.collect_pickup(arena.pickups.back());check(arena.player.hp==23,"heart cannot exceed cap")
	var ally=arena.spawn_actor("mortar",Vector2i(0,2),false,true);arena.throw_grenade(ally,Vector3.ZERO)
	check(is_equal_approx(arena.grenades.back().damage,1.5),"allied mortar inherits slow meta upgrade")
	var rng=RandomNumberGenerator.new();rng.seed=42;var hearts=0;var bonuses=0
	for i in range(10000):
		if rng.randf()<Game.heart_chance():hearts+=1
		if rng.randf()<Game.bonus_chance():bonuses+=1
	check(hearts>1500 and hearts<1700 and bonuses>2050 and bonuses<2350,"drop probabilities within expected range")
	Game.save_path="res://tmp/meta-test.json";Game.save_enabled=true;Game.save_progress()
	Game.luck_level=0;Game.turret_level=0;Game.load_progress();check(Game.luck_level==20 and Game.turret_level==20,"new branches persist")
	Game.reset_upgrades();Game.credits=99;Game.health_level=3;Game.load_progress()
	check(Game.credits==0 and Game.health_level+Game.damage_level+Game.luck_level+Game.turret_level==0,"full reset persists zero currency and all branches")
	DirAccess.remove_absolute(Game.save_path);Game.save_enabled=false
	arena.free();print("META/SHIELD failures: ",failures);get_tree().quit(failures)
