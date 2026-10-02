extends Node3D
## Service room: themed dressing per branch, exit gate closed until the choice, walking out completes the room.
var errors=0
func check(value:bool,message:String):
	if value:print("PASS ",message)
	else:errors+=1;push_error("FAIL: "+message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.begin_room(1)
	await get_tree().process_frame;remove_child(arena)
	for branch in ["vehicle","ability","headquarters"]:
		var room=load("res://scripts/service_room.gd").new();room.arena=arena;room.branch=branch;room.index=2;add_child(room)
		await get_tree().process_frame
		check(is_instance_valid(room.dressing) and room.dressing.get_child_count()>20,branch+": themed dressing built")
		check(not room.dressing.open,branch+": exit closed before the choice")
		var done=[false];room.completed.connect(func(_i):done[0]=true)
		room.cell=room.dressing.EXIT_CELL+Vector2i.LEFT;room.avatar.position=Vector3(room.cell.x,0,room.cell.y);room.destination=room.avatar.position
		Game.touch_direction=Vector2i.RIGHT;await get_tree().physics_frame;await get_tree().physics_frame;Game.touch_direction=Vector2i.ZERO
		check(room.cell!=room.dressing.EXIT_CELL,branch+": gate blocks before the choice")
		room.skip_choice();check(room.dressing.open,branch+": gate opens after the choice")
		# T-083: leaving takes E in the exit zone; E anywhere else does nothing.
		room.avatar.position=Vector3(0,0,3);room.interact()
		check(not done[0],branch+": E away from the exit keeps the room")
		room.avatar.position=Vector3(room.dressing.EXIT_CELL.x-1,0,room.dressing.EXIT_CELL.y)
		Game.touch_direction=Vector2i.RIGHT
		for i in range(30):await get_tree().physics_frame
		Game.touch_direction=Vector2i.ZERO
		check(room.avatar.position.x>room.dressing.EXIT_CELL.x-.6,branch+": the hero walks into the open gate")
		room.interact()
		check(done[0],branch+": E at the gate completes the room")
		room.queue_free();await get_tree().process_frame
	arena.queue_free()
	print("SERVICE ROOM: %d failures" % errors);get_tree().quit(1 if errors else 0)
