extends Node3D
## Alloy crates sit pressed into corners against blocks; battle edge clouds fade near their lane ends.
## Window shot /tmp/r13-crates.png. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=21;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.2).timeout;arena.set_physics_process(false)
	var crates=arena.get_node("FieldCrates").crates
	check(crates.size()>0,"crates placed (%d)" % crates.size())
	var snug=crates.all(func(c):
		var pos:Vector3=c.node.global_position;var cell=arena.grid_pos(pos);var local=pos-arena.world_pos(cell)
		# Pressed to the cell edge facing a wall (the first crate of a pair also sits in the corner).
		return maxf(absf(local.x),absf(local.z))>.28 and [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN].any(func(d):return arena.walls.has(cell+d)))
	check(snug,"every crate is pressed against a block")
	var atmosphere=arena.find_children("*","",true,false).filter(func(n):return n.get_script()==load("res://scripts/world_atmosphere.gd"))
	if not atmosphere.is_empty():
		var a=atmosphere[0]
		check(a.drift_span>=arena.grid_size+40,"cloud lane reaches far past the screen")
		for entry in a.drifters:entry.node.position.z=a.drift_span*.5-1.0
		for i in range(3):await get_tree().process_frame
		check(a.drifters.all(func(e):return float(e.node.material_override.get_shader_parameter("opacity"))<.1),"clouds are nearly invisible at the lane end")
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-crates.png")
	print("CRATES CLOUDS: %d failures" % failures);get_tree().quit(1 if failures else 0)
