extends Node3D
func shot(name:String):
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/ui_refresh/"+name+".png")
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades();Game.credits=708;Game.cores=4;Game.health_level=4;Game.built_workshops=["character","weapons","bonuses"]
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(.3).timeout;shot("hub")
	hub.open_workshop(false);hub.workshop_tab=3;hub.refresh();await get_tree().create_timer(.3).timeout;shot("abilities")
	hub.close_station();hub.open_workshop(true);await get_tree().create_timer(.3).timeout;shot("weapons")
	hub.queue_free();await get_tree().process_frame
	Game.equipped_abilities=["shield","cloak"];Game.ability_slots=2
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	for actor in arena.actors:actor.set_physics_process(false)
	arena.phase="combat";arena.abilities.cast_slot(0)
	await get_tree().create_timer(.6).timeout;shot("active_skill")
	arena.abilities.tick(10);await get_tree().create_timer(.2).timeout;shot("cooldown")
	var benchmark=preload("res://scripts/ui/weapon_benchmarks.gd").weapon(arena.weapon)
	arena.player.damage=benchmark.damage*1.25;arena.player.fire_interval=1/(benchmark.rate*1.2)
	await get_tree().create_timer(.15).timeout;shot("above_reference")
	arena.player=arena.spawn_actor("tank",Vector2i(6,9),true);arena.player.set_physics_process(false)
	await get_tree().create_timer(.4).timeout;shot("vehicle_panels")
	arena.queue_free();await get_tree().process_frame
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=42;route.available=2;route.needs_service=true;add_child(route)
	await get_tree().create_timer(.8).timeout;shot("service_map")
	route.needs_service=false;route.travel_to_room(2,route.reachable[0]);await get_tree().create_timer(1.0).timeout;shot("briefing")
	route.show_pause();await get_tree().create_timer(.2).timeout;shot("map_inventory")
	route.queue_free();await get_tree().process_frame
	var display=Node3D.new();add_child(display);Visuals.setup_world(display,12,Vector3.ZERO)
	for i in range(3):
		var model=Visuals.model(["tank","apc","buggy"][i],display,Vector3((i-1)*3.4,0,0));model.rotation.y=.3
	await get_tree().create_timer(.2).timeout;shot("friendly_vehicles")
	get_tree().quit()
