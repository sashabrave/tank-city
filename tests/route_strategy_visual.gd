extends Node3D
func _ready():call_deferred("run")
func shot(path:String):
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/route_strategy/"+path+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false
	var seed_value=42
	for candidate in range(100):
		var plan=RoutePlan.build(candidate)
		if plan[0].size()==2 and plan[1].size()==2:seed_value=candidate;break
	Game.visual_run_seed=seed_value
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=seed_value;route.available=1;route.hero_weapon="shotgun";add_child(route)
	await get_tree().create_timer(.8).timeout;shot("branch_map")
	route.queue_free();await get_tree().process_frame
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=42;add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	arena.begin_room(3)
	for actor in arena.actors:actor.set_physics_process(false)
	await get_tree().create_timer(.3).timeout;shot("countdown")
	arena.phase="combat"
	await get_tree().create_timer(.3).timeout;shot("combat_entry")
	arena.room.commander_elite=true;arena.spawn_room_boss()
	for actor in arena.actors:actor.set_physics_process(false)
	await get_tree().create_timer(.3).timeout;shot("miniboss")
	arena.presentation.announce("ВОЛНА ЗАВЕРШЕНА","Можно выдохнуть",.9);arena.phase="upgrade"
	await get_tree().create_timer(.3).timeout;shot("wave_complete")
	get_tree().quit()
