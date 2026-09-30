extends Node
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func _ready():call_deferred("run")
func shot(label:String):
	if DisplayServer.get_name()=="headless":return
	await get_tree().create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/r13-feedback-"+label+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Settings.values.world_lighting="night";Settings.values.fullscreen=false;Settings.apply();Campaign.configure(1)
	for seed_value in range(30):
		var rows=BattleMapGenerator.generate(seed_value,0).rows
		for x in [0,rows.size()-1]:
			var count=0
			for y in range(1,rows.size()-1):
				if rows[y][x]=="N":count+=1
			check(count==roundi((rows.size()-2)*.75),"Each flank retains 75% nets")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false);arena.phase="combat";arena.spawn_queue.clear()
	for actor in arena.actors:actor.set_physics_process(false)
	for wall in arena.walls.values():wall.node.queue_free()
	for trench in arena.trenches.values():trench.queue_free()
	arena.walls.clear();arena.trenches.clear();arena.terrain.patches.clear();arena.navigation.reset()
	arena.base_model.rotation.y=PI
	await get_tree().process_frame
	var rig=arena.base_model.get_node("HeadlightRig")
	check(rig.get_child_count()==2,"Two HQ lights")
	for light in rig.get_children():
		check(light.shadow_enabled and light.get_meta("occluded_beam",false),"HQ beams are shadowed")
		check((-light.global_basis.z).normalized().dot(Vector3.FORWARD)>.9,"HQ headlights follow front")
	var lamps=arena.base_model.find_children("Amber headlamp*","MeshInstance3D",true,false)
	for i in range(2):check(rig.get_child(i).global_position.distance_to(lamps[i].global_position)<.03,"HQ beam anchored to authored lamp")
	for kind in ["tank","apc","buggy"]:
		var model=Visuals.model(kind,arena,arena.world_pos(arena.base_cell)+Vector3((1 if kind=="tank" else -1)*2,0,-3 if kind=="buggy" else -1))
		preload("res://scripts/world_lighting.gd").headlights(model,true)
		check(model.get_node("HeadlightRig").find_children("*","SpotLight3D",true,false).size()==2,"Pair of lights on "+kind)
	var camera=arena.get_viewport().get_camera_3d();camera.size=7;camera.position=arena.base_model.position+Vector3(4,7,5);camera.look_at(arena.base_model.position+Vector3(0,0,-1.5))
	arena.add_wall(arena.base_cell+Vector2i.UP,8)
	await shot("wall-intact")
	arena.walls[arena.base_cell+Vector2i.UP].node.queue_free();arena.walls.erase(arena.base_cell+Vector2i.UP)
	await shot("wall-open")
	var alert=arena.base_model.get_node("BaseAlert")
	arena.combat.damage_base(.1);check(alert.remaining>4,"Damage activates alert")
	alert.cooldown=3;alert.trigger();check(alert.cooldown==3,"Repeated damage respects cooldown")
	await shot("alarm")
	arena.phase="upgrade";alert._process(.1);check(alert.remaining==0,"Alert ends outside battle");arena.phase="combat"
	var p=arena.player;p.position=arena.world_pos(Vector2i(4,4))+Vector3(.3,0,0);p.cell=Vector2i(4,4);p.destination=Vector2i(5,4);p.moving=true;p.quarter_destination=p.position+Vector3(.25,0,0)
	check(arena.add_barrier(Vector2i(5,4),10),"Barrier placed during step")
	check(arena.can_stand(p.position,p) and not p.moving,"Player displaced safely and step canceled")
	var drop=load("res://scripts/resource_drop.gd").new();drop.arena=arena;drop.position=arena.base_model.position+Vector3(0,.8,-1.8);arena.add_child(drop);arena.room.resource_drops.append(drop)
	var mat=drop.visual.get_child(0).material_override;check(mat.metallic>.9 and mat.roughness<.3,"Alloy has gold PBR")
	await shot("gold")
	var before=Game.credits;drop.collect();drop.collect();check(Game.credits==before+1,"Collection awards once")
	check(ResourceStrip.pickup_flights.size()>0,"Pickup uses common HUD flight")
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(.32).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/r13-feedback-flight.png")
	await get_tree().create_timer(.8).timeout
	check(ResourceStrip.pickup_flights.filter(is_instance_valid).is_empty(),"Flights cleaned up")
	# Loot cannot spawn on water, vegetation, trenches, or unreachable isolated floor.
	for cell in [Vector2i(3,3),Vector2i(4,3)]:
		for x in range(2):
			for y in range(2):arena.terrain.patches[cell*2+Vector2i(x,y)]="water" if cell.x==3 else "vegetation"
	for i in range(15):arena.drop_pickup(Vector2i(3,3),"heart")
	for pickup in arena.pickups:check(arena.reward.drop_cell_open(arena.grid_pos(pickup.node.position)),"Bonus on accessible floor")
	arena.drop_recipe(Vector2i(3,3),{})
	check(arena.reward.drop_cell_open(arena.grid_pos(arena.pickups[-1].node.position)),"Chest moved off water")
	preload("res://scripts/resource_drop.gd").spawn(arena,arena.world_pos(Vector2i(3,3)),5)
	check(arena.reward.drop_cell_open(arena.grid_pos(arena.room.resource_drops[-1].position)),"Currency moved off water")
	for token in arena.room.resource_drops:token.set_physics_process(false)
	var next=arena.pickups.filter(func(item):return item.kind=="heart")[0]
	next.node.position=arena.world_pos(Vector2i(2,2))
	p.position=next.node.position+Vector3(.95,0,0);p.hp=1;arena.soldier_hp=1
	next.land_at=0.0  # landed: bonuses float down on a parachute first
	arena.reward.collect_nearby_pickups(0)
	check(next not in arena.pickups,"Collect from adjacent cell edge")
	var states={}
	for seed_value in range(30):states[preload("res://scripts/mobile_hq.gd").orientation(seed_value)]=true
	check(states.size()==2 and states.has(PI*.5) and states.has(-PI*.5),"HQ stands only sideways")
	var audio=Game.audio();check(audio.banks.base_alert.files.size()==3,"Three alarm variants")
	var rng_state=arena.run.combat_rng.state;var previous=""
	for i in range(6):
		var stream=audio.stream_for("base_alert");check(stream.get_length()>3 and stream.resource_path!=previous,"Alarm variants playable without adjacent repeat");previous=stream.resource_path
	check(arena.run.combat_rng.state==rng_state,"Audio randomness does not affect combat")
	arena.queue_free();await get_tree().process_frame
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=42;route.available=1;add_child(route)
	await get_tree().create_timer(.8).timeout
	var hq=route.player_marker.get_node("CurrentHero");var pair=hq.get_node("HeadlightRig").get_children();var fixtures=hq.find_children("Amber headlamp*","MeshInstance3D",true,false)
	for i in range(2):check(pair[i].global_position.distance_to(fixtures[i].global_position)<.15,"Map lamps follow scaled rotated HQ")
	await shot("route")
	route.queue_free();await get_tree().process_frame
	print("FIELD FEEDBACK: failures=",failures)
	get_tree().quit(failures)
