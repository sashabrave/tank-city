extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var rng=RandomNumberGenerator.new();rng.seed=27
	var generator=load("res://scripts/progression/adaptive_orders.gd")
	var orders=generator.create(Game.progression,rng);assert(orders.size()==3)
	for q in orders:
		# Goals count over 2–3 sorties (×1.5 / ×2), so the cap is the hardest single-sortie goal doubled.
		assert(q.goal<=roundi(generator.BASE[q.event]*1.15)*2 and not q.has("vehicle"))
	Game.progression.counters.depth=8;Game.progression.level=4;Game.progression.recent_sorties=[{"infantry":28,"waves":9,"drones":12},{"infantry":24,"waves":8,"drones":10}]
	rng.seed=27;var grown=generator.create(Game.progression,rng)
	assert(grown[2].difficulty=="Сложный")
	Game.progression.telegram_options=grown;Game.progression.choose_telegram(2);var goal=Game.progression.telegram.goal;Game.progression.counters.depth=16;Game.progression.prepare_telegrams();assert(Game.progression.telegram.goal==goal)
	# No selected order is needed to learn from a sortie.
	# Only sorties that reached combat are learned from (a map-only exit is not a sortie).
	Game.progression.telegram={};Game.progression.begin_run();Game.progression.combat_entered=true;Game.progression.event("infantry",17);Game.progression.end_run();assert(Game.progression.recent_sorties.back().infantry==17)
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=12;route.available=1;add_child(route);await get_tree().create_timer(.7).timeout
	var start=route.player_marker.position;var other=route.plan[3][0]
	route.travel_to_room(3,other.id);assert(route.preview_only and route.player_marker.position==start and is_instance_valid(route.modal))
	route.cancel_entry();assert(route.player_marker.position==start and not route.travelling)
	route.queue_free();await get_tree().process_frame
	var service=load("res://scripts/route_map.gd").new();service.wave_seed=12;service.available=2;service.needs_service=true;add_child(service);await get_tree().create_timer(.7).timeout
	# Service stops depend on the world (world 1: instructor and merchant); take the first one offered.
	var stop=service.service_choices[0]
	start=service.player_marker.position;service.choose_service(stop);await get_tree().create_timer(.5).timeout
	# Arrival waits on the stop (node card, E enters); no modal opens on its own.
	assert(not service.travelling and service.pending_service==stop and service.player_marker.position!=start)
	service.cancel_entry();await get_tree().create_timer(.6).timeout;assert(service.player_marker.position.is_equal_approx(start))
	service.queue_free();await get_tree().process_frame
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat"
	var enemy=arena.spawn_actor("soldier",Vector2i(3,1),false);enemy.set_physics_process(false);enemy.hidden_in_trench=true;enemy.idle_progress_time=13;enemy.route_points=[Vector2i(1,1)];enemy.movement_pause=5
	arena.enemy.attention_tick(enemy,.1);assert(enemy.assault_time>0 and not enemy.hidden_in_trench and enemy.trench_return_delay>0 and enemy.route_points.is_empty() and enemy.movement_pause==0)
	arena.queue_free();await get_tree().process_frame
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);await get_tree().create_timer(.55).timeout;hub.show_recipe_shop();hub.build_menu.category="garage";hub.build_menu.refresh();await get_tree().create_timer(.1).timeout
	if DisplayServer.get_name()!="headless":RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/recipe_shop_grouped.png")
	print("ADAPTIVE/ROUTES PASS: easy start, adaptive/fixed orders, unconnected preview stays put, service preview/cancel, enemy wakeup, grouped recipes")
	get_tree().quit()
