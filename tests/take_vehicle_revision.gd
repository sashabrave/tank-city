extends Node
## T-011: on foot at the mechanic, E at the parked vehicle buys it for the next field.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Campaign.configure(1);Game.profiles.selected=true
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await settle();await settle()
	main.start_run();await settle()
	main.enter_room(0,RoutePlan.build(Game.visual_run_seed)[0][1].id);await settle()
	var arena=main.run_arena;arena.pending_vehicle=""
	main.show_service("vehicle",2);await get_tree().create_timer(.5).timeout
	var room=main.current;Game.credits=500
	check(room.has_node("TakeVehicleLabel"),"on foot the parked vehicle is offered")
	var price=int(room.VEHICLE_PRICES.get(room.vehicle,80));var before=Game.credits
	room.avatar.position=room.PARKED+Vector3(-.8,0,.6);room.interact();await settle()
	check(arena.pending_vehicle==room.vehicle and Game.credits==before-price,"taking it costs alloy and waits at the next field")
	print("TAKE VEHICLE: %d failures" % failures);get_tree().quit(1 if failures else 0)
