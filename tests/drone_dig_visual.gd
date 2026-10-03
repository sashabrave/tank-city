extends Node
## T-071: a planting drone burrows halfway into the ground and becomes the bomb. Window shots
## /tmp/r13-dig-0.png (start) and /tmp/r13-dig-1.png (dug in).
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func shot(path):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(path)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=31;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	await get_tree().create_timer(.8).timeout
	arena.phase="combat";arena.room.spawn_queue.clear()
	var cell=Vector2i(arena.room.base_cell.x+2,arena.room.grid_size-2)
	var drone=arena.spawn_actor("drone",cell,false);drone.position=arena.world_pos(cell)
	drone.set_physics_process(false);drone.set_process(false)
	await get_tree().create_timer(1.6).timeout
	var model=drone.model;var top=model.global_position.y
	await shot("/tmp/r13-dig-0.png")
	var bomb=load("res://scenes/bomb.tscn").instantiate();bomb.arena=arena;bomb.position=drone.position;bomb.drone_model=model;bomb.timer=99.0
	arena.add_child(bomb);arena.room.bombs.append(bomb);arena.room.actors.erase(drone);drone.dead=true;drone.queue_free()
	await get_tree().create_timer(.12).timeout;await shot("/tmp/r13-dig-mid.png")
	await get_tree().create_timer(.4).timeout
	check(is_instance_valid(model) and model.get_parent()==bomb,"drone model becomes the bomb")
	check(model.global_position.y<top-.05,"drone sinks into the ground (%.2f → %.2f)" % [top,model.global_position.y])
	check(bomb.has_node("Blink"),"fuse light on top")
	await shot("/tmp/r13-dig-1.png")
	print("DRONE DIG: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
