extends Node
func _ready():call_deferred("run")
func shot(label:String):
	if DisplayServer.get_name()=="headless":return
	await get_tree().create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/r13-hub-"+label+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Settings.values.fullscreen=false;Settings.apply()
	Game.progression.prepare_telegrams();Game.progression.mark_seen()
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	assert(not hub.command_alert.visible)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		assert(not hub.command_alert.visible)
		get_viewport().get_texture().get_image().save_png("/tmp/r13-hub-entry-no-alert.png")
	await get_tree().create_timer(.6).timeout
	hub.set_physics_process(false)
	var models=hub.bench_visuals
	for i in range(4):hub.refresh()
	assert(hub.bench_visuals==models and not models.is_queued_for_deletion())
	for id in ["character","weapons","bonuses"]:
		if id not in Game.built_workshops:Game.built_workshops.append(id)
	hub.update_bench_visuals();models=hub.bench_visuals
	assert(hub.bench_visuals==models and not models.is_queued_for_deletion())
	hub.close_station();Game.credits=0;hub._physics_process(.4)
	for id in hub.bench_dots:assert(hub.bench_dots[id].visible==hub.bench_available(id))
	Game.credits=99999;hub._physics_process(.4)
	for id in hub.bench_dots:assert(hub.bench_dots[id].visible==hub.bench_available(id))
	assert(hub.bench_visuals==models)
	hub.avatar.position=hub.command_pos;hub._physics_process(0)
	for mesh in hub.command_meshes:assert(is_zero_approx(mesh.transparency)) # the command centre stays solid (no see-through)
	hub.avatar.position=Vector3(2,0,2);hub._physics_process(0)
	for mesh in hub.command_meshes:assert(is_zero_approx(mesh.transparency))
	await shot("world-cache")
	print("HUB REFRESH CACHE PASS: stable world models, live availability, command transparency")
	get_tree().quit()
