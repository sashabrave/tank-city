extends Node
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	var c=load("res://scripts/music_controller.gd").new();c.preferences_path="/tmp/tank-radio-test.json";Game.music_controller=c;add_child(c);c.ratings={}
	assert("hub_evening_dial" in c.TRACKS.hub)
	c.rate("hub_evening_dial",-1);assert("hub_evening_dial" not in c.eligible("hub"))
	c.change("hub",true);assert(c.current_track!="hub_evening_dial" and c.repeat_mode==1)
	c.rate("hub_evening_dial",1);assert("hub_evening_dial" in c.eligible("hub"))
	var view=load("res://scripts/ui/field_tablet.gd").new();view.tab="inventory";add_child(view)
	for tab in ["inventory","fighter","notifications","music"]:
		view.tab=tab;view.refresh();await get_tree().process_frame
		if DisplayServer.get_name()!="headless":
			await get_tree().create_timer(.2).timeout;RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/refresh-"+tab+".png")
	view.music_folder="favorites";view.refresh();assert(view.music_folder=="favorites")
	c.change("battle",true);assert(view.music_folder=="favorites" and c.current_track in c.TRACKS.battle)
	Game.sound_enabled=true;c.play_track("hub_evening_dial");await get_tree().create_timer(.1).timeout;c.seek(5)
	assert(absf(c.position_seconds()-5)<.3)
	var audio=Game.audio();assert(audio.banks.has("ui_hover") and audio.banks.has("ui_denied"));Game.sound_enabled=false
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await get_tree().process_frame
	main.enter_room(0);await get_tree().process_frame
	var arena=main.run_arena;arena.auto_pause_enabled=false
	view.arena=arena
	for tab in ["inventory","fighter"]:view.tab=tab;view.refresh();await get_tree().process_frame
	preload("res://scripts/ui/tablet_pages.gd").new(view).weapon_details(arena.weapon)
	arena.run.damage_bonus+=1
	var live=preload("res://scripts/ui/stat_snapshot.gd").weapon(arena,arena.weapon);assert(live[0].current>live[0].base)
	main.queue_free()
	var stats=preload("res://scripts/ui/stat_snapshot.gd").weapon(null,"pistol");assert(stats.size()==4 and stats[0].base==stats[0].current)
	Game.notifications.post("Тест задания","Командование","important");Game.notifications.post("Тест боя")
	assert(Game.notifications.category(Game.notification_history.back())=="technical")
	view.queue_free();await get_tree().process_frame
	print("PASS tablet pages, stat source, music groups, ratings, scene transition, message categories")
	get_tree().quit()
