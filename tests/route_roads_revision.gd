extends Node3D
## CORE: route graph rules for every world (determinism, reachability, no crossings, risk spread, services),
## the world 1 table, the 3D route map, route choices through the arena and main, commander/chest rules,
## world unlocks, orders (telegrams) and the endless front. Profile and settings writes stay disabled; the
## one disk save check goes into a fresh temporary folder.
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;printerr("FAIL ",label);push_error(label)
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.values.world_lighting="day";Settings.apply()
	Game.reset_upgrades()
	var dev_worlds_before=Settings.values.get("dev_worlds",false);var selected_before=Game.profiles.selected
	for world in range(1,4):
		Campaign.configure(world)
		var patterns={}
		for seed_value in range(100):
			var plan=RoutePlan.build(seed_value)
			check(plan==RoutePlan.build(seed_value),"Deterministic graph")
			# from worlds_v13: world size, branch bounds, single final, complete paths.
			check(plan.size()==Campaign.SIZES.size(),"world size")
			var incoming=plan[0].map(func(n):return n.id)
			for stage in range(plan.size()):
				var next=[];var edges=[]
				check(plan[stage].size()>=1 and plan[stage].size()<=3,"branch bounds")
				if stage==plan.size()-1:check(plan[stage].size()==1,"one final")
				if world==1:
					# from route_strategy: three roads per field, one boss; branches differ in risk; boss converges.
					check(plan[stage].size() in ([1] if stage in Campaign.BOSSES else [3]),"three roads per field, one boss")
					var risks={}
					for info in plan[stage]:risks[info.difficulty]=true
					if plan[stage].size()>1:check(risks.size()>=2,"branch offers different risk")
					if stage in Campaign.BOSSES:check(plan[stage].size()==1 and plan[stage][0].elite,"major boss convergence")
				for node in plan[stage]:
					check(node.id in incoming,"No unreachable nodes")
					check(RoutePlan.path_to(plan,stage,node.id).size()==stage+1,"complete path")
					if stage==plan.size()-1:continue
					check(not node.next.is_empty(),"No dead ends")
					if plan[stage].size()>1 and plan[stage+1].size()>1:patterns[node.next.size()]=true
					for target_id in node.next:
						check(plan[stage+1].any(func(n):return n.id==target_id),"edge only to next stage")
						next.append(target_id);edges.append(Vector2i(node.lane,int(target_id.split(":")[1])))
				if stage<plan.size()-1 and plan[stage].size()==3 and plan[stage+1].size()==3:
					check(edges.size()==4,"Four links instead of nine")
					for a in edges:
						for b in edges:check((a.x-b.x)*(a.y-b.y)>=0,"No crossing diagonals")
				incoming=next
			# from worlds_v13: two distinct service choices; service roads keep every lane connected.
			for stage in Campaign.SERVICES:
				var services=Campaign.service_options(seed_value,stage)
				check(services.size()==2 and services[0]!=services[1],"two distinct service choices")
				if RoutePlan.service_roads():
					for row in [plan[stage-1],plan[stage]]:
						var covered={}
						for option in range(services.size()):
							for lane in RoutePlan.lane_span(option,services.size(),row.size()):covered[lane]=true
						check(covered.size()==row.size(),"service roads cover every lane")
				elif plan[stage].size()==plan[stage-1].size():
					for n in plan[stage-1]:check("%d:%d" % [stage,n.lane] in n.next,"service keeps every lane's road")
		if world==1:check(patterns.has(1) and patterns.has(2),"restricted and open crossings generated")
	# from route_world1_revision: difficulty ramps along world 1, mechanic/workshop are route nodes.
	Campaign.configure(1)
	var early_hard=0;var specials_ok=true;var levels_ok=true
	for seed_value in range(80):
		var plan=RoutePlan.build(seed_value*7919)
		var found={}
		for stage in range(plan.size()):
			for node in plan[stage]:
				if node.type!="battle":found[node.type]=stage
				if stage<2 and node.difficulty>=2:early_hard+=1
			if stage<RoutePlan.WORLD1_LEVELS.size():
				for level in plan[stage].filter(func(n):return n.type=="battle").map(func(n):return n.difficulty):
					if level not in RoutePlan.WORLD1_LEVELS[stage]:levels_ok=false
		specials_ok=specials_ok and found.get("mechanic",1) in [1,2] and found.get("workshop",3) in [3,4]  # each appears only by its chance (T-235)
	check(early_hard==0,"no ★★ rooms on the first two stages")
	check(levels_ok,"battle difficulty follows the world 1 table")
	check(specials_ok,"mechanic only on stage 2–3 and workshop only on stage 4–5")
	check(Campaign.service_options(1,2)==["ability","merchant"],"world 1 service row: instructor and merchant")
	Campaign.configure(1,true)
	check(RoutePlan.build(5).all(func(stage):return stage.all(func(n):return n.type=="battle")),"endless rooms stay battles")
	Campaign.configure(2)
	var world2=RoutePlan.build(5)
	check(world2[0].map(func(n):return n.difficulty).has(2) and world2.all(func(stage):return stage.all(func(n):return n.type=="battle")),"world 2 route unchanged")
	Campaign.configure(1)
	# Route map.
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=42;route.available=1;add_child(route)
	await get_tree().create_timer(1.0).timeout
	check(is_equal_approx(route.stage_z(1),-RoutePlan.STAGE_STEP) and is_equal_approx(route.START_POINT.z,RoutePlan.STAGE_STEP),"Equal spacing for stages and start pad")
	var hero=route.player_marker.get_node("CurrentHero")
	check(is_equal_approx(hero.rotation.y,PI),"World map orientation is fixed")
	check(route.find_children("RouteRoad*","Node3D",false,false).size()>0,"Road surfaces exist")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/r13-route-roads.png")
	var stars=route.find_children("EliteStar*","MeshInstance3D",true,false)
	check(not stars.is_empty() and stars[0].material_override.emission_energy_multiplier>2,"Emissive stars")
	var dust=route.get_node("WorldAtmosphere");var origin=dust.global_position
	# Near-camera bokeh was replaced by puffy edge clouds (world_atmosphere.add_map_clouds).
	check(dust.batches[0].multimesh.instance_count==0,"No near-camera bokeh on the map")
	var clouds=dust.clouds[0].multimesh
	check(clouds.instance_count>0,"Puffy map clouds exist")
	var particle=dust.clouds[0].global_transform*clouds.get_instance_transform(0).origin
	var screen_before=route.camera.unproject_position(particle)
	route.scroll+=10;route.move_camera();await get_tree().process_frame
	check(dust.global_position.is_equal_approx(origin),"Dust anchored to world map")
	check(route.camera.unproject_position(dust.clouds[0].global_transform*clouds.get_instance_transform(0).origin).distance_to(screen_before)>30,"Clouds move across screen while scrolling")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/r13-route-roads-scrolled.png")
	route.scroll-=10;route.move_camera()
	var selected=[];route.route_selected.connect(func(index,id):selected.append([index,id]))
	var allowed=route.reachable[0]
	route.travel_to_room(1,allowed)
	await get_tree().create_timer(.4).timeout
	var target=route.previews[allowed].position+Vector3(0,.17,2)*route.MINI_SCALE
	var direction=(target-route.player_marker.position).normalized()
	check(hero.global_basis.z.normalized().dot(direction)>.99,"HQ faces travel direction")
	# from route_strategy: arrival waits for confirmation; the chosen branch is sent once confirmed.
	for i in range(40):
		if not route.travelling:break
		await get_tree().create_timer(.1).timeout
	await get_tree().create_timer(.3).timeout
	check(selected.is_empty() and not route.travelling and not is_instance_valid(route.modal),"travel waits for confirmation")
	route.confirm_entry()
	for i in range(30):
		if not selected.is_empty():break
		await get_tree().create_timer(.1).timeout
	check(selected==[[1,allowed]],"selected branch sent after confirmation")
	route.queue_free();await get_tree().process_frame
	# from route_strategy: commander risk, reinforcement budget, chest by difficulty.
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=42;add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	var field=5;arena.run.route_choices[field]=RoutePlan.build(42)[field].filter(func(n):return n.type=="battle")[0].id
	for difficulty in range(3):
		var elite=difficulty>0;var limit=[1,2,3][difficulty]
		arena.begin_room(field);arena.phase="combat";arena.room.difficulty=difficulty;arena.room.commander_elite=elite
		for actor in arena.actors:actor.set_physics_process(false)
		arena.spawn_room_boss();var commander=arena.room.commander
		check(is_instance_valid(commander) and commander.commander_elite==elite,"commander matches risk")
		if not is_instance_valid(commander):continue
		commander.set_physics_process(false)
		var pool=arena.room.commander_help_pool
		check(not pool.is_empty(),"strong wave helper pool")
		arena.boss.tick_commander_help(20)
		var helpers=arena.actors.filter(func(a):return a.commander_support)
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
			check(offers.all(func(o):return o.category=="upgrade" and o.tier>=difficulty),"chest: upgrade cards only, never below the room difficulty (T-267)")
		if chests.is_empty():continue
		arena.run.rerolls_left=2;arena.reward.open_recipe_draft(chests[0])
		check(int(chests[0].get("alloy_given",0))==EncounterRules.chest_alloy(field,difficulty),"chest alloy spills out as alloy, not a card")
		arena.reward.reroll_recipe_draft()
		if difficulty==0:check(arena.draft_pickup.offers.all(func(o):return o.category in ["alloy","upgrade"]),"reroll cannot upgrade chest tier")
	# from route_strategy: a map exit freezes combat at once (the transition itself is not awaited here).
	arena.phase="upgrade";var map_events=[]
	arena.map_requested.connect(func(index):map_events.append(index))
	arena.depart_room();arena.depart_room()
	check(arena.phase=="map" and map_events.is_empty(),"map exit freezes combat before transition")
	var plan42=RoutePlan.build(42);var branch_stage=0
	while branch_stage<plan42.size()-1 and plan42[branch_stage].size()<2:branch_stage+=1
	var chosen=plan42[branch_stage][1];arena.run.route_choices[branch_stage]=chosen.id;arena.begin_room(branch_stage)
	check(arena.room.commander_elite==chosen.elite,"route choice survives room entry")
	arena.free();await settle()
	# from route_strategy: main accepts only connected route nodes.
	var main=load("res://scripts/main.gd").new();add_child(main);main.start_run()
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
	var fight=legal.filter(func(id):return RoutePlan.node_branch(main.current.plan[1].filter(func(n):return n.id==id)[0])=="")
	main.enter_room(1,fight[0]);check(main.run_arena.room_index==1,"legal next room starts")
	main.show_hub();main.queue_free();await settle()
	# from route_world1_revision: the stage 2 mechanic node opens the vehicle service and stays on the path.
	Game.profiles.selected=true
	main=load("res://scenes/main.tscn").instantiate();add_child(main);await settle()
	var mech_seed=0;var plan=[];var mechanic={}
	for candidate in range(1,200):
		plan=RoutePlan.build(candidate)
		for node in plan[1]:
			if node.type=="mechanic":mechanic=node
		if not mechanic.is_empty():mech_seed=candidate;break
	check(not mechanic.is_empty(),"found a plan with a stage 2 mechanic")
	if not mechanic.is_empty():
		var start=plan[0].filter(func(n):return mechanic.id in n.next)[0]
		main.start_run();await settle();Game.visual_run_seed=mech_seed;main.show_map(0);await settle()
		main.enter_room(0,start.id);await settle()
		main.run_arena.auto_pause_enabled=false;main.run_arena.set_physics_process(false)
		main.show_map(1);await settle()
		main.enter_room(1,mechanic.id);await settle()
		var ground=main.run_arena.playground
		check(main.current==main.run_arena and ground!=null and ground.get_script()==load("res://scripts/service_room.gd") and ground.branch=="vehicle","mechanic node opens the vehicle service on the run arena")
		ground.completed.emit(1);await settle()
		check(main.current.get_script()==load("res://scripts/route_map.gd") and main.current.available==2,"after the mechanic the next stage opens")
		check(main.route_choices.get(1,"")==mechanic.id,"mechanic stays on the travelled path")
		check(main.current.start_pad!=null,"start pad one step before the first stage")
	if is_instance_valid(main.run_arena):main.run_arena.free()
	main.queue_free();await settle()
	Game.profiles.selected=selected_before
	await world_progress()
	Settings.values["dev_worlds"]=dev_worlds_before;Campaign.configure(1)
	print("ROUTE ROADS: failures=",failures)
	get_tree().quit(1 if failures else 0)

## from worlds_v13: world unlocks and their persistence, orders, per-world finals and reward pools, endless.
func world_progress():
	var p=Game.progression
	check(not Campaign.unlocked(2) and not Campaign.infinite_unlocked(),"initial world locks")
	p.complete_world(1);check(not Campaign.unlocked(2) and Campaign.infinite_unlocked(),"demo: world 1 opens the endless front, world 2 stays closed")
	Settings.values["dev_worlds"]=true  # the development switch restores the full chain
	check(Campaign.unlocked(2) and Campaign.infinite_unlocked() and not Campaign.unlocked(3),"world unlock")
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
	for world in range(1,4):
		Campaign.configure(world)
		var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
		arena.upgrade_offers.clear();arena.reward.prepare_upgrade_offers();check(not arena.upgrade_offers.any(func(o):return str(o.id).begins_with("hq_")),"no HQ battle cards")
		Game.hq_unlocks=HQCatalog.DEFAULT_UNLOCKS.duplicate();Game.purchased_hq=HQCatalog.DEFAULT_UNLOCKS.duplicate()
		check(arena.reward.service_offers("headquarters").size()==3,"HQ service has three start options")
		var service=load("res://scripts/service_room.gd").new();service.branch="headquarters";arena.begin_service(2,service);service.claim(0);check(service.claimed,"HQ service claim")
		var tiers=load("res://scripts/progression/recipe_tiers.gd")
		check(tiers.weight("sniper",12)>0,"sniper world gate")
		check((tiers.weight("rpg",16)>0)==(world!=2),"RPG world gate")
		arena.begin_room(Campaign.SIZES.size()-1);check(arena.grid_size==Campaign.SIZES.back(),"boss board size")
		arena.phase="combat";arena.spawn_queue.clear();arena.boss_defeated=true;arena.room.pickups.clear();arena.flow.finish_wave()
		check(arena.phase=="result" and world in Game.progression.cleared_worlds,"world victory commits unlock")
		arena.queue_free();await get_tree().process_frame
	Campaign.configure(1,true);var first=Campaign.hp_scale(0);Campaign.cycle=4;check(Campaign.hp_scale(0)>first,"endless grows")
	# Disk round trip into a fresh temporary folder only (the profile, its backup and nothing else).
	var folder=OS.get_temp_dir().path_join("war-cats-route-roads-%d-%d" % [Time.get_ticks_usec(),randi()]);DirAccess.make_dir_recursive_absolute(folder)
	var save_path=Game.save_path;var picked=Game.profiles.selected;Game.profiles.selected=true;Game.save_path=folder+"/profile.json";Game.save_enabled=true;Game.save_progress();Game.progression.cleared_worlds=[];Game.load_progress();Game.save_enabled=false;Game.save_path=save_path;Game.profiles.selected=picked
	check(Game.progression.cleared_worlds==[1,2,3],"disk save preserves world unlocks")
	var main=load("res://scripts/main.gd").new();add_child(main);await settle()
	Campaign.configure(1,true);main.start_run();main.enter_room(0);var carried=main.run_arena;carried.damage_bonus=2.5
	# Endless has no map: the next sector starts straight in its first room.
	main.show_map(Campaign.SIZES.size());check(Campaign.cycle==1 and main.current==carried and carried.room_index==0 and main.run_arena==carried and carried.damage_bonus==2.5,"endless next sector preserves build")
	main.show_hub();await settle()
	check(not is_instance_valid(main.run_arena),"safe hub return from map")
	main.queue_free();await settle()
