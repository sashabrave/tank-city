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
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Engine.set_meta("hub_calls_off",true)
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);await get_tree().create_timer(1.0).timeout
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
	for t in get_tree().get_nodes_in_group("field_tablet"):t.queue_free()
	get_tree().paused=false
	hub.queue_free();await get_tree().process_frame
	print("ESC WINDOWS: %d failures" % failures);get_tree().quit(1 if failures else 0)
