extends Node
# Author fixes 0.8.x: T-235 the route has fewer service stops instead of the old «no two services in a row» rule
# (T-218, removed): every road goes through the service rows, roads never cross and every point is reachable;
# T-209 the 3×2 cells in front of the HQ fortification stay free; T-210 commander sniper tuning; T-212 visible
# dodge; T-205 sandbox turret drop. Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame

## Map position of a route node or a service stop, the same formulas as route_map.gd (room_point, service rows).
func stage_z(stage:int)->float:
	return -(stage+Campaign.SERVICES.filter(func(i):return i<=stage).size())*RoutePlan.STAGE_STEP
func node_point(plan:Array,stage:int,lane:int)->Vector2:
	return Vector2((lane-(plan[stage].size()-1)*.5)*6.5,stage_z(stage))
func stop_point(stage:int,option:int,count:int)->Vector2:
	return Vector2((option-(count-1)*.5)*6.5,stage_z(stage)+RoutePlan.STAGE_STEP)
## Road segments as the world 1 map draws them: lane to lane between battle stages, through the stops of a row.
func roads(plan:Array)->Array:
	var result=[]
	for stage in range(plan.size()-1):
		if stage+1 in Campaign.SERVICES:continue
		for node in plan[stage]:
			for id in node.next:result.append([node_point(plan,stage,node.lane),node_point(plan,stage+1,int(id.split(":")[1]))])
	for stage in Campaign.SERVICES:
		var options=Campaign.service_options(0,stage)
		for i in range(options.size()):
			for lane in RoutePlan.lane_span(i,options.size(),plan[stage-1].size()):result.append([node_point(plan,stage-1,lane),stop_point(stage,i,options.size())])
			for lane in RoutePlan.lane_span(i,options.size(),plan[stage].size()):result.append([stop_point(stage,i,options.size()),node_point(plan,stage,lane)])
	return result
## Pairs of road segments that cross away from their shared ends.
func crossings(segments:Array)->int:
	var bad=0
	for a in range(segments.size()):
		for b in range(a+1,segments.size()):
			var p=segments[a];var q=segments[b]
			if p[0].is_equal_approx(q[0]) or p[0].is_equal_approx(q[1]) or p[1].is_equal_approx(q[0]) or p[1].is_equal_approx(q[1]):continue
			if Geometry2D.segment_intersects_segment(p[0],p[1],q[0],q[1])!=null:bad+=1
	return bad
## Every node the game lets the player reach (RoutePlan.reachable through the service rows), as ids.
func reached(plan:Array)->Dictionary:
	var seen={};var stack=[]
	for id in RoutePlan.reachable(plan,0,{}):stack.append([0,id])
	while not stack.is_empty():
		var state=stack.pop_back();var stage:int=state[0];var id:String=state[1]
		if seen.has(id):continue
		seen[id]=true
		if stage+1>=plan.size():continue
		var choices={stage:id};var branches=[""]
		if stage+1 in Campaign.SERVICES:branches=RoutePlan.service_options_from(plan,stage+1,choices,Campaign.service_options(0,stage+1))
		for branch in branches:
			for next in RoutePlan.reachable(plan,stage+1,choices,branch):stack.append([stage+1,next])
	return seen

func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	# T-235: fewer service stops on the route, every road through the service rows, no crossings, all reachable.
	Campaign.configure(1)
	var deterministic=true;var specials=0;var crossed=0;var unreachable=0;var empty_routes=0;var plans=400
	for seed_value in range(plans):
		var plan=RoutePlan.build(seed_value*7919+3)
		deterministic=deterministic and str(plan)==str(RoutePlan.build(seed_value*7919+3))
		var count=0
		for stage in plan:
			for node in stage:if RoutePlan.is_service(node):count+=1
		specials+=count;empty_routes+=1 if count<=1 else 0
		crossed+=crossings(roads(plan))
		var seen=reached(plan)
		for stage in plan:
			for node in stage:if not seen.has(node.id):unreachable+=1
	check(deterministic,"route plan stays seeded")
	check(specials>plans*1.6 and specials<plans*2.4,"service stops on the route are rarer: %.2f per route (was 3)" % (float(specials)/plans))
	check(empty_routes>0,"some routes have neither the mechanic nor the workshop (%d)" % empty_routes)
	check(crossed==0,"roads never cross (%d crossings)" % crossed)
	check(unreachable==0,"every point of the map is reachable (%d unreachable)" % unreachable)
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
	# Main flow (T-235): after the mechanic right before a service row the row still comes — no road past it.
	Game.profiles.selected=true
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await settle()
	var seed_with_mechanic=-1
	for seed_value in range(1,200):
		if RoutePlan.build(seed_value)[1].any(func(n):return n.type=="mechanic"):seed_with_mechanic=seed_value;break
	check(seed_with_mechanic>0,"some route has the mechanic on stage 2")
	if seed_with_mechanic>0:
		var plan=RoutePlan.build(seed_with_mechanic);var mechanic=plan[1].filter(func(n):return n.type=="mechanic")
		var start=plan[0].filter(func(n):return mechanic[0].id in n.next)[0]
		main.start_run();await settle();Game.visual_run_seed=seed_with_mechanic;main.show_map(0);await settle()
		main.enter_room(0,start.id);await settle()
		main.run_arena.auto_pause_enabled=false;main.run_arena.set_physics_process(false)
		main.show_map(1);await settle()
		main.enter_room(1,mechanic[0].id);await settle()
		main.current.completed.emit(1);await settle()
		check(main.current.get_script()==load("res://scripts/route_map.gd") and main.current.needs_service,"after the mechanic the service row comes next")
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
	# T-228: a crate broken by the soldier often holds a prize — alloy, ammo, a medkit or a gun — on the combat RNG.
	var crate_script=preload("res://scripts/systems/field_crates.gd")
	var odds=RandomNumberGenerator.new();odds.seed=5;var got={}
	for i in range(2000):
		var prize=crate_script.roll_prize(odds);got[prize]=got.get(prize,0)+1
	check(got.get("",0)>800 and got.get("",0)<1000 and got.has("alloy") and got.has("ammo") and got.has("medkit") and got.has("weapon"),"crate prizes: %s" % [got])
	var crates=arena.get_node_or_null("FieldCrates")
	if crates:
		var state=arena.run.combat_rng.state;var items=arena.room.pickups.size()
		for i in range(12):crates.loot(hero.position)
		check(arena.run.combat_rng.state!=state,"crate loot rolls on the combat RNG")
		check(arena.room.pickups.size()>items,"broken crates leave items on the field")
	# T-205: the sandbox admin turret drops a turret even on the first field.
	arena.sandbox=true;var before=arena.room.pickups.size()
	arena.drop_pickup(hero.cell,"turret")
	check(arena.room.pickups.size()==before+1 and arena.room.pickups.back().kind=="turret","sandbox turret drop stays a turret")
	arena.sandbox=false
	arena.drop_pickup(hero.cell,"turret")
	check(arena.room.pickups.back().kind!="turret","campaign field 1 still swaps the turret")
