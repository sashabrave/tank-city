extends Node
func _ready():call_deferred("run")
func shot(name:String):
	await get_tree().create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/"+name+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.values.language="ru";Settings.values.ui_theme="dark";Settings.values.world_lighting="day";Settings.apply()
	for language in ["ru","en"]:
		Settings.change("language",language)
		var hub=load("res://scenes/hub.tscn").instantiate();hub.arrival_reason="wake" if language=="ru" else "return";add_child(hub)
		await get_tree().create_timer(1.0).timeout;await shot("arrival-"+language)
		hub.queue_free();await get_tree().process_frame
	Settings.change("language","ru");Campaign.configure(3)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false)
	arena.begin_room(3);arena.phase="combat";arena.spawn_queue.clear();arena.player.set_physics_process(false);await shot("world3-cover")
	for seed_value in range(3):
		arena.run_seed=seed_value;arena.begin_room(6);arena.phase="combat";arena.spawn_queue.clear();arena.player.set_physics_process(false)
		var spec=BossCatalog.encounter(seed_value,6)
		for i in range(spec.count):
			var boss=arena.spawn_actor("boss",Vector2i(10+i*7,10),false);boss.wave_slot=i;boss.set_physics_process(false);boss.movement_pause=0
			arena.boss.boss_step(boss,.01);boss.get_meta("boss_pattern").timer=0;arena.boss.boss_step(boss,.01)
		await shot("boss-"+spec.id)
	arena.begin_room(7);arena.phase="combat";arena.spawn_queue.clear();arena.player.set_physics_process(false)
	var boss=arena.spawn_actor("boss",Vector2i(15,10),false);boss.set_physics_process(false);boss.take_damage(99999)
	for actor in arena.actors:actor.set_physics_process(false)
	await shot("gigaboss-generator")
	arena.queue_free();await get_tree().process_frame
	print("NEW CONTENT VISUAL PASS");get_tree().quit()
