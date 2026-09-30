extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=42;route.available=4;route.needs_service=true;add_child(route)
	await get_tree().create_timer(.8).timeout
	for id in route.previews:
		var node=route.previews[id];var info=node.get_meta("info")
		assert(node.has_node("RoomTile"))
		assert(node.has_node("EliteStar")== (info.elite and info.stage>=route.available))
	for node in route.service_nodes:assert(node.scale==route.previews.values()[0].scale)
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/route_map_v8/map.png")
	route.needs_service=false;route.update_selection()
	var original=route.player_marker.position
	route.travel_to_room(route.available,route.reachable[0])
	await get_tree().create_timer(1).timeout
	# Arriving shows the compact node card (not a modal); E / the card button would enter.
	assert(is_instance_valid(route.node_card) and not is_instance_valid(route.modal));route.cancel_entry()
	await get_tree().create_timer(.7).timeout
	assert(route.player_marker.position.is_equal_approx(original));assert(not route.travelling)
	print("ROUTE V8 PASS: footprints, elite badges, briefing and return")
	get_tree().quit()
