extends Node3D
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS;call_deferred("run")
func shot(path:String):
	await get_tree().create_timer(.65).timeout;RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png(path)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.save_blocked=false;Game.reset_upgrades();Settings.values.fullscreen=false;Settings.apply();Campaign.configure(1)
	Game.profiles.directory="/tmp/reskin-visual-%d" % Time.get_ticks_usec();Game.profiles.active=1
	Game.ProfileStore.write_file(Game.profiles.path(1),Game.serialize_progress(),Game.ProfileSchema.validate)
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(.8).timeout
	hub.phase="combat";hub.set_physics_process(false)
	await shot("/tmp/reskin-hub.png")
	var grenade=load("res://scripts/hub_ability_effect.gd").new();grenade.hub=hub;grenade.kind="grenade";hub.add_child(grenade)
	await get_tree().create_timer(.7).timeout
	await shot("/tmp/reskin-grenade-radius.png")
	await get_tree().create_timer(.94).timeout
	await shot("/tmp/reskin-grenade-blast.png")
	ProfileMenu.hub=hub;ProfileMenu.open();await shot("/tmp/reskin-profiles.png")
	ProfileMenu.close()
	Game.duplicate_recipes=[{"category":"weapon","id":"pistol"},{"category":"weapon","id":"smg"}];hub.show_recycling()
	await shot("/tmp/reskin-recycling.png");hub.close_station()
	Game.built_workshops=["character","weapons","bonuses","headquarters","garage"]
	for method in ["show_build_menu","show_classes","show_class_catalog","show_recipe_shop","show_command","show_garage","show_hq_workshop"]:
		hub.call(method);await shot("/tmp/reskin-"+method+".png");hub.close_station()
	for options in [[false,false],[true,false],[false,true]]:
		hub.open_workshop(options[0],options[1]);await shot("/tmp/reskin-workshop-"+str(options)+".png");hub.close_station()
	var layer=CanvasLayer.new();layer.layer=110;add_child(layer)
	var tablet=load("res://scripts/ui/field_tablet.gd").new();tablet.tab="inventory";layer.add_child(tablet)
	for tab in ["inventory","fighter","quests","notifications","music","settings","guide"]:
		tablet.tab=tab;tablet.refresh();await shot("/tmp/reskin-tablet-"+tab+".png")
	layer.queue_free();hub.queue_free();await get_tree().process_frame
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=92;add_child(route)
	await get_tree().create_timer(1).timeout
	await shot("/tmp/reskin-route.png")
	var info=route.plan[0].filter(func(n):return n.difficulty==2)[0]
	route.modal=preload("res://scripts/route_room_dialog.gd").build(route,info)
	await shot("/tmp/reskin-route-dialog.png")
	route.queue_free();await get_tree().process_frame
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false;arena.phase="upgrade"
	await get_tree().create_timer(2).timeout
	arena.phase="combat"
	await get_tree().create_timer(1).timeout
	await shot("/tmp/reskin-battle.png")
	arena.phase="upgrade"
	arena.upgrade_offers=[{"id":"last_stand","tier":1},{"id":"opening_shot","tier":1},{"id":"exit_dash","tier":1}]
	arena.hud._show_upgrades_now()
	await get_tree().create_timer(.5).timeout
	await shot("/tmp/reskin-tall-cards.png")
	for card in arena.hud.modal.get_node("Panel").get_children():
		if not card.has_node("Description"):continue
		var description=card.get_node("Description")
		assert(description.get_line_count()*description.get_line_height()<=description.size.y)
		assert(description.position.y+description.size.y<card.get_node("ChooseButton").position.y)
	arena.hud.close_modal()
	arena.draft_pickup={"offers":[{"category":"alloy","id":"alloy","amount":30,"tier":0},{"category":"weapon","id":"smg"},{"category":"upgrade","id":"health","tier":1}]}
	arena.hud.show_recipe_draft();await shot("/tmp/reskin-chest.png");arena.hud.close_modal()
	arena.hud.show_departure();await shot("/tmp/reskin-departure.png");arena.hud.close_modal()
	for won in [false,true]:
		arena.hud.show_result(won,"Проверка оформления");await shot("/tmp/reskin-result-"+str(won)+".png");arena.hud.close_modal()
	remove_child(arena)
	for branch in ["vehicle","ability","headquarters"]:
		var service=load("res://scripts/service_room.gd").new();service.arena=arena;service.branch=branch;add_child(service)
		await shot("/tmp/reskin-service-"+branch+".png")
		service.avatar.position=Vector3(0,0,0);service.interact();await shot("/tmp/reskin-service-cards-"+branch+".png")
		service.queue_free();await get_tree().process_frame
	arena.queue_free();await get_tree().process_frame
	print("PASS visual capture: hub, profiles, recycling, route, difficult room")
	get_tree().quit()
