extends Node
# World 1 route: difficulty grows along the path, mechanic and workshop are ordinary route nodes,
# the start pad shares the stage spacing. Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	Campaign.configure(1)
	var early_hard=0;var specials_ok=true;var levels_ok=true;var edges_ok=true
	for seed_value in range(80):
		var plan=RoutePlan.build(seed_value*7919)
		var found={}
		for stage in range(plan.size()):
			for node in plan[stage]:
				if node.type!="battle":found[node.type]=stage
				if stage<2 and node.difficulty>=2:early_hard+=1
				if node.stage<plan.size()-1 and node.next.is_empty():edges_ok=false
			if stage<RoutePlan.WORLD1_LEVELS.size():
				var battles=plan[stage].filter(func(n):return n.type=="battle").map(func(n):return n.difficulty)
				for level in battles:
					if level not in RoutePlan.WORLD1_LEVELS[stage]:levels_ok=false
		specials_ok=specials_ok and found.get("mechanic",-1) in [1,2] and found.get("workshop",-1) in [3,4]
	check(early_hard==0,"no ★★ rooms on the first two stages")
	check(levels_ok,"battle difficulty follows the world 1 table")
	check(specials_ok,"mechanic on stage 2–3 and workshop on stage 4–5 in every plan")
	check(edges_ok,"every node keeps a road forward")
	check(Campaign.service_options(1,2)==["ability"],"world 1 service row keeps the instructor")
	Campaign.configure(1,true)
	var endless_plan=RoutePlan.build(5)
	check(endless_plan.all(func(stage):return stage.all(func(n):return n.type=="battle")),"endless rooms stay battles")
	Campaign.configure(2)
	var world2=RoutePlan.build(5)
	check(world2[0].map(func(n):return n.difficulty).has(2) and world2.all(func(stage):return stage.all(func(n):return n.type=="battle")),"world 2 route unchanged")
	Campaign.configure(1)
	# Mechanic node flow through main.
	Game.profiles.selected=true
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await settle()
	var seed_value=0;var plan=[];var mechanic={}
	for candidate in range(1,200):
		plan=RoutePlan.build(candidate)
		for node in plan[1]:
			if node.type=="mechanic":mechanic=node
		if not mechanic.is_empty():seed_value=candidate;break
	check(not mechanic.is_empty(),"found a plan with a stage 2 mechanic")
	var start=plan[0].filter(func(n):return mechanic.id in n.next)[0]
	main.start_run();await settle();Game.visual_run_seed=seed_value;main.show_map(0);await settle()
	main.enter_room(0,start.id);await settle()
	var arena=main.run_arena;arena.auto_pause_enabled=false;arena.set_physics_process(false)
	main.show_map(1);await settle()
	main.enter_room(1,mechanic.id);await settle()
	check(main.current.get_script()==load("res://scripts/service_room.gd") and main.current.branch=="vehicle","mechanic node opens the vehicle service")
	main.current.completed.emit(1);await settle()
	check(main.current.get_script()==load("res://scripts/route_map.gd") and main.current.available==2,"after the mechanic the next stage opens")
	check(main.route_choices.get(1,"")==mechanic.id,"mechanic stays on the travelled path")
	var map=main.current
	check(map.start_pad!=null and is_equal_approx(map.START_POINT.z,RoutePlan.STAGE_STEP),"start pad one step before the first stage")
	if is_instance_valid(main.run_arena):main.run_arena.free()
	main.queue_free();await settle()
	print("ROUTE WORLD 1: %d failures" % failures);get_tree().quit(1 if failures else 0)
