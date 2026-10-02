extends Node3D
## Dog general statues: only in built-up biomes; window shot /tmp/r13-statue.png of the first urban room that has one.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=1;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(.8).timeout;arena.set_physics_process(false)
	var found=false;var natural_ok=true
	for s in range(1,60):
		arena.run.run_seed=s;arena.run_seed=s
		for room in [2,4,5]:
			arena.begin_room(room)
			var has=arena.walls.values().any(func(w):return w.get("style_kind","")=="concrete_statue")
			if has and arena.room_palette().family not in ["urban","desert","ash"]:natural_ok=false
			if has and not found:
				found=true;await get_tree().create_timer(.6).timeout
				if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-statue.png")
		if found and s>30:break
	check(found,"a statue appears in some built-up room")
	check(natural_ok,"no statues in natural biomes")
	print("STATUE: %d failures" % failures);get_tree().quit(1 if failures else 0)
