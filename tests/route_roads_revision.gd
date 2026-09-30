extends Node3D
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.values.world_lighting="day";Settings.apply()
	for world in range(1,4):
		Campaign.configure(world)
		for seed_value in range(40):
			var plan=RoutePlan.build(seed_value)
			check(plan==RoutePlan.build(seed_value),"Deterministic graph")
			var incoming=plan[0].map(func(n):return n.id)
			for stage in range(plan.size()):
				var next=[];var edges=[]
				for node in plan[stage]:
					check(node.id in incoming,"No unreachable nodes")
					if stage==plan.size()-1:continue
					check(not node.next.is_empty(),"No dead ends")
					for target_id in node.next:
						next.append(target_id);edges.append(Vector2i(node.lane,int(target_id.split(":")[1])))
				if stage<plan.size()-1 and plan[stage].size()==3 and plan[stage+1].size()==3:
					check(edges.size()==4,"Four links instead of nine")
					for a in edges:
						for b in edges:check((a.x-b.x)*(a.y-b.y)>=0,"No crossing diagonals")
				incoming=next
	Campaign.configure(1)
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
	check(dust.materials[0].get_shader_parameter("near_bokeh"),"Map white particles use bokeh")
	var white=dust.batches[0].multimesh
	check(white.instance_count==ceili(7*maxf(1,(-route.stage_z(route.plan.size()-1)+18)/18)),"Sparse near-field particles")
	check(white.get_instance_transform(0).basis.get_scale().x>=.55 and white.get_instance_transform(0).origin.y>11,"Large particles close to camera")
	var particle=dust.batches[0].global_transform*dust.batches[0].multimesh.get_instance_transform(0).origin
	var screen_before=route.camera.unproject_position(particle)
	route.scroll+=10;route.move_camera();await get_tree().process_frame
	check(dust.global_position.is_equal_approx(origin),"Dust anchored to world map")
	check(route.camera.unproject_position(particle).distance_to(screen_before)>30,"Dust moves across screen while scrolling")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/r13-route-roads-scrolled.png")
	route.scroll-=10;route.move_camera()
	route.travel_to_room(1,route.reachable[0])
	await get_tree().create_timer(.4).timeout
	var target=route.previews[route.reachable[0]].position+Vector3(0,.17,2)*route.MINI_SCALE
	var direction=(target-route.player_marker.position).normalized()
	check(hero.global_basis.z.normalized().dot(direction)>.99,"HQ faces travel direction")
	print("ROUTE ROADS: failures=",failures)
	get_tree().quit(failures)
