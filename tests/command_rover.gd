extends Node3D
func _ready():call_deferred("run")
func screenshot(id):
	if DisplayServer.get_name()=="headless":return
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/command_rover/"+id+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	var map=load("res://scripts/route_map.gd").new();add_child(map)
	assert(map.travelling)
	var start=map.player_marker.position
	var vehicle=map.player_marker.get_node("CurrentHero")
	assert(vehicle.find_child("RadarDish",true,false)!=null)
	assert(vehicle.find_children("WheelPivot*","Node3D",true,false).size()==4)
	await get_tree().create_timer(.2).timeout;screenshot("route_departure")
	await get_tree().create_timer(1.2).timeout
	assert(not map.travelling and map.player_marker.position.z<start.z-2)
	screenshot("route_ready")
	var origin=map.player_marker.position
	# The route is driven: selecting a node drives there and shows its card; entry is a separate confirm.
	map.travel_to_room(0,map.reachable[0])
	await get_tree().create_timer(1.9).timeout
	assert(not map.travelling and not is_instance_valid(map.modal) and is_instance_valid(map.node_card))
	map.cancel_entry()
	await get_tree().create_timer(.8).timeout
	assert(map.player_marker.position.distance_to(origin)<.01 and not map.travelling)
	map.queue_free();await get_tree().process_frame
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.5).timeout
	assert(arena.base_model.find_child("RadarDish",true,false)!=null)
	screenshot("battle_headquarters")
	print("ROVER PASS: hangar departure, vehicle hierarchy, route selection/cancel, battlefield HQ")
	get_tree().quit()
