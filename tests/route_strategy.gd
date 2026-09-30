extends Node3D
var checks=0
var failures=0
func check(ok:bool,msg:String):
	checks+=1
	if not ok:failures+=1;push_error(msg)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var patterns={}
	for seed_value in range(150):
		var plan=RoutePlan.build(seed_value)
		check(plan==RoutePlan.build(seed_value),"stable route seed")
		var incoming=plan[0].map(func(n):return n.id)
		for stage in range(17):
			var next=[]
			check(plan[stage].size() in [1,2],"one/two rooms")
			if plan[stage].size()==2:check(plan[stage][0].elite!=plan[stage][1].elite,"branch offers different risk")
			if stage in Campaign.BOSSES:check(plan[stage].size()==1 and plan[stage][0].elite,"major boss convergence")
			for info in plan[stage]:
				check(info.id in incoming,"node reachable from start")
				if stage<16:check(not info.next.is_empty(),"no dead ends")
				for id in info.next:
					check(plan[stage+1].any(func(n):return n.id==id),"edge only to next stage")
					next.append(id)
				if plan[stage].size()==2 and stage<16 and plan[stage+1].size()==2:patterns[info.next.size()]=true
			incoming=next
	check(patterns.has(1) and patterns.has(2),"restricted and open crossings generated")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=42;add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	check(arena.camera.size>arena.grid_size+5,"countdown camera pulled out")
	arena.phase="combat";arena.presentation._process(10)
	check(is_equal_approx(arena.camera.size,arena.grid_size+5),"combat camera returns to normal")
	for elite in [false,true]:
		arena.begin_room(12);arena.phase="combat";arena.room.commander_elite=elite
		for actor in arena.actors:actor.set_physics_process(false)
		arena.spawn_room_boss();var commander=arena.room.commander;commander.set_physics_process(false)
		check(is_instance_valid(commander) and commander.commander_elite==elite,"commander matches risk")
		var pool=arena.room.commander_help_pool
		check(not pool.is_empty(),"strong wave helper pool")
		arena.boss.tick_commander_help(20)
		var helpers=arena.actors.filter(func(a):return a.commander_support)
		check(helpers.size()==(2 if elite else 1),"small risk-based reinforcement batch")
		for helper in helpers:
			helper.set_physics_process(false)
			check(pool.any(func(e):return e.kind==helper.kind),"helpers from room wave")
		for i in range(15):arena.boss.tick_commander_help(20)
		check(arena.actors.filter(func(a):return a.commander_support and not a.dead).size()<=(3 if elite else 1),"live support cap")
		for cycle in range(8):
			for helper in arena.actors.duplicate():
				if helper.commander_support:arena.actors.erase(helper);helper.free()
			arena.boss.tick_commander_help(30)
		check(arena.room.commander_help_waves==(4 if elite else 2),"finite reinforcement wave budget")
		commander.take_damage(99999)
		var count=arena.actors.size();arena.boss.tick_commander_help(100)
		check(arena.actors.size()==count,"support stops on commander death")
		var chests=arena.pickups.filter(func(p):return p.kind=="recipe_draft")
		check(chests.size()==1 and chests[0].elite==elite,"correct chest dropped")
		for i in range(20):
			var offers=arena.reward.chest_offers(elite)
			check(offers.size()==3,"three rewards")
			if not elite:check(offers.all(func(o):return o.category in ["alloy","upgrade"] and o.tier==0),"normal chest has no recipes/secrets")
			check(offers.any(func(o):return o.category=="alloy" and o.amount==RoutePlan.chest_alloy(12,elite)),"map alloy matches chest")
		arena.run.rerolls_left=2;arena.reward.open_recipe_draft(chests[0]);arena.reward.reroll_recipe_draft()
		if not elite:check(arena.draft_pickup.offers.all(func(o):return o.category in ["alloy","upgrade"]),"reroll cannot upgrade chest tier")
	# Existing combat transitions remain locked until the zoom-out is complete.
	arena.phase="upgrade";var map_events=[]
	arena.map_requested.connect(func(index):map_events.append(index))
	arena.depart_room();arena.depart_room()
	check(arena.phase=="map" and map_events.is_empty(),"map exit freezes combat before transition")
	await get_tree().create_timer(.7).timeout
	check(map_events.size()==1,"map exit fires exactly once after camera transition")
	arena.begin_room(16)
	check(arena.presentation.heading.text=="ПОСЛЕДНИЙ БОЙ","final stage title")
	arena.begin_room(0);arena.start_wave(1)
	check(arena.presentation.heading.text=="ВОЛНА 2 / 3","second wave title")
	arena.phase="paused";var size_before=arena.camera.size;arena.presentation._process(1)
	check(arena.camera.size==size_before,"paused camera stays still")
	var plan=RoutePlan.build(42);var stage=0
	while stage<16 and plan[stage].size()<2:stage+=1
	var chosen=plan[stage][1];arena.run.route_choices[stage]=chosen.id;arena.begin_room(stage)
	check(arena.room.commander_elite==chosen.elite,"route choice survives room entry")
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=42;route.available=stage;route.route_choices=arena.run.route_choices;add_child(route)
	check(route.find_children("CurrentHero","Node3D",true,false).size()==1,"one player on branch map")
	var selected=[];route.route_selected.connect(func(index,id):selected.append([index,id]))
	var allowed=route.reachable[0];route.travel_to_room(stage,allowed)
	await get_tree().create_timer(1.3).timeout
	check(selected.is_empty() and is_instance_valid(route.modal),"travel opens briefing")
	route.confirm_entry();await get_tree().create_timer(.45).timeout
	check(selected==[[stage,allowed]],"selected branch sent after confirmation")
	route.queue_free();arena.queue_free();await get_tree().process_frame
	var main=load("res://scripts/main.gd").new();add_child(main);main.start_run()
	var first=main.current.plan[0].back()
	main.enter_room(0,first.id)
	check(main.run_arena.run.route_choices[0]==first.id and main.run_arena.room.commander_elite==first.elite,"first branch reaches real arena")
	main.show_map(1)
	var legal=main.current.reachable
	var inaccessible=main.current.plan[1].filter(func(n):return n.id not in legal)
	if not inaccessible.is_empty():
		var old=main.current;main.enter_room(1,inaccessible[0].id);check(main.current==old,"Main rejects disconnected route")
	main.enter_room(1,legal[0]);check(main.run_arena.room_index==1,"legal next room starts")
	main.show_hub();main.queue_free();await get_tree().process_frame
	print("ROUTE STRATEGY: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
