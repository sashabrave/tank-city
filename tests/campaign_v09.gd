extends Node
var checks=0
var failures=0
func check(ok,msg):
	checks+=1
	if not ok:failures+=1;push_error(msg)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var total1=0;var total2=0
	for seed_value in range(300):
		for wave in range(3):
			total1+=WaveDirector.build(seed_value,5,wave).size();total2+=WaveDirector.build(seed_value,7,wave).size()
	check(absf(float(total2)/total1-1.2)<.025,"zone two population +20 percent")
	check(absf(float(total1)/(300*21)-1.075)<.02,"regular troops +7.5 percent")
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	for room in range(7,15):
		arena.begin_room(room);arena.player.set_physics_process(false)
		check(arena.grid_size==22+room-7 and arena.spawn_columns().size()==4,"zone two sizes/spawns "+str(room))
		check(not arena.walls.is_empty(),"zone two obstacles")
		arena.start_wave(2);check(arena.spawn_queue.size()>=9,"zone two wave quantity")
	arena.run_seed=43;arena.begin_room(15);check(arena.twin_boss,"zone two twin variant")
	var boss=arena.spawn_actor("boss",Vector2i(4,1),false);boss.set_physics_process(false);check(boss.max_hp==550,"second zone boss health")
	arena.phase="combat";boss.artillery_timer=0;arena.boss_extra_attacks(boss,.1);check(arena.grenades.size()==2,"twin area volley")
	arena.begin_room(16);arena.phase="combat";arena.player.set_physics_process(false)
	check(arena.grid_size==35 and arena.generators.size()==4,"citadel and four generators")
	boss=arena.spawn_actor("boss",Vector2i(15,2),false);boss.set_physics_process(false);var hp=boss.hp;boss.take_damage(50);check(boss.hp==hp,"generator shield blocks damage")
	for cell in arena.generators.keys():arena.damage_generator(cell,99)
	boss.take_damage(50);check(boss.hp==hp-50,"shield removed after four generators")
	boss.laser_timer=0;arena.boss_extra_attacks(boss,.1)
	var lasers=arena.get_children().filter(func(n):return n.get_script()==load("res://scripts/boss_lasers.gd"));check(lasers.size()==1 and lasers[0].count in [4,5,6],"laser count four to six")
	Game.cores=20;Game.select_class("gunner");check(Game.upgrade_class("gunner",false) and Game.upgrade_class("gunner",true),"class level and specialization purchasable")
	arena.queue_free();await get_tree().process_frame
	print("CAMPAIGN09: %d checks, %d failures; population ratio %.3f" % [checks,failures,float(total2)/total1]);get_tree().quit(1 if failures else 0)
