extends Node3D
## T-044: an unopened commander chest holds the exit flag back; taking or declining the chest places it.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=3;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(.8).timeout;arena.set_physics_process(false)
	arena.room.spawn_queue.clear()
	for a in arena.room.actors.duplicate():
		if is_instance_valid(a) and not a.player_owned:a.dead=true;arena.room.actors.erase(a);a.queue_free()
	arena.reward.drop_recipe(arena.player.cell+Vector2i(1,-2),{"elite":true})
	arena.room.wave=2;arena.room.room_boss_spawned=true;arena.phase="combat";arena.flow.finish_wave();await get_tree().process_frame
	check(not is_instance_valid(arena.room.flag) and arena.room.has_meta("pending_flag"),"no exit while the chest is unopened")
	var chest=arena.room.pickups.filter(func(p):return p.kind=="recipe_draft")[0]
	arena.reward.consume_chest(chest);await get_tree().process_frame
	check(is_instance_valid(arena.room.flag) and not arena.room.has_meta("pending_flag"),"exit appears once the chest is done")
	print("CHEST FLAG: %d failures" % failures);get_tree().quit(1 if failures else 0)
