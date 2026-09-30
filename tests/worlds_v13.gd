extends Node3D
func _ready():call_deferred("run")
func check(value:bool,label:String):
	if not value:push_error("FAILED: "+label);get_tree().quit(1)
	assert(value,label)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	for world in range(1,4):
		Campaign.configure(world)
		for seed_value in range(300):
			var plan=RoutePlan.build(seed_value)
			check(plan.size()==Campaign.SIZES.size(),"world size")
			for stage in range(plan.size()):
				check(plan[stage].size()>=1 and plan[stage].size()<=3,"branch bounds")
				if stage==plan.size()-1:check(plan[stage].size()==1,"one final")
				else:
					for n in plan[stage]:check(not n.next.is_empty(),"no dead ends")
					for n in plan[stage+1]:check(plan[stage].any(func(source):return n.id in source.next),"all nodes reachable")
				for n in plan[stage]:check(RoutePlan.path_to(plan,stage,n.id).size()==stage+1,"complete path")
			for stage in Campaign.SERVICES:
				var services=Campaign.service_options(seed_value,stage)
				check(services.size()==2 and services[0]!=services[1],"two distinct service choices")
				for n in plan[stage-1]:check(n.next.size()==plan[stage].size(),"service joins every lane")
	print("PASS graphs: 900 maps")
	var p=Game.progression
	check(not Campaign.unlocked(2) and not Campaign.infinite_unlocked(),"initial world locks")
	p.complete_world(1);check(Campaign.unlocked(2) and Campaign.infinite_unlocked() and not Campaign.unlocked(3),"world unlock")
	p.complete_world(2);check(Campaign.unlocked(3),"third world unlock")
	var restored=load("res://scripts/progression/base_progression.gd").new();restored.restore(p.serialize().duplicate(true));check(restored.cleared_worlds==[1,2],"world persistence")
	p.prepare_telegrams();p.choose_telegram(0);var id=p.telegram.id;var goal=p.telegram.goal;var remaining=p.telegram.runs_left;var currency=Game.credits
	p.begin_run();p.combat_entered=true;p.event(p.telegram.event,1);p.end_run()
	check(p.telegram.id==id and p.telegram.progress==1 and p.telegram.runs_left==remaining-1,"order carries progress")
	p.begin_run();p.end_run();check(p.telegram.runs_left==remaining-1,"map-only exit costs no attempt")
	p.begin_run();p.combat_entered=true;p.event(p.telegram.event,goal);p.end_run()
	check(not p.telegram.is_empty() and p.telegram.progress==goal and Game.credits==currency,"ready waits for claim")
	check(p.claim_telegram() and Game.credits>currency and p.completed_orders.size()==1,"manual claim")
	p.choose_telegram(0);p.abandon_telegram();p.prepare_telegrams();check(p.telegram_options.is_empty(),"decline waits")
	p.begin_run();p.combat_entered=true;p.end_run();check(p.telegram_options.size()==3,"new order after sortie")
	p.choose_telegram(0);remaining=p.telegram.runs_left
	for i in range(remaining):p.begin_run();p.combat_entered=true;p.end_run()
	check(p.telegram.is_empty() and p.telegram_options.size()==3,"expiry regenerates offers")
	print("PASS quests: persistence, claim, expiry, decline")
	for world in range(1,4):
		Campaign.configure(world)
		var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
		arena.upgrade_offers.clear();arena.reward.prepare_upgrade_offers();check(not arena.upgrade_offers.any(func(o):return str(o.id).begins_with("hq_")),"no HQ battle cards")
		check(arena.reward.service_offers("headquarters").size()==3,"HQ service has three start options")
		var service=load("res://scripts/service_room.gd").new();service.arena=arena;service.branch="headquarters";add_child(service);service.claim(0);check(service.claimed,"HQ service claim");service.queue_free()
		var tiers=load("res://scripts/progression/recipe_tiers.gd")
		check((tiers.weight("sniper",12)>0)==(world>=2),"sniper world gate")
		check((tiers.weight("rpg",16)>0)==(world==3),"RPG world gate")
		arena.begin_room(Campaign.SIZES.size()-1);check(arena.grid_size==Campaign.SIZES.back(),"boss board size")
		arena.phase="combat";arena.boss_defeated=true;arena.room.pickups.clear();arena.flow.finish_wave()
		check(arena.phase=="result" and world in Game.progression.cleared_worlds,"world victory commits unlock")
		arena.queue_free();await get_tree().process_frame
	print("PASS arenas: all world finals / reward pools")
	Campaign.configure(1,true);var first=Campaign.hp_scale(0);Campaign.cycle=4;check(Campaign.hp_scale(0)>first,"endless grows")
	var save_path=Game.save_path;Game.save_path="/tmp/worlds_v13_profile.json";Game.save_enabled=true;Game.save_progress();Game.progression.cleared_worlds=[];Game.load_progress();Game.save_enabled=false;Game.save_path=save_path
	check(Game.progression.cleared_worlds==[1,2,3],"disk save preserves world unlocks")
	var main=load("res://scripts/main.gd").new();add_child(main);await get_tree().process_frame;await get_tree().process_frame
	Campaign.configure(1,true);main.start_run();main.enter_room(0);var carried=main.run_arena;carried.damage_bonus=2.5
	main.show_map(7);check(Campaign.cycle==1 and main.current.available==0 and main.run_arena==carried and carried.damage_bonus==2.5,"endless next sector preserves build")
	main.show_hub();await get_tree().process_frame;await get_tree().process_frame
	check(not is_instance_valid(main.run_arena),"safe hub return from map")
	main.queue_free();await get_tree().process_frame
	print("WORLDS V13 PASS")
	get_tree().quit()
