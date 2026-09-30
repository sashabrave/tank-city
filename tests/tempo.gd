extends Node
var failures=0
func check(ok,message):
	if not ok:failures+=1;push_error(message)
	else:print("PASS: ",message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena)
	arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat"
	for room in range(5):
		arena.begin_room(room);arena.phase="combat"
		for i in range(15):arena.drop_pickup(arena.base_cell,"repair")
		check(arena.pickups.all(func(p):return arena.grid_pos(p.node.position).y<int(arena.grid_size/2.0) and not arena.walls.has(arena.grid_pos(p.node.position))),"pickups reachable in upper half room %d" % room)
	for wall in arena.walls.values():wall.node.queue_free()
	arena.walls.clear()
	for kind in ["soldier","apc","tank","grenadier","boss"]:
		var a=arena.spawn_actor(kind,Vector2i(0,0),false);a.set_physics_process(false);a.movement_pause=0
		var count=2 if kind in ["apc","grenadier"] else 1
		for step in range(count):
			a.try_move(Vector2i.DOWN)
			check(a.moving,"burst starts "+kind)
			a.position=arena.actor_world_pos(a,a.destination)
			a._physics_process(.01)
		check(a.movement_pause>0 and not a.moving,"pause after burst "+kind)
		a.try_move(Vector2i.DOWN);check(not a.moving,"pause blocks next move "+kind)
		arena.actors.erase(a);a.free()
	arena.free();print("TEMPO failures: ",failures);get_tree().quit(failures)
