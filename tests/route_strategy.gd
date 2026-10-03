extends Node3D
var checks=0
var failures=0
func check(ok:bool,msg:String):
	checks+=1
	if not ok:failures+=1;push_error(msg)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var patterns={}
	for seed_value in range(150):
		var plan=RoutePlan.build(seed_value)
		check(plan==RoutePlan.build(seed_value),"stable route seed")
		var incoming=plan[0].map(func(n):return n.id)
		var last=plan.size()-1
		for stage in range(plan.size()):
			var next=[]
			check(plan[stage].size() in ([1] if stage in Campaign.BOSSES else [3]),"three roads per field, one boss")
			var risks={}
			for info in plan[stage]:risks[info.difficulty]=true
			if plan[stage].size()>1:check(risks.size()>=2,"branch offers different risk")
			if stage in Campaign.BOSSES:check(plan[stage].size()==1 and plan[stage][0].elite,"major boss convergence")
			for info in plan[stage]:
				check(info.id in incoming,"node reachable from start")
				if stage<last:check(not info.next.is_empty(),"no dead ends")
				for id in info.next:
					check(plan[stage+1].any(func(n):return n.id==id),"edge only to next stage")
					next.append(id)
				if plan[stage].size()>1 and stage<last and plan[stage+1].size()>1:patterns[info.next.size()]=true
			incoming=next
	check(patterns.has(1) and patterns.has(2),"restricted and open crossings generated")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=42;add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	# Framing without the arrival swoop: overview during the countdown, normal size in combat.
	var presentation=arena.presentation
	if presentation.swoop_tween:presentation.swoop_tween.kill()
	presentation.swoop_weight=0;presentation._process(10)
	check(arena.phase=="countdown" and arena.camera.size>arena.grid_size+5,"countdown camera pulled out")
	arena.phase="combat";presentation._process(10)
	check(is_equal_approx(arena.camera.size,arena.grid_size+5),"combat camera returns to normal")
	# A regular battle field late in world 1 (challenge and service nodes have no commander).
	var field=5;arena.run.route_choices[field]=RoutePlan.build(42)[field].filter(func(n):return n.type=="battle")[0].id
	for difficulty in range(3):
		var elite=difficulty>0;var limit=[1,2,3][difficulty]
		arena.begin_room(field);arena.phase="combat";arena.room.difficulty=difficulty;arena.room.commander_elite=elite
		for actor in arena.actors:actor.set_physics_process(false)
		arena.spawn_room_boss();var commander=arena.room.commander;commander.set_physics_process(false)
		check(is_instance_valid(commander) and commander.commander_elite==elite,"commander matches risk")
		var pool=arena.room.commander_help_pool
		check(not pool.is_empty(),"strong wave helper pool")
		arena.boss.tick_commander_help(20)
		var helpers=arena.actors.filter(func(a):return a.commander_support)
		# Zone one: one helper per call; elite commanders in later zones call two.
		check(helpers.size()==1,"small reinforcement batch")
		for helper in helpers:
			helper.set_physics_process(false)
			check(pool.any(func(e):return e.kind==helper.kind),"helpers from room wave")
		for i in range(15):arena.boss.tick_commander_help(20)
		for helper in arena.actors:helper.set_physics_process(false)
		check(arena.actors.filter(func(a):return a.commander_support and not a.dead).size()<=limit,"live support cap by difficulty")
		for cycle in range(8):
			for helper in arena.actors.duplicate():
				if helper.commander_support:arena.actors.erase(helper);helper.free()
			arena.boss.tick_commander_help(30)
		check(arena.room.commander_help_waves==limit,"finite reinforcement wave budget by difficulty")
		commander.take_damage(99999)
		var count=arena.actors.size();arena.boss.tick_commander_help(100)
		check(arena.actors.size()==count,"support stops on commander death")
		var chests=arena.pickups.filter(func(p):return p.kind=="recipe_draft")
		check(chests.size()==1 and chests[0].elite==elite,"correct chest dropped")
		for i in range(20):
			var offers=arena.reward.chest_offers()
			check(offers.size()==3,"three rewards")
			check(offers.slice(1).all(func(o):return o.category=="upgrade" and o.tier>=difficulty),"chest upgrades never below the room difficulty")
			if difficulty==0:check(offers[0].category=="alloy" and offers[0].amount==EncounterRules.chest_alloy(field,0),"simple chest has alloy, no blueprints")
			else:check(offers[0].category!="alloy" or offers[0].amount==EncounterRules.chest_alloy(field,difficulty),"starred chest: blueprint or alloy by difficulty")
		arena.run.rerolls_left=2;arena.reward.open_recipe_draft(chests[0]);arena.reward.reroll_recipe_draft()
		if difficulty==0:check(arena.draft_pickup.offers.all(func(o):return o.category in ["alloy","upgrade"]),"reroll cannot upgrade chest tier")
	# Existing combat transitions remain locked until the zoom-out is complete.
	arena.phase="upgrade";var map_events=[]
	arena.map_requested.connect(func(index):map_events.append(index))
	arena.depart_room();arena.depart_room()
	check(arena.phase=="map" and map_events.is_empty(),"map exit freezes combat before transition")
	# The HQ outro plays first; wait for it.
	for i in range(60):
		await get_tree().create_timer(.1).timeout
		if not map_events.is_empty():break
	await get_tree().create_timer(.3).timeout
	check(map_events.size()==1,"map exit fires exactly once after camera transition")
	arena.begin_room(Campaign.BOSSES[0])
	check(arena.presentation.heading.text.to_lower()=="бой с генералом","final stage title")
	arena.begin_room(0);arena.start_wave(1)
	check(arena.presentation.heading.text.to_lower()=="волна 2","second wave title")
	arena.phase="paused";var size_before=arena.camera.size;arena.presentation._process(1)
	check(arena.camera.size==size_before,"paused camera stays still")
	var plan=RoutePlan.build(42);var stage=0
	while stage<plan.size()-1 and plan[stage].size()<2:stage+=1
	var chosen=plan[stage][1];arena.run.route_choices[stage]=chosen.id;arena.begin_room(stage)
	check(arena.room.commander_elite==chosen.elite,"route choice survives room entry")
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=42;route.available=stage;route.route_choices=arena.run.route_choices;add_child(route)
	check(route.find_children("CurrentHero","Node3D",true,false).size()==1,"one player on branch map")
	var selected=[];route.route_selected.connect(func(index,id):selected.append([index,id]))
	# On the first stage the HQ first drives out of the garage (intro); travel starts after it.
	for i in range(30):
		if not route.travelling:break
		await get_tree().create_timer(.1).timeout
	var allowed=route.reachable[0];route.travel_to_room(stage,allowed)
	for i in range(40):
		await get_tree().create_timer(.1).timeout
		if not route.travelling:break
	await get_tree().create_timer(.3).timeout
	# Arrival shows the compact node card (not a modal); E / the card button would enter.
	check(selected.is_empty() and not route.travelling and not is_instance_valid(route.modal),"travel waits for confirmation")
	route.confirm_entry()
	for i in range(30):
		await get_tree().create_timer(.1).timeout
		if not selected.is_empty():break
	check(selected==[[stage,allowed]],"selected branch sent after confirmation")
	route.queue_free();arena.queue_free();await get_tree().process_frame
	var main=load("res://scripts/main.gd").new();add_child(main);main.start_run()
	# Start from a node with a fight ahead (a lane may lead only to a service stop).
	var plan1=main.current.plan[1]
	var fights=func(n):return n.next.any(func(id):return RoutePlan.node_branch(plan1.filter(func(m):return m.id==id)[0])=="")
	var first=main.current.plan[0].filter(fights).back()
	main.enter_room(0,first.id)
	check(main.run_arena.run.route_choices[0]==first.id and main.run_arena.room.commander_elite==first.elite,"first branch reaches real arena")
	main.show_map(1)
	var legal=main.current.reachable
	var inaccessible=main.current.plan[1].filter(func(n):return n.id not in legal)
	if not inaccessible.is_empty():
		var old=main.current;main.enter_room(1,inaccessible[0].id);check(main.current==old,"Main rejects disconnected route")
	# Service nodes open their own stop; a fight node starts the arena.
	var fight=legal.filter(func(id):return RoutePlan.node_branch(main.current.plan[1].filter(func(n):return n.id==id)[0])=="")
	main.enter_room(1,fight[0]);check(main.run_arena.room_index==1,"legal next room starts")
	main.show_hub();main.queue_free();await get_tree().process_frame
	print("ROUTE STRATEGY: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
