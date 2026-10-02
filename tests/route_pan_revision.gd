extends Node3D
## Two-finger trackpad scroll (InputEventPanGesture on macOS) moves the route map like the mouse wheel.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=42;route.available=2;add_child(route)
	await get_tree().create_timer(.8).timeout
	var before=route.scroll
	var pan=InputEventPanGesture.new();pan.delta=Vector2(0,-6);pan.position=Vector2(400,300)
	get_viewport().push_input(pan)
	await get_tree().process_frame
	check(route.scroll>before+1.0,"pan up scrolls the map forward (%.2f → %.2f)" % [before,route.scroll])
	var mid=route.scroll;pan=InputEventPanGesture.new();pan.delta=Vector2(0,4);get_viewport().push_input(pan);await get_tree().process_frame
	check(route.scroll<mid,"pan down scrolls back")
	print("ROUTE PAN: %d failures" % failures);get_tree().quit(1 if failures else 0)
