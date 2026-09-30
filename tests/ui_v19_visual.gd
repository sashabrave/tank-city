extends Node3D
func _ready():call_deferred("run")
func shot(path:String):
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.save_blocked=false;Game.reset_upgrades();Campaign.configure(1)
	Game.profiles.directory="/tmp/tank-v19-visual-%d" % Time.get_ticks_usec();Game.profiles.active=1
	Game.ProfileStore.write_file(Game.profiles.path(1),Game.serialize_progress(),Game.ProfileSchema.validate)
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(.8).timeout
	hub.phase="combat";hub.set_physics_process(false)
	await shot("/tmp/tank-v19-hub.png")
	var grenade=load("res://scripts/hub_ability_effect.gd").new();grenade.hub=hub;grenade.kind="grenade";hub.add_child(grenade)
	await get_tree().create_timer(.7).timeout
	await shot("/tmp/tank-v19-grenade-radius.png")
	await get_tree().create_timer(.94).timeout
	await shot("/tmp/tank-v19-grenade-blast.png")
	ProfileMenu.hub=hub;ProfileMenu.open();await shot("/tmp/tank-v19-profiles.png")
	ProfileMenu.close()
	Game.duplicate_recipes=[{"category":"weapon","id":"pistol"},{"category":"weapon","id":"smg"}];hub.show_recycling()
	await shot("/tmp/tank-v19-recycling.png");hub.close_station();hub.queue_free();await get_tree().process_frame
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=92;add_child(route)
	await get_tree().create_timer(1).timeout
	await shot("/tmp/tank-v19-route.png")
	var info=route.plan[0].filter(func(n):return n.difficulty==2)[0]
	route.modal=preload("res://scripts/route_room_dialog.gd").build(route,info)
	await shot("/tmp/tank-v19-route-dialog.png")
	route.queue_free();await get_tree().process_frame
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false;arena.phase="upgrade"
	arena.upgrade_offers=[{"id":"last_stand","tier":1},{"id":"opening_shot","tier":1},{"id":"exit_dash","tier":1}]
	arena.hud._show_upgrades_now()
	await get_tree().create_timer(.5).timeout
	await shot("/tmp/tank-v19-tall-cards.png")
	for card in arena.hud.modal.get_node("Panel").get_children():
		if not card.has_node("Description"):continue
		var description=card.get_node("Description")
		assert(description.get_line_count()*description.get_line_height()<=description.size.y)
		assert(description.position.y+description.size.y<card.get_node("ChooseButton").position.y)
	arena.queue_free();await get_tree().process_frame
	print("PASS visual capture: hub, profiles, recycling, route, difficult room")
	get_tree().quit()
