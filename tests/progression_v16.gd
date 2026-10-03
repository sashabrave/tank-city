extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	assert(Game.progression.quests().is_empty(),"Unaccepted quests hidden")
	assert(Game.progression.accept_quest("first_alloy"))
	assert(Game.progression.quests().size()==1,"Accepted quest shown")
	assert(Game.progression.section_new("quests"))
	Game.progression.view_section("quests");assert(not Game.progression.section_new("quests"))
	Game.progression.event("alloy",1)
	var restored=load("res://scripts/progression/base_progression.gd").new();restored.restore(Game.progression.serialize());assert("first_alloy" in restored.accepted)
	for world in range(1,4):
		Campaign.configure(world)
		for seed_value in range(100):
			for field in range(Campaign.SIZES.size()-1):
				if field in Campaign.BOSSES:continue
				for wave in range(3):
					var roster=WaveDirector.build(seed_value,field,wave)
					var tanks=roster.filter(func(e):return e.kind=="tank").size()
					assert((tanks>0)==WaveDirector.tanks_in_wave(field,wave),"Tank introduction pacing")
					assert(tanks<=WaveDirector.tank_limit(field,wave),"Tank cap")
				var commander=RoutePlan.commander_kind(seed_value,field)
				if field<2:assert(commander!="tank","No early tank commander")
				if field in [1,2]:assert(commander in ["buggy","apc"],"Light vehicle commanders")
				if field==3:assert(commander in ["grenadier","tank"],"Heavy tier reveal")
	print("PASS tank pacing: 3 worlds, 100 seeds each")
	# Meta stage 4: the class Q is free, the second ability opens at class level 3.
	assert(Game.class_loadout()==[Game.class_skill()] and Game.hq_loadout().is_empty(),"Only the class Q at start")
	Game.class_levels[Game.selected_class]=3;assert(Game.class_loadout().size()==2)
	assert(Game.hero_loadout().size()<=3 and Game.hq_loadout().size()<=1)
	assert(Game.ability_action(0)=="class_ability" and Game.ability_action(1)=="skill_1" and Game.ability_action(2)=="ability")
	assert(Game.upgrade_cap("health")>10000)
	Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="upgrade"
	var reward=arena.reward
	# Run cards come from the UpgradeRegistry (assets/balance/upgrades); every card renders a titled card.
	assert(UpgradeRegistry.all().size()>=15)
	for def in UpgradeRegistry.all():
		var card=reward.upgrade_card({"id":def.id,"tier":0});assert(not card.title.is_empty(),"Card has a title: "+def.id)
	arena.run.range_multiplier=1.12;assert(arena.run.range_multiplier>1)
	arena.queue_free()
	# Fresh temporary folder: the profile, its backup and temp files never touch real saves or older runs.
	var dir=OS.get_temp_dir().path_join("warcats_v16_%d" % Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(dir)
	var old_path=Game.save_path;Game.save_path=dir.path_join("profile.json");Game.save_enabled=true
	Game.health_level=45;Game.class_choices[Game.selected_class]=Game.CLASS_CHOICES[Game.selected_class][1];Game.save_progress();Game.health_level=0;Game.class_choices={};Game.load_progress()
	assert(Game.health_level==45 and Game.class_second()==Game.CLASS_CHOICES[Game.selected_class][1],"Save preserves uncapped levels and the class choice")
	Game.save_enabled=false;Game.save_path=old_path
	for file in DirAccess.get_files_at(dir):DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
	print("PASS v16 loadout, registry cards, class gallery, quest acceptance and isolated save roundtrip")
	get_tree().quit()
