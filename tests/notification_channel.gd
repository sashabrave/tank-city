extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.phase="combat";arena.set_physics_process(false)
	arena.toast("Бомба у правой стены базы!");arena.toast("Бомба у правой стены базы!")
	assert(Game.notification_history.size()==1)
	Game.notifications.post("ЗАДАНИЕ ВЫПОЛНЕНО\nПостроить верстак","КОМАНДОВАНИЕ")
	await get_tree().create_timer(.35).timeout
	assert(Game.notifications.feed.get_child_count()==2 and not arena.hud.tip.visible)
	assert(Game.notifications.feed.position.y>=arena.hud.left_info.global_position.y+arena.hud.left_info.size.y)
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/channel_foot.png")
	arena.hud.set_process(false);arena.hud.set_transport_visible(true)
	await get_tree().create_timer(.3).timeout
	assert(Game.notifications.feed.get_child_count()==1)
	assert(arena.hud.left_info.size==Vector2(76,76) and not arena.hud.weapon_bars.visible and not arena.hud.vehicle_label.visible)
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/channel_vehicle.png")
	arena.hud.show_pause();arena.phase="paused"
	load("res://scripts/notifications/journal.gd").open(self)
	await get_tree().create_timer(.1).timeout
	assert(get_tree().paused)
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/channel_journal.png")
	Game.notifications.mark_all();assert(Game.notifications.unread()==0)
	get_tree().get_first_node_in_group("notification_journal").close();assert(not get_tree().paused)
	var original=Game.save_path;Game.save_path="/tmp/channel_profile.json";Game.save_enabled=true;Game.save_progress();Game.notification_history.clear();Game.load_progress();assert(Game.notification_history.size()>=2 and Game.notifications.unread()==0);Game.save_enabled=false;Game.save_path=original
	print("CHANNEL PASS: deduplication, feed, compact weapon, modal pause, read state, persistence")
	get_tree().quit()
