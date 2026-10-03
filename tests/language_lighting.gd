extends Node
func _ready():call_deferred("run")
func snapshot(name):
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(.3).timeout;RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/"+name+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.values.language="ru";Settings.values.world_lighting="day";Settings.apply()
	var scene=load("res://scenes/hub.tscn").instantiate();add_child(scene);await get_tree().process_frame
	var lighting=scene.get_node("WorldLighting");var day_color=lighting.environment.background_color;var day_energy=lighting.sun.light_energy;var cam=scene.get_viewport().get_camera_3d();var transform=cam.transform
	Settings.change("world_lighting","night");assert(lighting.sun.light_energy<=.55,"night sun %s" % lighting.sun.light_energy)  # 0.7.2 night palette: brighter silver moon;assert(cam.transform==transform,"camera %s -> %s" % [transform,cam.transform])
	assert(get_tree().get_nodes_in_group("night_lamps").any(func(n):return n.visible));await snapshot("night-hub")
	Settings.change("world_lighting","day");assert(lighting.environment.background_color==day_color);assert(is_equal_approx(lighting.sun.light_energy,day_energy) and day_energy>.4)
	assert(get_tree().get_nodes_in_group("night_lamps").any(func(n):return n.visible))
	var layer=CanvasLayer.new();layer.layer=200;add_child(layer)
	var tablet=load("res://scripts/ui/field_tablet.gd").new();tablet.tab="settings";tablet.settings_tab="Интерфейс";layer.add_child(tablet)
	Settings.change("language","en");await get_tree().process_frame;await get_tree().process_frame
	assert(Texts.render("Настройки")=="Settings");assert(Texts.render("На уровне 2")=="At level 2")
	await snapshot("settings-english")
	var missing={};var russian=RegEx.new();russian.compile("[А-Яа-яЁё]")
	for tab in ["settings","inventory","fighter","quests","notifications","base","about","music"]:
		tablet.tab=tab;tablet.refresh();await get_tree().process_frame;await get_tree().process_frame;NumberDisplay.refresh()
		for node in get_tree().get_nodes_in_group("number_display"):
			if tablet.is_ancestor_of(node) and node.is_visible_in_tree() and russian.search(node.text):missing[node.text]=true
	var file=FileAccess.open("/tmp/english-missing.txt",FileAccess.WRITE);file.store_string("\n".join(missing.keys()))
	Settings.change("language","ru");await get_tree().process_frame;assert(Texts.render("Настройки")=="Настройки")
	tablet.queue_free();scene.queue_free();await get_tree().process_frame
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena);await get_tree().process_frame
	arena.presentation.hide();arena.phase="combat";arena.player.fire_cooldown=0;arena.player.turn_left=0;arena.player.shoot()
	Settings.change("world_lighting","night");await snapshot("night-arena");assert(arena.get_node("WorldLighting").sun.light_energy<=.41)
	assert(arena.has_node("FieldBorder") and arena.has_node("WorldAtmosphere"))
	assert(arena.get_node("FieldBorder").find_children("*","CollisionObject3D",true,false).is_empty())
	var hq_light=arena.base_model.find_child("Headlight",true,false);assert(hq_light!=null and hq_light.visible and hq_light.get_meta("priority")==5)
	Settings.change("tilt_shift",false);assert(not arena.get_node("WorldAtmosphere").tilt.get_child(0).visible)
	Settings.change("atmosphere",false);assert(arena.get_node("WorldAtmosphere").batches.all(func(b):return not b.visible))
	Settings.change("atmosphere",true);Settings.change("tilt_shift",true)
	Settings.change("world_lighting","day");Settings.change("language","ru")
	arena.queue_free();await get_tree().process_frame
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=92;add_child(route)
	Settings.change("world_lighting","night");await snapshot("night-route")
	assert(route.has_node("WorldAtmosphere"));assert(route.get_node("WorldLighting").sun.light_energy<=.41)
	route.scroll=8;route.move_camera();await snapshot("night-route-scroll")
	Settings.change("world_lighting","day");await snapshot("day-route");route.queue_free();await get_tree().process_frame
	print("PASS language switch, lighting restore, lamps and camera invariance");get_tree().quit()
