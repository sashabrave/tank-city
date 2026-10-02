extends Node
## Continue a saved run: the map opens without building a hidden battle room, the hero's vehicle
## survives the next map save, and entering the room restores it. The loading veil covers the switch.
var errors=0
func check(value:bool,message:String):
	if value:print("PASS ",message)
	else:errors+=1;push_error("FAIL: "+message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	# Main defers its own hub/profile screen on ready: let it settle before starting the run.
	var main=load("res://scripts/main.gd").new();add_child(main);await get_tree().process_frame;await get_tree().process_frame
	main.start_run();main.enter_room(0);await get_tree().process_frame
	main.show_map(1);await get_tree().process_frame
	var cp=Game.run_checkpoint.duplicate(true)
	cp.hero={"kind":"buggy","hp":3.0,"salvaged":false,"origin":"owned","zone":1}
	Game.run_checkpoint=cp.duplicate(true)
	var t0=Time.get_ticks_msec()
	await preload("res://scripts/ui/loading_veil.gd").run(main,main.resume_run)
	print("resume with veil: %d ms" % (Time.get_ticks_msec()-t0));await get_tree().process_frame
	var arena=main.run_arena
	check(arena.defer_room and not is_instance_valid(arena.player) and arena.walls.is_empty(),"no hidden battle room is built")
	check(main.current.get_script().resource_path.ends_with("route_map.gd") and main.current.hero_kind=="buggy","map shows the saved vehicle")
	check(Game.run_checkpoint.get("hero",{}).get("kind","")=="buggy","next map save keeps the hero")
	check(get_tree().root.get_children().all(func(n):return not n.get_script() or not n.get_script().resource_path.ends_with("loading_veil.gd")),"veil is removed after loading")
	var plan=RoutePlan.build(arena.run_seed)
	var lanes=RoutePlan.reachable(plan,1,main.route_choices,"").filter(func(id):return RoutePlan.node_branch(RoutePlan.chosen(plan,1,{1:id}))=="")
	if lanes.is_empty():print("RESUME FAST: no battle lane on stage 1 for this seed, room check skipped")
	else:
		main.enter_room(1,lanes[0]);await get_tree().process_frame
		check(is_instance_valid(main.run_arena.player) and main.run_arena.player.kind=="buggy","entering the room restores the vehicle")
	print("RESUME FAST: %d failures" % errors);get_tree().quit(1 if errors else 0)
