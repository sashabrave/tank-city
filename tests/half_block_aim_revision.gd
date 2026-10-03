extends Node3D
## T-002: an enemy straight above the HQ does not keep firing down into indestructible cover (a concrete
## half-block or corner); with only brick in between it still breaches.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=3;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(.8).timeout;arena.set_physics_process(false)
	var base=arena.base_cell;var spot=base+Vector2i(0,-3);var cover=base+Vector2i(0,-2)
	for c in [spot,cover,base+Vector2i(0,-1)]:
		if arena.walls.has(c):arena.walls[c].node.queue_free();arena.walls.erase(c)
	var enemy=arena.spawn_actor("soldier",spot,false);enemy.assault_time=5.0;enemy.set_physics_process(false)
	arena.add_wall(cover,-1);arena.board.shape_wall(cover,0)
	check(arena.enemy.enemy_aim(enemy)!=Vector2i.DOWN,"no firing down into a concrete half-block")
	arena.walls[cover].node.queue_free();arena.walls.erase(cover);arena.add_wall(cover,4)
	check(arena.enemy.concrete_to_base(spot)==false,"brick in between still counts as breachable")
	print("HALF BLOCK AIM: %d failures" % failures);get_tree().quit(1 if failures else 0)
