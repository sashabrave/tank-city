extends Node
# Quests for world 1 and endless: no locked-world references, document rewards, new events, messenger feed.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	var Q=preload("res://scripts/progression/quest_catalog.gd")
	var all=Q.STORY+Q.INSTITUTE+Q.BRIEFINGS
	var stale=all.filter(func(q):return "мир 2" in (q.text+q.hint).to_lower() or "мир 3" in (q.text+q.hint).to_lower() or "цитадел" in (q.text+q.hint).to_lower() or "втором мире" in q.hint)
	check(stale.is_empty(),"no quest points to locked worlds %s" % str(stale.map(func(q):return q.id)))
	check(all.all(func(q):return q.has("docs")),"every quest states its document reward")
	for type in RoutePlan.CHALLENGES:check(Q.BRIEFINGS.any(func(q):return q.event=="challenge_"+type),"briefing for challenge "+type)
	check(Q.sender(Q.STORY[0])=="story" and Q.sender(Q.INSTITUTE[0])=="institute" and Q.sender(Q.BRIEFINGS[0])=="operations","senders")
	var p=Game.progression
	var quest=Q.STORY.filter(func(q):return q.id=="general1")[0]
	p.accepted.append(quest.id);p.event(quest.event,1,true);var cores=Game.cores;var credits=Game.credits
	check(p.claim(quest) and Game.credits==credits+quest.alloy+quest.docs*Game.DOC_ALLOY,"claim pays alloy with documents melted in")
	# Actions count only after taking the quest; one-shot story states count from the profile.
	p.event("extracted",50)
	var first=Q.STORY[0]
	check(p.count(first)==0 and not p.claim(first),"alloy carried before taking the quest does not count")
	if first.id not in p.accepted:p.accept_quest(first.id)
	p.quest_progress[first.id]=0
	p.event("extracted",first.goal)
	check(p.count(first)==first.goal and p.claim(first),"alloy carried after taking it completes the quest")
	Game.built_workshops.append("garage");p.sync()
	var garage=Q.BRIEFINGS.filter(func(q):return q.id=="garage_build")[0]
	check(p.count(garage)==1,"a bench built earlier still completes the story step")
	# One operations briefing at a time, in story order.
	p.counters["world_depth_1"]=6;p.counters["merchant_buy"]=1;p.counters["challenge_any"]=3
	var offered=p.quests("available").filter(func(q):return Q.sender(q)=="operations" and not str(q.id).begins_with("order_"))
	check(offered.size()==1 and offered[0].id==Q.BRIEFINGS[0].id,"one briefing offered: %s" % str(offered.map(func(q):return q.id)))
	p.accept_quest(offered[0].id)
	check(p.quests("available").filter(func(q):return q in Q.BRIEFINGS).map(func(q):return q.id)==[offered[0].id],"the taken briefing stays alone until handed in")
	var before=int(p.counters.get("challenge_any",0))
	Campaign.configure(1)
	var arena=preload("res://scripts/sandbox/sandbox_ground.gd").field({"mode":"hold","difficulty":2});add_child(arena);arena.set_physics_process(false);await settle()
	arena.challenges.complete(arena.player.position)
	check(int(p.counters.get("challenge_any",0))==before+1 and int(p.counters.get("challenge_hold",0))>=1 and int(p.counters.get("challenge_hard",0))>=1,"challenge success counts")
	RunUpgrades.apply(arena,"opening_shot",0)
	for i in range(5):RunUpgrades.apply(arena,"fire",0)
	check(int(p.counters.get("behavior_cards",0))>=1 and int(p.counters.get("card_stack",0))>=5,"card events count")
	# from progression_v16: run cards come from the UpgradeRegistry and every one renders a titled card.
	check(UpgradeRegistry.all().size()>=15,"the registry holds at least 15 run cards")
	var untitled=UpgradeRegistry.all().filter(func(def):return arena.reward.upgrade_card({"id":def.id,"tier":0}).title.is_empty()).map(func(def):return def.id)
	check(untitled.is_empty(),"every run card has a title %s" % str(untitled))
	# from adaptive_routes: a hidden enemy that idles too long wakes up and assaults.
	var phase_keep=arena.phase;arena.phase="combat"
	var enemy=arena.spawn_actor("soldier",Vector2i(3,1),false);enemy.set_physics_process(false);enemy.hidden_in_trench=true;enemy.idle_progress_time=13;enemy.route_points=[Vector2i(1,1)];enemy.movement_pause=5
	arena.enemy.attention_tick(enemy,.1)
	check(enemy.assault_time>0 and not enemy.hidden_in_trench and enemy.trench_return_delay>0 and enemy.route_points.is_empty() and enemy.movement_pause==0,"an idle hidden enemy leaves the trench and assaults")
	arena.phase=phase_keep
	arena.queue_free();await settle()
	# Messenger feed in the command centre: new messages on top.
	var memory=preload("res://scripts/ui/tablet_memory.gd");memory.loaded=true;memory.state={}
	var view=preload("res://scripts/ui/field_tablet.gd").new();view.manage=true;view.tab="quests";add_child(view);await settle()
	var feed=view.find_child("QuestFeed",true,false)
	check(feed!=null and feed.get_child_count()>0,"quest feed renders")
	var cards=feed.get_children().filter(func(c):return c.name.begins_with("Quest_"))
	check(not cards.is_empty() and cards[0].has_node("Bubble"),"quests are messages with bubbles")
	view.queue_free();await settle()
	# from hub_polish_v11: command centre news — fresh news, seen, a failed order is no news, quest progress is.
	Game.reset_upgrades();p=Game.progression
	check(p.has_news(),"a fresh profile has news");p.mark_seen();check(not p.has_news(),"seen news are gone")
	p.telegram_result="Оперштаб: приказ не выполнен.";check(not p.has_news(),"a failed order result is not news")
	p.accept_quest("first_alloy");p.mark_seen();p.event("extracted",30);check(p.has_news(),"progress on a taken quest is news")
	p.telegram_result=""

	# from progression_v16: quests show only once taken, the section «new» mark, acceptance survives a restore.
	Game.reset_upgrades();p=Game.progression
	check(p.quests().is_empty(),"unaccepted quests are hidden")
	check(p.accept_quest("first_alloy") and p.quests().size()==1,"an accepted quest is shown")
	check(p.section_new("quests"),"the quests section is marked new")
	p.view_section("quests");check(not p.section_new("quests"),"viewing the section clears the mark")
	p.event("alloy",1)
	var restored=load("res://scripts/progression/base_progression.gd").new();restored.restore(p.serialize())
	check("first_alloy" in restored.accepted,"accepted quests survive serialize/restore")
	# from progression_v16: tank pacing and commanders in 3 worlds × 100 seeds.
	var pacing_bad=[]
	for world in range(1,4):
		Campaign.configure(world)
		for seed_value in range(100):
			for field in range(Campaign.SIZES.size()-1):
				if field in Campaign.BOSSES:continue
				for wave in range(3):
					var tanks=WaveDirector.build(seed_value,field,wave).filter(func(e):return e.kind=="tank").size()
					if (tanks>0)!=WaveDirector.tanks_in_wave(field,wave) or tanks>WaveDirector.tank_limit(field,wave):pacing_bad.append("w%d s%d f%d wave%d tanks" % [world,seed_value,field,wave])
				var commander=RoutePlan.commander_kind(seed_value,field)
				if (field<2 and commander=="tank") or (field in [1,2] and commander not in ["buggy","apc"]) or (field==3 and commander not in ["grenadier","tank"]):pacing_bad.append("w%d s%d f%d commander %s" % [world,seed_value,field,commander])
	Campaign.configure(1)
	check(pacing_bad.is_empty(),"tank pacing, tank caps and commander tiers hold %s" % str(pacing_bad.slice(0,5)))
	# from progression_v16: the class path loadout.
	check(Game.class_loadout().is_empty() and Game.hq_loadout().is_empty(),"no abilities at the very start")
	Game.class_levels[Game.selected_class]=7;check(Game.class_loadout().size()==1,"class level 8: still one class ability, on Q")
	check(Game.hero_loadout().size()<=2 and Game.hq_loadout().size()<=1,"loadout limits: Q and the gadget")
	check(Game.ability_action(0)=="class_ability" and Game.ability_action(1)=="ability","ability slots map to their actions")
	check(Game.upgrade_cap("health")>10000,"health has no level cap")
	# from progression_v16: uncapped levels and class slots survive a save — only inside a fresh temporary folder.
	var dir=OS.get_temp_dir().path_join("warcats_quests_%d" % Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(dir)
	var restore={"path":Game.save_path,"selected":Game.profiles.selected,"blocked":Game.save_blocked}
	Game.save_path=dir.path_join("profile.json");Game.profiles.selected=true;Game.save_blocked=false;Game.save_enabled=true
	Game.health_level=45;Game.class_slots[Game.selected_class]=[Game.CLASS_CHOICES[Game.selected_class][0]]
	var saved=Game.save_progress();Game.health_level=0;Game.class_slots={};Game.load_progress()
	check(saved and Game.health_level==45 and Game.class_loadout()==[Game.CLASS_CHOICES[Game.selected_class][0]],"save keeps uncapped levels and the ability on Q")
	Game.save_enabled=false;Game.save_path=restore.path;Game.profiles.selected=restore.selected;Game.save_blocked=restore.blocked
	for file in DirAccess.get_files_at(dir):DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)

	# from adaptive_routes: operations orders adapt to recent sorties; a chosen order keeps its goal.
	Game.reset_upgrades();p=Game.progression
	var rng=RandomNumberGenerator.new();rng.seed=27
	var generator=load("res://scripts/progression/adaptive_orders.gd")
	var orders=generator.create(p,rng)
	check(orders.size()==3,"three orders offered")
	check(orders.all(func(q):return q.goal<=roundi(generator.BASE[q.event]*1.15)*2 and not q.has("vehicle")),"order goals stay within the doubled single-sortie cap, no vehicle orders")
	p.counters.depth=8;p.level=4;p.recent_sorties=[{"infantry":28,"waves":9,"drones":12},{"infantry":24,"waves":8,"drones":10}]
	rng.seed=27;var grown=generator.create(p,rng)
	check(grown[2].difficulty=="Сложный","a strong record makes the third order hard")
	p.telegram_options=grown;p.choose_telegram(2);var goal=p.telegram.goal;p.counters.depth=16;p.prepare_telegrams()
	check(p.telegram.goal==goal,"a chosen order keeps its goal")
	p.telegram={};p.begin_run();p.combat_entered=true;p.event("infantry",17);p.end_run()
	check(not p.recent_sorties.is_empty() and p.recent_sorties.back().infantry==17,"a sortie that reached combat is learned without a chosen order")
	Game.reset_upgrades()
	print("QUESTS: %d failures" % failures);get_tree().quit(1 if failures else 0)
