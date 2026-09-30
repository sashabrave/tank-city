extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades();Game.credits=50000
	assert(Game.garage.starting_vehicle()=="" and not Game.garage.buy("buggy"))
	Game.research_unlocks.append("garage");assert(Game.build_workshop("garage"));assert(not Game.garage.buy("buggy"))
	Game.garage.unlocks.append("vehicle_buggy");assert(Game.garage.buy("buggy"));assert(Game.garage.starting_vehicle()=="buggy")
	var money=Game.credits;assert(not Game.garage.buy("buggy") and Game.credits==money)
	Game.garage.unlocks.append("vehicle_tank");Game.progression.level=5;assert(not Game.garage.buy("tank"))
	Game.garage.unlocks.append("vehicle_apc");Game.progression.level=2;assert(not Game.garage.buy("apc"));Game.progression.level=5;assert(Game.garage.buy("apc") and Game.garage.buy("tank"))
	Game.garage.choose("buggy");assert(not Game.garage.upgrade("buggy","armor"));Game.garage.unlocks.append("buggy_armor");assert(Game.garage.upgrade("buggy","armor"))
	assert(is_equal_approx(GarageCatalog.stats("buggy").hp,Balance.CONFIG.enemy("buggy").health*1.03))
	for kind in GarageCatalog.VEHICLES:
		var v=GarageCatalog.VEHICLES[kind]
		for stage in range(17):assert((GarageCatalog.weight("vehicle_"+kind,stage)>0)==(stage>=v.stage and stage<=v.last))
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat"
	assert(arena.player.kind=="buggy" and arena.player.vehicle_origin=="owned")
	var full=arena.player.max_hp;arena.player.hp=full*.6
	arena.vehicle.interact_vehicle();assert(arena.player.kind=="soldier")
	var own=arena.wrecks.back();assert(own.vehicle_origin=="owned" and is_equal_approx(own.armor,full*.6))
	arena.player.position=own.position+Vector3(.8,0,0);arena.vehicle.interact_vehicle();assert(arena.player.kind=="buggy" and is_equal_approx(arena.player.hp,full*.6))
	arena.begin_room(7);arena.phase="combat";assert(arena.player.vehicle_origin=="owned" and is_equal_approx(arena.player.hp,full*.6))
	arena.vehicle.interact_vehicle()
	for wreck in arena.wrecks.duplicate():wreck.spent=true;wreck.queue_free()
	arena.wrecks.clear()
	var capture=arena.make_wreck("tank",Vector2i(3,3),Vector2i.UP,false,GarageCatalog.stats("tank",arena,"captured",2).hp*.5,"captured",2);capture.salvaged=true
	arena.player.position=capture.position+Vector3(.8,0,0);arena.vehicle.interact_vehicle()
	assert(arena.player.vehicle_origin=="captured" and arena.player.vehicle_zone==2)
	var stock=GarageCatalog.stats("tank",arena,"captured",2);assert(is_equal_approx(arena.player.damage,stock.damage));var captured_hp=arena.player.hp
	arena.begin_room(8);arena.phase="combat";assert(arena.player.vehicle_origin=="captured" and is_equal_approx(arena.player.hp,captured_hp))
	# Player projectile carries the firing vehicle identity through later dismounts.
	var foe=arena.spawn_actor("soldier",Vector2i(2,2),false);foe.set_physics_process(false);foe.invulnerable=0
	var bullet=arena.spawn_bullet(arena.player,foe.position,Vector2i.UP,100,true);assert(bullet.vehicle_credit=="tank")
	foe.take_damage(100,Vector3.ZERO,bullet.vehicle_credit);assert(Game.progression.counters.get("kills_tank",0)==1)
	Game.progression.telegram_options.clear();Game.progression.prepare_telegrams();assert(Game.progression.telegram_options.size()==3)
	arena.queue_free();await get_tree().process_frame
	var original=Game.save_path;Game.save_path="/tmp/garage_profile.json";Game.save_enabled=true;Game.save_progress();Game.garage=load("res://scripts/garage/state.gd").new();Game.load_progress();Game.save_enabled=false;Game.save_path=original
	assert(Game.garage.owned.size()==3 and Game.garage.selected=="buggy" and Game.garage.level("buggy","armor")==1)
	Game.new_recipes.clear();var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);await get_tree().create_timer(.55).timeout
	hub.show_garage();await get_tree().create_timer(.15).timeout
	if DisplayServer.get_name()!="headless":RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/garage_workbench.png")
	assert(Game.garage.choose("") and Game.garage.starting_vehicle()=="")
	print("GARAGE PASS: recipes, sequence, prices, base gates, equipment, start mounted, dismount/remount, room carry, captured stock, kill credit, profile and UI")
	get_tree().quit()
