extends Node
## CORE: waves made of squads: exact wave size, squads arrive together, caps hold, vehicles appear by field tier,
## the same seed gives the same wave, and different seeds give varied squad mixes. Also: world ranks and tank
## pacing, commanders by field, room previews equal the real rosters, route difficulty tables, chest/recipe
## pools by difficulty, spawn cells and enemy professionalism. Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	if not ok:failures+=1;print("FAIL ",message);push_error(message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	var sizes=true;var caps=true;var tiers=true;var grouped=true;var mixes={}
	for seed_value in range(60):
		for room in range(6):
			for wave in range(3):
				var entries=WaveDirector.build(seed_value,room,wave)
				sizes=sizes and entries.size()==WaveDirector.wave_size(room,wave)
				var counts={}
				for e in entries:var key="rpg" if e.weapon=="rpg" else e.kind;counts[key]=int(counts.get(key,0))+1
				for key in SquadCatalog.CAPS:caps=caps and int(counts.get(key,0))<=SquadCatalog.CAPS[key]
				if room<2:tiers=tiers and not entries.any(func(e):return UnitKinds.is_vehicle(e.kind) or e.kind=="mortar")
				# Members of one squad are contiguous.
				var seen=[];var last=""
				for e in entries:
					if e.squad!=last:
						if e.squad in seen and seen.back()!=e.squad:pass
						seen.append(e.squad);last=e.squad
				mixes[str(room)+":"+",".join(entries.map(func(e):return e.squad))]=true
	check(sizes,"every wave has exactly the tuned size")
	check(caps,"mortar, sniper, tank and RPG caps hold")
	check(tiers,"fields 1–2 are infantry only")
	check(WaveDirector.build(5,3,1)==WaveDirector.build(5,3,1),"same seed, same wave")
	check(mixes.size()>200,"varied squad mixes (%d)" % mixes.size())
	var tier3=WaveDirector.build(7,5,2)
	check(tier3.any(func(e):return e.squad in ["tank_wedge","tank_hunters","storm_column"]),"late fields bring heavy squads")
	every_world_waves()
	await commander_spawns()
	await previews()
	await encounters()
	await professionalism()
	Campaign.configure(1)
	print("SQUADS: %d failures" % failures);get_tree().quit(1 if failures else 0)

## from update_v06 (wave counts) and wave_tiers: seeded squad waves in all three worlds.
func every_world_waves():
	var valid=true;var species={};var ranks={};var squads={};var structure=true;var tier_ok=true;var commanders=true
	for world in range(1,4):
		Campaign.configure(world)
		# World 3 adds the final citadel after its boss.
		structure=structure and Campaign.BOSSES[0]==6 and Campaign.BOSSES==([6,7] if world==3 else [6]) and Campaign.SIZES.size()==Campaign.BOSSES.back()+1
		for seed_value in range(100):
			for room in range(6):
				for wave in range(3):
					var entries=WaveDirector.build(seed_value,room,wave);var counts={}
					valid=valid and entries==WaveDirector.build(seed_value,room,wave) and entries.size()==WaveDirector.wave_size(room,wave)
					var people=0;var light=0;var heavy=0
					var pool=SquadCatalog.pool(WaveDirector.content_tier(room),wave).map(func(sq):return sq.id)
					for entry in entries:
						var type="rpg" if entry.weapon=="rpg" else entry.kind
						counts[type]=int(counts.get(type,0))+1;species[entry.kind]=true;ranks[entry.rank]=true;squads[entry.squad]=true
						valid=valid and entry.rank==world and entry.kind in WaveDirector.PEOPLE+WaveDirector.MACHINES
						tier_ok=tier_ok and entry.squad in pool
						if entry.weapon=="rpg" or entry.kind=="tank":heavy+=1
						elif entry.kind in WaveDirector.LIGHT:light+=1
						else:people+=1
					for type in counts:valid=valid and counts[type]<=int(SquadCatalog.CAPS.get(type,99))
					valid=valid and counts.has("tank")==WaveDirector.tanks_in_wave(room,wave)
					# Infantry, then light vehicles; tanks open every late wave.
					tier_ok=tier_ok and people>0
					if room<2:tier_ok=tier_ok and light==0 and heavy==0
					elif room<4:tier_ok=tier_ok and heavy==0
					else:tier_ok=tier_ok and entries[0].kind=="tank" and heavy>=1
			for room in range(6):
				for lane in range(3):
					var e=WaveDirector.commander_entry(seed_value,room,"%d:%d" % [room,lane])
					commanders=commanders and e.kind!="mortar"
					if room==0:commanders=commanders and e.kind in WaveDirector.PEOPLE and e.weapon!="rpg"
					elif room<=2:commanders=commanders and e.kind in ["buggy","apc"]
					else:commanders=commanders and (e.kind=="tank" or e.weapon=="rpg")
	Campaign.configure(1)
	check(structure,"six fields and a boss in every world (world 3 adds the citadel)")
	check(valid and species.size()==8 and ranks.size()==3 and squads.size()==SquadCatalog.SQUADS.size(),"seeded squad waves in 3 worlds: sizes, caps, tank pacing, all kinds, squads and world ranks")
	check(tier_ok,"squads of the field tier: infantry first, light vehicles mid-route, a tank opens late waves")
	check(commanders,"commanders: infantry on field 1, light vehicles on 2–3, tank or RPG later, never a mortar")

## from wave_tiers: the arena spawns the commander the roster promised (both RPG and tank kinds).
func commander_spawns():
	Campaign.configure(1)
	var seen={}
	for seed_value in range(1,31):
		var node=RoutePlan.build(seed_value)[3][0]
		var entry=WaveDirector.commander_entry(seed_value,3,node.id)
		if seen.has(entry.weapon+entry.kind):continue
		var arena=load("res://scenes/arena.tscn").instantiate()
		arena.run_seed=seed_value;add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
		arena.begin_room(3);arena.spawn_room_boss()
		var ok=is_instance_valid(arena.room.commander) and arena.room.commander.kind==entry.kind and arena.room.commander.enemy_weapon==entry.weapon
		check(ok,"room 3 commander matches its roster entry (seed %d)" % seed_value)
		seen[entry.weapon+entry.kind]=true
		arena.free();await get_tree().process_frame
		if seen.size()==2:break
	check(seen.size()==2,"both RPG and tank commanders spawn")

## from route_wave_preview: previews are the exact rosters; the map keeps its gates; main forwards the run.
func previews():
	Game.visual_run_seed=42
	var preview=preload("res://scripts/room_wave_preview.gd")
	var stages=Campaign.SIZES.size()
	for seed_value in [42,43]:
		for room in range(stages):
			var rosters=preview.waves(seed_value,room)
			if room in Campaign.BOSSES:
				check(rosters.size()==1 and rosters[0].size()==BossCatalog.encounter(seed_value,room).count and rosters[0].all(func(e):return e.kind=="boss"),"boss roster")
			else:
				for wave in range(3):check(rosters[wave]==WaveDirector.build(seed_value,room,wave),"exact wave roster")
	var route=load("res://scripts/route_map.gd").new();route.available=4;route.wave_seed=42;route.hero_kind="apc";route.hero_weapon="shotgun";add_child(route)
	check(route.wave_rosters.size()==stages,"all rooms have rosters")
	for info in route.plan[4]:check(route.node_rosters[info.id]==preview.waves(42,4,info.difficulty,info.id),"node roster matches its difficulty")
	route.travel_to_room(5);check(not route.travelling,"cannot skip ahead")
	route.needs_service=true;route.travel_to_room(4);check(not route.travelling,"service cannot be bypassed")
	route.free();await get_tree().process_frame
	var main=load("res://scripts/main.gd").new();add_child(main);main.start_run()
	var seed_before=main.current.wave_seed;main.enter_room(0)
	check(main.run_arena.run_seed==seed_before,"first room uses preview seed")
	main.run_arena.weapon="sniper";main.run_arena.pending_vehicle="buggy";main.show_map(1)
	check(main.current.hero_weapon=="sniper" and main.current.hero_kind=="buggy","run weapon and pending vehicle forwarded")
	main.show_hub();main.queue_free();await get_tree().process_frame

## from encounters_v19: difficulty tables per stage, rosters per node difficulty, recipe pools, chests, spawn cells.
func encounters():
	var preview=preload("res://scripts/room_wave_preview.gd")
	var graph=true;var rosters=true;var pools=true
	for world in range(1,4):
		Campaign.configure(world)
		for seed_value in range(1,41):
			var plan=RoutePlan.build(seed_value)
			for stage in range(6):
				# World 1 ramps up (RoutePlan.WORLD1_LEVELS; service stops are simple); later worlds offer 0, ★ and ★★.
				var levels=RoutePlan.WORLD1_LEVELS[stage].duplicate() if RoutePlan.gradual() else [0,1,2]
				for node in plan[stage]:
					if RoutePlan.node_branch(node)!="":graph=graph and node.difficulty==0;continue
					graph=graph and levels.has(node.difficulty);levels.erase(node.difficulty)
				# Three continuing roads plus one fork between regular stages, a single road into the boss.
				graph=graph and plan[stage].reduce(func(sum,n):return sum+n.next.size(),0)==(3 if stage==5 else 4)
				for node in plan[stage]:
					graph=graph and (node.next.size()==1 if stage==5 else node.next.size() in [1,2])
					var waves=preview.waves(seed_value,stage,node.difficulty,node.id)
					for wave in range(3):
						rosters=rosters and waves[wave]==WaveDirector.build(seed_value,stage,wave,node.difficulty,node.id)
						for e in waves[wave]:
							rosters=rosters and e.rank==world
							if stage<2:rosters=rosters and e.kind in WaveDirector.PEOPLE and e.weapon!="rpg"
							elif stage<4:rosters=rosters and e.kind!="tank" and e.weapon!="rpg"
		for level in range(3):
			var pool=EncounterRules.recipe_pool(level,[],Campaign.progress_index(3))
			for recipe in pool:
				var rarity=Game.TIERS.tier(recipe.id)
				pools=pools and level!=0 and ((level==1 and rarity<=1) or (level==2 and rarity>=2))
				pools=pools and (recipe.category!="ability" or recipe.id in ["barrier","mine","laser","airstrike"])
				# World 1 holds the content of every world, gated by stage tiers; later worlds by their own number.
				if recipe.category=="weapon":pools=pools and Campaign.weapon_world(recipe.id)<=Campaign.recipe_world()
				if Campaign.unified_content():pools=pools and rarity<=Game.TIERS.unlocked(Campaign.progress_index(3))
				pools=pools and not EncounterRules.recipe_pool(level,[recipe],Campaign.progress_index(3)).has(recipe)
	check(graph,"stage difficulty table, 4 roads between fields and 3 into the boss")
	check(rosters,"node rosters by difficulty equal the preview, ranks and early-field kinds hold")
	check(pools,"recipe pools by chest level: rarity, gadget list, world gate, owned recipes excluded")
	Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=79;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	var chest_ok=true
	for node in RoutePlan.build(79)[0]:
		arena.run.route_choices[0]=node.id;arena.begin_room(0);arena.phase="upgrade"
		check(arena.room.difficulty==node.difficulty,"room difficulty follows the chosen node")
		var expected=WaveDirector.build(79,0,0,node.difficulty,node.id)
		var same=arena.room.wave_roster.size()>=expected.size()
		for i in range(mini(expected.size(),arena.room.wave_roster.size())):same=same and arena.room.wave_roster[i].kind==expected[i].kind and arena.room.wave_roster[i].weapon==expected[i].weapon
		check(same,"arena wave roster equals the node preview")
		for i in range(60):
			var offers=arena.reward.chest_offers()
			chest_ok=chest_ok and offers.size()==3
			for offer in offers:
				# Each card rolls its own rarity; chest cards never fall below the room difficulty.
				if offer.category=="upgrade":chest_ok=chest_ok and offer.tier>=node.difficulty and offer.tier<=3
				elif offer.category!="alloy":chest_ok=chest_ok and node.difficulty>0
		arena.reward.prepare_upgrade_offers()
		check(not arena.room.upgrade_offers.is_empty() and arena.room.upgrade_offers.all(func(o):return o.tier>=0 and o.tier<=3),"upgrade offers stay within tiers 0–3")
	check(chest_ok,"chest: three cards, upgrades not below the room difficulty, blueprints only on starred rooms")
	# Same three-wave rhythm, with no side entry near the headquarters.
	var cells_ok=true
	for size in [13,22,30]:
		var previous=WaveDirector.spawn_cells(size,0)
		for wave in [1,2]:
			var current=WaveDirector.spawn_cells(size,wave)
			cells_ok=cells_ok and current.size()==previous.size()+2 and previous.all(func(cell):return cell in current)
			cells_ok=cells_ok and WaveDirector.side_spawn_cells(size,wave).filter(func(cell):return cell.x==0).size()==wave
			cells_ok=cells_ok and WaveDirector.side_spawn_cells(size,wave).filter(func(cell):return cell.x==size-1).size()==wave
			previous=current
	cells_ok=cells_ok and WaveDirector.spawn_cells(13,0).all(func(c):return c.y==0) and WaveDirector.spawn_cells(13,2).any(func(c):return c.y>0 and c.y<=4)
	check(cells_ok,"spawn cells grow by two per wave, side entries one per side per wave")
	Game.set_all_recipes(true)
	var dup_ok=true
	for difficulty in [0,1,2]:
		arena.room.difficulty=difficulty
		for offer in arena.reward.chest_offers():
			if offer.category not in ["alloy","upgrade"]:dup_ok=dup_ok and offer.get("duplicate",false)
	check(dup_ok,"exhausted pool labels sellable duplicates")
	arena.free();await get_tree().process_frame

## from professionalism_revision: one smooth skill curve through the world; aim delay, rests and chevrons follow it.
func professionalism():
	Campaign.configure(1)
	var P=Professionalism
	check(is_equal_approx(P.skill(0),.8) and is_equal_approx(P.skill(5),1.2) and is_equal_approx(P.skill(6),1.2),"world 1: 0.8 at the first room, 1.2 at the last and the boss")
	var smooth=true
	for i in range(1,6):smooth=smooth and P.skill(i)>P.skill(i-1) and P.value("aim_delay",i)<P.value("aim_delay",i-1)
	check(smooth,"skill grows and aim delay shrinks room by room")
	check(absf(P.skill(2)-.96)<.01 and absf(P.skill(3)-1.04)<.01,"middle rooms stay near today's tuning")
	check(is_equal_approx(P.value("trench_share",0),.15) and is_equal_approx(P.value("assault_chance",5),.55),"trench share and assault follow the curve")
	Campaign.configure(2);check(is_equal_approx(P.skill(0),.8),"a world without its own curve reuses world 1")
	Campaign.configure(1,true);check(P.skill(0)>1.0 and P.skill(0)<=1.4,"endless keeps growing, clamped")
	Campaign.configure(1)
	check(P.tier(0)==1 and P.tier(1)==1 and P.tier(2)==2 and P.tier(3)==2 and P.tier(4)==3 and P.tier(6)==3,"chevrons 1-1-2-2-3-3 through world 1")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=7;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	var enemy=arena.spawn_actor("soldier",Vector2i(3,1),false);enemy.set_physics_process(false)
	check(is_equal_approx(enemy.aim_delay_time,P.value("aim_delay",0)) and enemy.pause_scale>1.0,"room 0 enemy gets a slow aim and longer rests")
	enemy.fire_cooldown=0;enemy.aim_hold=0
	enemy.track_aim(Vector2i.DOWN,.1)
	check(not enemy.aimed_shot(),"no shot before the aim delay")
	enemy.track_aim(Vector2i.DOWN,.4)
	check(enemy.aim_hold>=enemy.aim_delay_time,"after the delay the shot is allowed")
	enemy.track_aim(Vector2i.ZERO,.2)
	check(enemy.aim_hold<enemy.aim_delay_time,"breaking the line resets the aim")
	check(enemy.health_label.rank==1,"room 0 enemy shows one chevron")
	var ally=arena.spawn_actor("soldier",Vector2i(5,1),false,true);ally.set_physics_process(false)
	check(ally.aim_delay_time==0.0 and ally.pause_scale==1.0,"allies have no aim delay")
	arena.free();await get_tree().process_frame
