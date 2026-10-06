extends Node
## T-336: with the barrier on one side broken, infantry coming from any side walks to the hole and shoots the
## HQ through it (it used to stop half a cell off the base line and stand there silent).
var failures=0
func _ready():call_deferred("run")
func remove_wall(arena,cell):
	if arena.walls.has(cell):arena.walls[cell].node.queue_free();arena.walls.erase(cell);arena.navigation.invalidate(cell)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1);Engine.physics_ticks_per_second=240
	for start in [Vector2i(-3,-1),Vector2i(-2,-1),Vector2i(-4,0),Vector2i(-1,-2),Vector2i(-3,-3)]:
		var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;arena.run_seed=7;add_child(arena)
		await get_tree().create_timer(.3).timeout
		arena.set_physics_process(false);arena.phase="combat";arena.spawn_queue.clear();arena.base_hp=10000
		for a in arena.actors:a.set_physics_process(false);a.dead=true
		arena.player.position=arena.world_pos(Vector2i(0,0));arena.player.cell=Vector2i(0,0)
		remove_wall(arena,arena.base_cell+Vector2i.LEFT)
		var cell=arena.base_cell+start
		for dx in range(-1,2):
			for dy in range(-1,2):
				if cell+Vector2i(dx,dy)!=arena.base_cell and absi(start.x+dx)>1 or start.y+dy<-1:remove_wall(arena,cell+Vector2i(dx,dy))
		var e=arena.spawn_actor("soldier",cell,false);e.set_physics_process(false);e.enemy_weapon="rifle"
		var before=arena.base_hp;var frames=0
		while frames<1800 and arena.base_hp>=before:
			e._physics_process(1.0/60)
			for b in arena.projectiles.duplicate():
				if is_instance_valid(b):b.set_physics_process(false);b._physics_process(1.0/60)
			frames+=1;await get_tree().physics_frame
		var ok=arena.base_hp<before
		print("PASS " if ok else "FAIL ","soldier from ",start," shoots the HQ through the breach (",snappedf(frames/60.0,.1)," s)")
		if not ok:failures+=1
		arena.queue_free();await get_tree().process_frame
	print("BREACH: %d failures" % failures);get_tree().quit(1 if failures else 0)
