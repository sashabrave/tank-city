extends Node
var checks=0
var failures=0
func check(ok,msg):
	checks+=1
	if not ok:failures+=1;push_error(msg)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	# Wave size depends on the field, not the world; zone two fields bring rank two troops.
	var sizes1=[];var sizes2=[];var ranks2={}
	for world in [1,2]:
		Campaign.configure(world)
		for seed_value in range(100):
			for room in range(6):
				for wave in range(3):
					var roster=WaveDirector.build(seed_value,room,wave)
					(sizes1 if world==1 else sizes2).append(roster.size())
					for entry in roster:
						if world==2:ranks2[entry.rank]=true
	check(sizes1==sizes2,"zone two keeps per-field wave sizes")
	check(ranks2.keys()==[2],"zone two troops are rank two")
	Campaign.configure(2)
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	for room in range(6):
		arena.begin_room(room);arena.player.set_physics_process(false)
		check(arena.grid_size==Campaign.WORLDS[2].sizes[room] and arena.spawn_columns().size()==4,"zone two sizes/spawns "+str(room))
		check(not arena.walls.is_empty(),"zone two obstacles")
		arena.start_wave(2);check(arena.spawn_queue.size()>=WaveDirector.wave_size(room,2,arena.room.difficulty),"zone two wave quantity")
	var twin_seed=range(10).filter(func(seed_value):return BossCatalog.encounter(seed_value,6).count==2)[0]
	arena.run_seed=twin_seed;arena.begin_room(6);check(arena.twin_boss,"zone two twin variant")
	var boss=arena.spawn_actor("boss",Vector2i(4,1),false);boss.set_physics_process(false)
	check(is_equal_approx(boss.max_hp,Campaign.tuning().world_value(Campaign.tuning().world_boss_health,2)*BossCatalog.DATA.twins.hp),"second zone boss health")
	arena.queue_free();await get_tree().process_frame
	# Citadel generators and shield phases are covered in boss_campaign_revision.
	Campaign.configure(3)
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	arena.begin_room(7);arena.phase="combat";arena.player.set_physics_process(false)
	check(arena.grid_size==35 and arena.generators.size()==4,"citadel and four generators")
	# Class upgrades are paid in alloy (credits).
	check(Game.select_class("recruit"),"starting class selectable")
	Game.credits=Game.class_upgrade_cost("recruit",false)+Game.class_upgrade_cost("recruit",true);check(Game.upgrade_class("recruit",false) and Game.upgrade_class("recruit",true) and Game.credits==0,"class level and specialization purchasable")
	arena.queue_free();await get_tree().process_frame
	print("CAMPAIGN09: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
