extends Node3D
var checks=0
func _ready():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	for world in range(1,4):
		Campaign.configure(world)
		assert(Campaign.SIZES.size()==7 and Campaign.BOSSES==[6],"Six fields and boss in every world")
		for seed_value in range(300):
			for room in range(Campaign.SIZES.size()-1):
				for wave in range(3):
					var roster=WaveDirector.build(seed_value,room,wave)
					assert(roster==WaveDirector.build(seed_value,room,wave),"Deterministic")
					var people=0;var light=0;var heavy=0
					for e in roster:
						assert(e.rank==world,"Chevron matches world")
						if e.weapon=="rpg" or e.kind=="tank":heavy+=1
						elif e.kind in WaveDirector.LIGHT:light+=1
						else:people+=1
					if room<2:assert(light==0 and heavy==0)
					elif room<4:assert(people==3 and light>=3 and heavy==0)
					else:assert(people==2 and light==2 and heavy>=3)
					assert(roster.filter(func(e):return e.kind=="tank").size()<=3)
					checks+=1
				for lane in range(3):
					var e=WaveDirector.commander_entry(seed_value,room,"%d:%d" % [room,lane])
					assert(e.kind!="mortar")
					if room==0:assert(e.kind in WaveDirector.PEOPLE and e.weapon!="rpg")
					elif room<=2:assert(e.kind in ["buggy","apc"])
					else:assert(e.kind=="tank" or e.weapon=="rpg")
	print("PASS wave tiers: ",checks," rosters / 3 worlds / 300 seeds + commanders")
	Campaign.configure(1)
	var seen={}
	for seed_value in range(1,31):
		var node=RoutePlan.build(seed_value)[3][0]
		var entry=WaveDirector.commander_entry(seed_value,3,node.id)
		if seen.has(entry.weapon+entry.kind):continue
		var arena=load("res://scenes/arena.tscn").instantiate()
		arena.run_seed=seed_value;add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
		arena.begin_room(3);arena.spawn_room_boss()
		assert(is_instance_valid(arena.room.commander))
		assert(arena.room.commander.kind==entry.kind and arena.room.commander.enemy_weapon==entry.weapon)
		seen[entry.weapon+entry.kind]=true
		arena.queue_free();await get_tree().process_frame
		if seen.size()==2:break
	assert(seen.size()==2,"Both RPG and tank commanders spawn")
	print("PASS actual RPG/tank commander spawns")
	get_tree().quit()
