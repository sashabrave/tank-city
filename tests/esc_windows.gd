extends Node
## T-189: Esc closes the topmost window first (class path → Barracks), and only with nothing open does it
## bring up the pause tablet. Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func esc():
	var e=InputEventAction.new();e.action="pause";e.pressed=true;Input.parse_input_event(e)
	await get_tree().process_frame;await get_tree().process_frame
	var u=InputEventAction.new();u.action="pause";u.pressed=false;Input.parse_input_event(u)
	await get_tree().process_frame
func key(action:String):
	var q=InputEventAction.new();q.action=action;q.pressed=true;Input.parse_input_event(q);await get_tree().process_frame;await get_tree().process_frame
	var u=InputEventAction.new();u.action=action;u.pressed=false;Input.parse_input_event(u);await get_tree().process_frame
func tablet_open(_hub)->bool:return not get_tree().get_nodes_in_group("field_tablet").is_empty()
# from tablet_resume: raw Escape key presses.
func escape_key(pressed:bool):
	var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.physical_keycode=KEY_ESCAPE;event.pressed=pressed
	Input.parse_input_event(event);Input.flush_buffered_events()
# from mobile_input: a finger on a touch pad.
func touch(pad,index,pos,pressed):
	var e=InputEventScreenTouch.new();e.index=index;e.position=pad.get_global_transform_with_canvas()*pos;e.pressed=pressed;pad._input(e)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Engine.set_meta("hub_calls_off",true)
	# The hub on its practice-run arena: windows close first, then Esc reaches the arena's pause (the tablet).
	var hub=preload("res://scripts/hub.gd").open_practice(self);await get_tree().create_timer(1.0).timeout
	hub.phase="combat"
	hub.open_station("fighter");await get_tree().create_timer(.3).timeout
	# T-178 / T-220: Q / E walk the Barracks' main tabs, now a row on top.
	await key("interact")
	check(hub.build_menu.tab=="general","E moves to the next main tab")
	await key("class_ability")
	check(hub.build_menu.tab=="shells","Q comes back to «Классы»")
	var page=hub.build_menu.find_child("Page",true,false)
	page.open_path();await get_tree().process_frame
	await esc()
	check(is_instance_valid(hub.build_menu) and page.get_node_or_null("ClassPathView")==null,"Esc closes the class path, the Barracks stays")
	await esc()
	check(not is_instance_valid(hub.build_menu) and not tablet_open(hub),"Esc closes the Barracks without the pause tablet on top")
	await esc()
	check(tablet_open(hub),"with nothing open Esc brings up the pause tablet")
	var over_hub=get_tree().get_first_node_in_group("field_tablet")
	check(over_hub!=null and over_hub.get_child(0).can_leave==false and over_hub.get_child(0).can_restart==false,"the hub's tablet has nothing to leave or restart")
	for t in get_tree().get_nodes_in_group("field_tablet"):t.queue_free()
	get_tree().paused=false
	hub.queue_free();await get_tree().process_frame
	# Field checks share one arena. Order matters: touch input switches the HUD to the touch layout, so it runs last.
	process_mode=Node.PROCESS_MODE_ALWAYS;Game.reset_upgrades()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false
	await get_tree().process_frame
	# from notification_channel: toast dedupe, important messages reach the feed, journal = tablet on the notifications tab,
	# read state and the history in the profile (written only into a fresh temp folder).
	arena.phase="combat";arena.set_physics_process(false);Game.notification_history.clear()
	arena.toast("Бомба у правой стены базы!");arena.toast("Бомба у правой стены базы!")
	check(Game.notification_history.size()==1,"repeated toast is stored once")
	Game.notifications.post("Задание выполнено\nПостроить верстак","Командование","important");Game.notifications.post("Новое задание\nСобрать чертёж","Командование","important")
	await get_tree().create_timer(.35).timeout
	check(Game.notifications.feed.get_child_count()==2,"important messages reach the channel feed")
	arena.phase="paused";load("res://scripts/notifications/journal.gd").open(arena)
	await get_tree().create_timer(.1).timeout
	var journal=get_tree().get_first_node_in_group("field_tablet")
	check(journal!=null and get_tree().paused and journal.initial_tab=="notifications","journal opens the pause tablet on notifications")
	Game.notifications.mark_all();check(Game.notifications.unread()==0,"mark all read")
	if journal:journal.close()
	check(not get_tree().paused,"closing the journal resumes")
	var directory=OS.get_temp_dir().path_join("warcats_channel_%d" % Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(directory)
	var original=[Game.save_path,Game.profiles.directory,Game.profiles.selected,Game.save_blocked]
	Game.save_blocked=false;Game.profiles.directory=directory;Game.profiles.selected=true;Game.save_path=directory.path_join("channel_profile.json");Game.save_enabled=true
	var saved=Game.save_progress();Game.notification_history.clear();Game.load_progress()
	Game.save_enabled=false;Game.save_path=original[0];Game.profiles.directory=original[1];Game.profiles.selected=original[2];Game.save_blocked=original[3]
	check(saved and Game.notification_history.size()>=3 and Game.notifications.unread()==0,"history and read state survive the profile")
	# from tablet_resume: in a field Esc opens the tablet in combat and countdown; Esc, «Продолжить» or the cross resume the same phase.
	for i in range(3):await get_tree().process_frame
	for phase in ["combat","countdown"]:
		for method in ["escape","continue","cross"]:
			arena.phase=phase;arena.countdown=100
			escape_key(true);await get_tree().process_frame;escape_key(false)
			var tablet=get_tree().get_first_node_in_group("field_tablet")
			check(tablet!=null and get_tree().paused and arena.phase=="paused","Esc opens the tablet in "+phase)
			if tablet==null:continue
			if method=="escape":escape_key(true)
			else:
				var label="Продолжить [Esc]" if method=="continue" else "Закрыть планшет"
				for button in tablet.get_child(0).find_children("*","Button",true,false):
					if button.tooltip_text==label:button.pressed.emit();break
			await get_tree().physics_frame;await get_tree().process_frame
			escape_key(false)
			check(not get_tree().paused and arena.phase==phase and get_tree().get_nodes_in_group("field_tablet").is_empty(),"closing via %s resumes %s" % [method,phase])
			if get_tree().paused:get_tree().paused=false
	# from mobile_input: two-finger touch controls, independent release, pause clears held fingers.
	arena.phase="combat"
	# The HUD shows the pads only in the touch scheme; the original ran before the first HUD frame, so show them here.
	var d=arena.hud.dpad;var f=arena.hud.fire_pad;d.enabled=true;f.enabled=true;d.visible=true;f.visible=true
	touch(d,0,Vector2(115,40),true);touch(f,1,Vector2(90,90),true)
	check(Game.touch_direction==Vector2i.UP and Game.touch_fire,"two-finger move and fire")
	var drag=InputEventScreenDrag.new();drag.index=0;drag.position=d.get_global_transform_with_canvas()*Vector2(200,115);d._input(drag)
	check(Game.touch_direction==Vector2i.RIGHT and Game.touch_fire,"direction drag preserves the fire finger")
	touch(d,0,Vector2(200,115),false)
	check(Game.touch_direction==Vector2i.ZERO and Game.touch_fire,"movement releases independently")
	touch(f,1,Vector2(90,90),false)
	check(not Game.touch_fire,"fire releases independently")
	touch(d,0,Vector2(115,40),true);touch(f,1,Vector2(90,90),true)
	arena.pause_battle()
	check(Game.touch_direction==Vector2i.ZERO and not Game.touch_fire,"pause clears held fingers")
	for t in get_tree().get_nodes_in_group("field_tablet"):t.queue_free()
	get_tree().paused=false;await get_tree().process_frame
	arena.phase="combat";d.enabled=true;d.visible=true;d.clear()
	for i in range(2):touch(d,0,Vector2(115,40),true);touch(d,0,Vector2(115,40),false)
	check(Game.touch_direction==Vector2i.ZERO,"double tap releases normally")
	check(not InputMap.has_action("strafe"),"no strafe action remains")
	arena.queue_free();await get_tree().process_frame
	print("ESC WINDOWS: %d failures" % failures);get_tree().quit(1 if failures else 0)
