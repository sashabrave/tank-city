extends Node3D
## «Глубина света»: grid AO strips along walls, AgX day light; window shots /tmp/r13-depth-on.png / -off.png.
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
	Settings.values.world_lighting="day";Settings.values.sun_day="morning";Settings.values.weather="clear"
	get_window().size=Vector2i(1600,900)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=21;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.4).timeout;arena.set_physics_process(false)
	var ao=arena.get_node_or_null("FloorAO")
	check(ao!=null and ao.multimesh.instance_count>0,"AO strips along walls (%d)" % (ao.multimesh.instance_count if ao else 0))
	await shot("/tmp/r13-depth-on.png")
	Settings.change("depth_light",false);await get_tree().create_timer(.3).timeout
	check(not ao.visible,"switch hides the AO")
	await shot("/tmp/r13-depth-off.png")
	Settings.change("depth_light",true);await get_tree().create_timer(.3).timeout
	await shot("/tmp/r13-depth-on2.png")
	Settings.values.sun_day="random";Settings.values.weather="random"
	print("DEPTH: %d failures" % failures);get_tree().quit(1 if failures else 0)
