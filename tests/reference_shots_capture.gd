extends Node
## Reference screenshots (roadmap stage 1, also Steam page candidates): one windowed run captures hub, battle,
## night storm, maze, route map and upgrade cards into art_requests/reference_shots_v1/. Not part of the suites.
## Run: Godot --path . tests/reference_shots_capture.tscn
const OUT="res://art_requests/reference_shots_v1/"
var n=0
func _ready():call_deferred("run")
func shot(name:String):
	await get_tree().create_timer(.4).timeout
	for i in range(3):await RenderingServer.frame_post_draw
	n+=1;var path=ProjectSettings.globalize_path(OUT)+"%02d_%s.png" % [n,name]
	get_viewport().get_texture().get_image().save_png(path);print("SHOT ",path)
func clear():
	for c in get_children():remove_child(c);c.queue_free()
	await get_tree().process_frame
func arena_scene(seed:int,setup:=Callable())->Node:
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=seed;arena.auto_pause_enabled=false
	if setup.is_valid():setup.call(arena)
	add_child(arena);return arena
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	Settings.values.show_fps=false;Settings.values.fullscreen=false;Settings.apply()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_window().size=Vector2i(1920,1080)
	for night in [false,true]:
		Settings.values.world_lighting="night" if night else "day";Settings.apply()
		var hub=preload("res://scripts/hub.gd").open_practice(self)
		await get_tree().create_timer(2.0).timeout;await shot("hub_"+("night" if night else "day"))
		await clear()
	# Battle in daylight, mid-wave.
	Settings.values.world_lighting="day";Settings.values.weather="clear";Settings.values.sun_day="golden";Settings.apply()
	var arena=arena_scene(21);await get_tree().create_timer(6.0).timeout;await shot("battle_golden")
	await clear()
	# Night storm.
	Settings.values.world_lighting="night";Settings.values.weather="rain";Settings.values.rain_style="downpour";Settings.apply()
	arena=arena_scene(8);await get_tree().create_timer(6.0).timeout
	var weather=arena.get_node_or_null("Weather")
	if weather:weather.storm_wait=0.0
	await get_tree().create_timer(.12).timeout;await shot("battle_night_storm")
	await clear()
	# Dark maze with zombies.
	Settings.values.weather="clear";Settings.values.rain_style="";Settings.apply()
	arena=arena_scene(11,func(a):a.sandbox=true;a.sandbox_mode="maze";a.sandbox_difficulty=1)
	await get_tree().create_timer(3.0).timeout;await shot("maze_night")
	await clear()
	# Route map and upgrade cards in daylight.
	Settings.values.world_lighting="day";Settings.apply()
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=5;add_child(route)
	await get_tree().create_timer(1.8).timeout;await shot("route_map")
	await clear()
	arena=arena_scene(4);await get_tree().create_timer(1.2).timeout;arena.set_physics_process(false)
	arena.room.upgrade_offers=[{"id":"burn_heat","tier":1},{"id":"crit_chance","tier":2},{"id":"health","tier":3}]
	arena.hud._show_upgrades_now();await get_tree().create_timer(1.2).timeout;await shot("upgrade_cards")
	await clear()
	# Service rooms: the field mechanic and the merchant (dusk light of the rooms).
	# One field engine: the rooms are the run arena in service mode with the room as its playground.
	for branch in ["vehicle","merchant"]:
		arena=arena_scene(4);await get_tree().create_timer(.8).timeout
		var room=load("res://scripts/merchant_room.gd" if branch=="merchant" else "res://scripts/service_room.gd").new()
		if branch!="merchant":room.branch=branch
		arena.begin_service(2,room)
		await get_tree().create_timer(1.4).timeout;await shot("room_"+("mechanic" if branch=="vehicle" else "merchant"))
		await clear()
	# World boss, golden light.
	Settings.values.sun_day="golden";Settings.apply()
	arena=arena_scene(1);await get_tree().create_timer(.8).timeout
	arena.begin_room(6);arena.phase="combat";arena.spawn_queue.clear()
	var spec=BossCatalog.encounter(1,6)
	for i in range(spec.count):
		var boss=arena.spawn_actor("boss",Vector2i(arena.grid_size/2-3+i*6,4),false);boss.wave_slot=i
	await get_tree().create_timer(2.5).timeout;await shot("boss_fight")
	Settings.values.show_fps=true;Settings.values.world_lighting="day";Settings.values.sun_day="random";Settings.values.weather="random"
	print("REFERENCE SHOTS: ",n)
	get_tree().quit()
