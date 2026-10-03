extends Node
var errors=0
func _ready():call_deferred("run")
func shot(name:String):
	await get_tree().create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/r13-"+name+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Settings.values.fullscreen=false;Settings.values.world_lighting="day";Settings.apply()
	var memory=load("res://scripts/ui/tablet_memory.gd");memory.loaded=true;memory.state={}
	for language in ["ru","en"]:
		Settings.change("language",language);Settings.change("ui_theme","dark" if language=="ru" else "light")
		for page in ["inventory","fighter","settings","notifications"]:
			var view=load("res://scripts/ui/field_tablet.gd").new();view.tab=page;add_child(view)
			view.settings_tab="Интерфейс";view.refresh()
			await shot(page+"-"+language)
			var bars=view.find_children("*","Control",true,false).filter(func(n):return n.get_script()==load("res://scripts/ui/comparison_bars.gd"))
			for bar in bars:
				if bar.columns()!=2:errors+=1;push_error("Expected two columns on "+page)
			view.queue_free();await get_tree().process_frame
	# A narrow viewport retains the full tablet and its close button.
	get_tree().root.content_scale_size=Vector2i(1000,700)
	var narrow=load("res://scripts/ui/field_tablet.gd").new();narrow.tab="fighter";add_child(narrow)
	await shot("narrow-tablet");narrow.queue_free();await get_tree().process_frame
	get_tree().root.content_scale_size=Vector2i(1440,810)
	# A constrained column switches to one and grows to fit long translated labels.
	var fixture=Control.new();add_child(fixture)
	var bars=load("res://scripts/ui/stat_snapshot.gd").add_bars(fixture,Vector2(40,40),360,load("res://scripts/ui/stat_snapshot.gd").fighter(),64,true)
	if bars.columns()!=1 or bars.content_height()!=bars.rows.size()*64:errors+=1
	await shot("narrow-bars");fixture.queue_free();await get_tree().process_frame
	Settings.change("language","ru");Settings.change("ui_theme","dark");Campaign.configure(2)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false)
	for seed_value in [0,3,4,5,8]:
		arena.run_seed=seed_value-5;arena.begin_room(5);arena.phase="upgrade"
		for actor in arena.actors:actor.set_physics_process(false)
		await get_tree().create_timer(1.6).timeout
		await shot("biome-"+str(seed_value))
	arena.queue_free();await get_tree().process_frame
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);hub.set_physics_process(false)
	await get_tree().create_timer(.6).timeout
	load("res://scripts/ui/build_menu.gd").show(hub);await shot("construction");hub.close_station()
	hub.open_station("fighter");await shot("fighter-station");hub.close_station()
	hub.queue_free();await get_tree().process_frame
	hub.open_station("hq");await shot("headquarters");hub.close_station();await get_tree().process_frame
	Settings.open();await shot("standalone-settings");Settings.close()
	print("TERRAIN UI VISUAL failures ",errors);get_tree().quit(1 if errors else 0)
