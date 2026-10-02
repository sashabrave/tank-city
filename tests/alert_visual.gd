extends Node
## Task alert «!» above the command screen: big, glowing, hopping. Window shots /tmp/r13-alert-*.png.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	get_window().size=Vector2i(1600,900)
	Game.progression.seen.clear()
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(1.5).timeout
	check(hub.command_alert.visible,"alert shows with unseen tasks")
	var heights=[]
	for i in range(3):
		heights.append(hub.command_alert.position.y)
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-alert-%d.png" % i)
		await get_tree().create_timer(.23).timeout
	check(heights.max()-heights.min()>.15,"alert hops (%.2f)" % (heights.max()-heights.min()))
	hub.queue_free();await get_tree().process_frame
	print("ALERT: %d failures" % failures);get_tree().quit(1 if failures else 0)
