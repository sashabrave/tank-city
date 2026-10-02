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
	assert(Game.hero_loadout().is_empty() and Game.hq_loadout().is_empty(),"No free starting abilities")
	Game.credits=30;assert(Game.buy_first_class_skill(Game.selected_class))
	assert(Game.class_loadout().size()==1)
	Game.class_levels[Game.selected_class]=5;Game.credits=2500
	assert(Game.buy_class_slot(Game.selected_class));assert(Game.class_loadout().size()==2)
	assert(Game.hero_loadout().size()<=3 and Game.hq_loadout().size()<=1)
	assert(Game.ability_action(0)=="class_ability" and Game.ability_action(1)=="skill_1" and Game.ability_action(2)=="ability")
	assert(Game.upgrade_cap("health")>10000)
	Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="upgrade"
	var reward=arena.reward
	assert(reward.START_EFFECTS.size()+BehaviorCards.DATA.size()==12)
	for id in reward.START_EFFECTS:
		var card=reward.upgrade_card({"id":id,"tier":0});assert(not card.title.is_empty())
	arena.run.range_multiplier=1.12;assert(arena.run.range_multiplier>1)
	var gallery=load("res://scripts/ui/class_gallery.gd").new();add_child(gallery)
	await get_tree().process_frame
	gallery.queue_free();arena.queue_free()
	var old_path=Game.save_path;Game.save_path="/tmp/tank_city_v16_test_save.json";Game.save_enabled=true
	Game.health_level=45;Game.save_progress();Game.health_level=0;Game.class_first_slots=[];Game.load_progress()
	assert(Game.health_level==45 and Game.selected_class in Game.class_first_slots,"Save preserves uncapped levels and purchases")
	Game.save_enabled=false;Game.save_path=old_path
	print("PASS v16 loadout, 12 cards, class gallery, quest acceptance and isolated save roundtrip")
	get_tree().quit()
