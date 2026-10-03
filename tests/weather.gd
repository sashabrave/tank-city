extends Node
func _ready():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	for seed_value in range(50):
		var seen=[]
		for i in range(6):
			var biome=LocationStyle.biome(seed_value,i)
			assert(biome not in seen);seen.append(biome)
			assert(biome==LocationStyle.biome(seed_value,i))
	var last=0.0
	for i in range(7):
		var coverage=LocationStyle.cloud_cover(i);assert(coverage>=last and coverage<=.4);last=coverage
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false
	# The backdrop follows the room biome (BiomeCatalog entry by world and route part).
	for i in range(7):
		arena.begin_room(i)
		var count=0
		for child in arena.get_children():
			if child.get_script()==load("res://scripts/location_ambience.gd"):
				count+=1;assert(child.biome==arena.room_palette().ambience);assert(child.get_child_count()>=9)  # silhouettes, ground, approach, cloud layer
		assert(count==1)
	print("WEATHER: 50 seeded routes, monotonic cloud limits, seven room transitions passed")
	arena.queue_free();await get_tree().process_frame;get_tree().quit()
