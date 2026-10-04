extends Node
# Author fixes 0.8.x: T-218 no two service stops in a row on any road; T-209 the 3×2 cells in front of
# the HQ fortification stay free; T-210 commander sniper tuning; T-212 visible dodge; T-205 sandbox
# turret drop. Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame

## Walks every road the game allows (RoutePlan.reachable, service rows included) and returns the number
## of places where a service stop follows another service stop.
func service_streaks(plan:Array)->int:
	var bad=0
	# Frontier: [stage, previous node id ("" at the start), previous step was a service].
	var stack=[[0,"",false]];var seen={}
	while not stack.is_empty():
		var state=stack.pop_back();var stage:int=state[0];var prev_id:String=state[1];var prev_service:bool=state[2]
		var key="%d|%s|%s" % [stage,prev_id,prev_service]
		if seen.has(key) or stage>=plan.size():continue
		seen[key]=true
		var choices={} if prev_id=="" else {stage-1:prev_id}
		var branches=[""]
		if stage in Campaign.SERVICES and not RoutePlan.skips_service_row(plan,stage,choices):
			# Mandatory service row before this stage.
			if prev_service:bad+=1
			prev_service=true
			branches=RoutePlan.service_options_from(plan,stage,choices,Campaign.service_options(0,stage))
		elif stage in Campaign.SERVICES:branches=[RoutePlan.ROW_REPLACED]
		for branch in branches:
			for id in RoutePlan.reachable(plan,stage,choices,branch):
				var node=plan[stage].filter(func(n):return n.id==id)[0]
				var service=RoutePlan.is_service(node)
				if service and prev_service:bad+=1
				stack.append([stage+1,id,service])
	return bad

func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	# T-218: every reachable road alternates services with battles.
	Campaign.configure(1)
	var streaks=0;var deterministic=true;var specials=0
	for seed_value in range(200):
		var plan=RoutePlan.build(seed_value*7919+3)
		streaks+=service_streaks(plan)
		deterministic=deterministic and str(plan)==str(RoutePlan.build(seed_value*7919+3))
		for stage in plan:
			for node in stage:if RoutePlan.is_service(node):specials+=1
	check(streaks==0,"no road has two service stops in a row (%d found)" % streaks)
	check(deterministic,"route plan stays seeded")
	check(specials==600,"world 1 keeps mechanic, workshop and command post on every route (%d)" % specials)
	Campaign.configure(2)
	check(service_streaks(RoutePlan.build(5))==0,"world 2 rows alternate with battles")
	Campaign.configure(1)
	# T-209: no block of any kind in the 3×2 cells in front of the HQ fortification.
	var front_free=true;var valid=true
	for room in range(Campaign.SIZES.size()):
		for seed_value in range(60):
			for reduce in [true,false]:
				var rows=BattleMapGenerator.generate(seed_value*104729+room,room,reduce).rows
				valid=valid and BattleMapGenerator.validate(rows)
				for cell in BattleMapGenerator.base_front_cells(rows.size()):
					if rows[cell.y][cell.x]!=".":front_free=false
	check(front_free,"3×2 cells in front of the HQ stay empty on every generated field")
	check(valid,"generated fields stay connected")
	# Same on a built arena (after barrels, reinforcement, containers): no wall in the zone.
	for seed_value in [3,41,977]:
		var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=seed_value;add_child(arena);arena.auto_pause_enabled=false
		await settle();arena.set_physics_process(false)
		var blocked=BattleMapGenerator.base_front_cells(arena.grid_size).filter(func(c):return arena.walls.has(c) or arena.trenches.has(c) or arena.nets.has(c))
		check(blocked.is_empty(),"arena %d: zone in front of the HQ has no walls" % seed_value)
		if seed_value==977:
			await extra_checks(arena)
		arena.free();await settle()
	# Main flow: a service node right before a service row replaces that row on its road.
	Game.profiles.selected=true
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await settle()
	var plan=RoutePlan.build(11);var mechanic=plan[1].filter(func(n):return n.type=="mechanic")
	check(not mechanic.is_empty(),"mechanic stands on stage 2")
	if not mechanic.is_empty():
		var start=plan[0].filter(func(n):return mechanic[0].id in n.next)[0]
		main.start_run();await settle();Game.visual_run_seed=11;main.show_map(0);await settle()
		main.enter_room(0,start.id);await settle()
		main.run_arena.auto_pause_enabled=false;main.run_arena.set_physics_process(false)
		main.show_map(1);await settle()
		main.enter_room(1,mechanic[0].id);await settle()
		main.current.completed.emit(1);await settle()
		check(main.current.get_script()==load("res://scripts/route_map.gd") and not main.current.needs_service,"after the mechanic the service row is skipped")
		check(main.run_arena.visited_services.get(2,"")==RoutePlan.ROW_REPLACED,"row marked as replaced")
		var next=RoutePlan.reachable(plan,2,main.route_choices,RoutePlan.ROW_REPLACED)
		check(next==mechanic[0].next and not next.is_empty(),"the mechanic's roads lead straight to stage 3 battles")
	if is_instance_valid(main.run_arena):main.run_arena.free()
	main.queue_free();await settle()
	print("ROUTE ALTERNATION: %d failures" % failures);get_tree().quit(1 if failures else 0)

func extra_checks(arena):
	arena.phase="combat"
	# T-210: the commander sniper aims faster and shoots a faster round than a regular sniper.
	var system=arena.enemy
	check(is_equal_approx(system.COMMANDER_SNIPER_AIM,system.SNIPER_AIM*.65) and is_equal_approx(system.COMMANDER_SNIPER_BULLET_SPEED,system.SNIPER_BULLET_SPEED*1.4),"commander sniper: aim −35%, bullet +40%")
	# T-212: a dodged bullet shows «Уклон» over the hero.
	var hero=arena.player;arena.run.dodge=1.0;arena.run.landing_until=-1.0
	var shown=false
	for i in range(40):
		hero.invulnerable=0;var hp=hero.hp
		hero.take_damage(.1,Vector3.ZERO,"","bullet")
		if is_equal_approx(hero.hp,hp):
			shown=arena.get_children().any(func(c):return c is Label3D and c.text in ["Уклон","Dodged"])
			break
	check(shown,"a dodge shows a floating «Уклон»")
	arena.run.dodge=0.0;hero.hp=hero.max_hp;hero.refresh_health()
	# T-205: the sandbox admin turret drops a turret even on the first field.
	arena.sandbox=true;var before=arena.room.pickups.size()
	arena.drop_pickup(hero.cell,"turret")
	check(arena.room.pickups.size()==before+1 and arena.room.pickups.back().kind=="turret","sandbox turret drop stays a turret")
	arena.sandbox=false
	arena.drop_pickup(hero.cell,"turret")
	check(arena.room.pickups.back().kind!="turret","campaign field 1 still swaps the turret")
