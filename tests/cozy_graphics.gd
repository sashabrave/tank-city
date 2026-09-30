extends Node
var visual=false
func _ready():call_deferred("run")
func shot(label:String):
	if not visual:return
	await get_tree().create_timer(.8).timeout
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png("res://screenshots/cozy-"+label+".png")==OK)
func run():
	visual=DisplayServer.get_name()!="headless"
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Settings.values.fullscreen=false;Settings.values.world_lighting="day";Settings.values.shaders=true;Settings.apply()
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=92;add_child(route)
	await get_tree().create_timer(1.4).timeout
	var light=route.get_node("WorldLighting");var camera_transform=route.camera.transform
	assert(light.environment.tonemap_mode==Environment.TONE_MAPPER_FILMIC)
	await shot("map-on")
	Settings.change("shaders",false)
	assert(not light.environment.ssao_enabled and not light.environment.glow_enabled and not light.environment.volumetric_fog_enabled)
	assert(route.camera.transform==camera_transform)
	assert(light.environment.tonemap_mode==Environment.TONE_MAPPER_LINEAR)
	await shot("map-off")
	Settings.change("shaders",true);Settings.change("world_lighting","night")
	await shot("map-night")
	var lamps=get_tree().get_nodes_in_group("night_lamps").filter(func(n):return route.is_ancestor_of(n))
	assert(lamps.filter(func(n):return n.shadow_enabled).size()<=3)
	Settings.open();assert(get_tree().paused)
	Settings.change("shaders",false);assert(not light.environment.glow_enabled)
	Settings.change("shaders",true);Settings.close()
	route.queue_free();await get_tree().process_frame
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	Settings.change("world_lighting","day");await shot("hub")
	assert(hub.get_node("WorldLighting").environment.tonemap_mode==Environment.TONE_MAPPER_FILMIC)
	hub.queue_free();await get_tree().process_frame
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena)
	await shot("battle")
	Settings.change("shaders",false);assert(not arena.get_node("WorldLighting").environment.ssao_enabled)
	Settings.change("shaders",true)
	arena.queue_free();await get_tree().process_frame
	print("COZY PASS: global toggle, scene transitions, paused settings, stable camera, bounded shadows, hub/map/combat")
	get_tree().quit()
