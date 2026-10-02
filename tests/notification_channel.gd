extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.phase="combat";arena.set_physics_process(false)
	arena.toast("Бомба у правой стены базы!");arena.toast("Бомба у правой стены базы!")
	assert(Game.notification_history.size()==1)
	# Only important messages reach the channel feed; technical ones stay in the journal.
	Game.notifications.post("Задание выполнено\nПостроить верстак","Командование","important");Game.notifications.post("Новое задание\nСобрать чертёж","Командование","important")
	await get_tree().create_timer(.35).timeout
	assert(Game.notifications.feed.get_child_count()==2 and not arena.hud.tip.visible)
	assert(Game.notifications.feed.position.y>=arena.hud.left_info.global_position.y+arena.hud.left_info.size.y)
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/channel_foot.png")
	arena.hud.set_process(false);arena.hud.set_transport_visible(true)
	await get_tree().create_timer(.3).timeout
	assert(Game.notifications.feed.get_child_count()==1)
	assert(arena.hud.left_info.size.is_equal_approx(Vector2(76,76)) and not arena.hud.weapon_bars.visible and not arena.hud.vehicle_label.visible,"compact weapon %s %s %s %s" % [arena.hud.left_info.size,arena.hud.weapon_bars.visible,arena.hud.vehicle_label.visible,arena.hud.is_processing()])
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/channel_vehicle.png")
	# The journal is the pause tablet opened on the notifications tab.
	arena.phase="paused";load("res://scripts/notifications/journal.gd").open(arena)
	await get_tree().create_timer(.1).timeout
	var tablet=get_tree().get_first_node_in_group("field_tablet");assert(tablet!=null and get_tree().paused and tablet.initial_tab=="notifications")
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/channel_journal.png")
	Game.notifications.mark_all();assert(Game.notifications.unread()==0)
	tablet.close();assert(not get_tree().paused)
	var directory="/tmp/war-cats-channel-%d" % Time.get_ticks_usec();DirAccess.make_dir_recursive_absolute(directory)
	var original=[Game.save_path,Game.profiles.directory,Game.profiles.selected,Game.save_blocked];Game.save_blocked=false;Game.profiles.directory=directory;Game.profiles.selected=true;Game.save_path=directory.path_join("channel_profile.json");Game.save_enabled=true
	assert(Game.save_progress());Game.notification_history.clear();Game.load_progress();assert(Game.notification_history.size()>=3 and Game.notifications.unread()==0)
	Game.save_enabled=false;Game.save_path=original[0];Game.profiles.directory=original[1];Game.profiles.selected=original[2];Game.save_blocked=original[3]
	print("CHANNEL PASS: deduplication, feed, compact weapon, modal pause, read state, persistence")
	get_tree().quit()
