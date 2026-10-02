extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.save_blocked=false;Game.reset_upgrades()
	var preview=preload("res://scripts/room_wave_preview.gd")
	var samples=0
	for world in range(1,4):
		Campaign.configure(world)
		for seed_value in range(1,101):
			var plan=RoutePlan.build(seed_value)
			assert(plan.size()==Campaign.SIZES.size() and plan==RoutePlan.build(seed_value))  # world 3 has two boss stages
			for stage in range(6):
				# World 1 ramps up (RoutePlan.WORLD1_LEVELS; service stops are simple); later worlds offer 0, ★ and ★★.
				var levels=RoutePlan.WORLD1_LEVELS[stage].duplicate() if RoutePlan.gradual() else [0,1,2]
				for node in plan[stage]:
					if RoutePlan.node_branch(node)!="":assert(node.difficulty==0);continue
					assert(levels.has(node.difficulty));levels.erase(node.difficulty)
				# Three continuing roads plus one fork between regular stages, a single road into the boss.
				assert(plan[stage].reduce(func(sum,n):return sum+n.next.size(),0)==(3 if stage==5 else 4))
				for node in plan[stage]:
					assert(node.next.size()==1 if stage==5 else node.next.size() in [1,2])
					var waves=preview.waves(seed_value,stage,node.difficulty,node.id)
					for wave in range(3):
						assert(waves[wave]==WaveDirector.build(seed_value,stage,wave,node.difficulty,node.id))
						for e in waves[wave]:
							assert(e.rank==world)
							if stage<2:assert(e.kind in WaveDirector.PEOPLE and e.weapon!="rpg")
							elif stage<4:assert(e.kind!="tank" and e.weapon!="rpg")
						samples+=1
		var pool_counts=[]
		for level in range(3):
			var pool=EncounterRules.recipe_pool(level,[],Campaign.progress_index(3));pool_counts.append(pool.size())
			for recipe in pool:
				var rarity=Game.TIERS.tier(recipe.id)
				assert(level!=0 and ((level==1 and rarity<=1) or (level==2 and rarity>=2)))
				assert(recipe.category!="ability" or recipe.id in ["barrier","mine","laser","airstrike"])
				# World 1 holds the content of every world, gated by stage tiers; later worlds by their own number.
				if recipe.category=="weapon":assert(Campaign.weapon_world(recipe.id)<=Campaign.recipe_world())
				if Campaign.unified_content():assert(rarity<=Game.TIERS.unlocked(Campaign.progress_index(3)))
				assert(not EncounterRules.recipe_pool(level,[recipe],Campaign.progress_index(3)).has(recipe))
		print("RECIPE POOLS world ",world,": ",pool_counts)
	Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=79;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	for node in RoutePlan.build(79)[0]:
		arena.run.route_choices[0]=node.id;arena.begin_room(0);arena.phase="upgrade"
		assert(arena.room.difficulty==node.difficulty)
		var expected=WaveDirector.build(79,0,0,node.difficulty,node.id)
		for i in range(expected.size()):assert(arena.room.wave_roster[i].kind==expected[i].kind and arena.room.wave_roster[i].weapon==expected[i].weapon)
		for i in range(100):
			var offers=arena.reward.chest_offers()
			assert(offers.size()==3)
			for offer in offers:
				# Each card rolls its own rarity (RunUpgrades.roll_tier); chest cards never fall below the room difficulty.
				if offer.category=="upgrade":assert(offer.tier>=node.difficulty and offer.tier<=3)
				elif offer.category!="alloy":assert(node.difficulty>0)
		arena.reward.prepare_upgrade_offers()
		assert(not arena.room.upgrade_offers.is_empty() and arena.room.upgrade_offers.all(func(o):return o.tier>=0 and o.tier<=3))
	# Same three-wave rhythm, with no side entry near the headquarters.
	for size in [13,22,30]:
		var previous=WaveDirector.spawn_cells(size,0)
		for wave in [1,2]:
			var current=WaveDirector.spawn_cells(size,wave)
			assert(current.size()==previous.size()+2)
			assert(previous.all(func(cell):return cell in current))
			assert(WaveDirector.side_spawn_cells(size,wave).filter(func(cell):return cell.x==0).size()==wave)
			assert(WaveDirector.side_spawn_cells(size,wave).filter(func(cell):return cell.x==size-1).size()==wave)
			previous=current
	assert(WaveDirector.spawn_cells(13,0).all(func(c):return c.y==0))
	assert(WaveDirector.spawn_cells(13,2).any(func(c):return c.y>0 and c.y<=4))
	Game.set_all_recipes(true)
	for difficulty in [0,1,2]:
		arena.room.difficulty=difficulty
		for offer in arena.reward.chest_offers():
			if offer.category not in ["alloy","upgrade"]:assert(offer.get("duplicate",false),"Exhausted pool labels sellable duplicates")
	arena.queue_free();await get_tree().process_frame
	print("PASS encounters: ",samples," exact rosters, 3 difficulties, recipe rarity/world/duplicate filters and fallback")
	get_tree().quit()
