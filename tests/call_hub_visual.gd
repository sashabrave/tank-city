extends Node
## Window shot of the hub with an incoming call (/tmp/r13-call-hub.png); answer opens the video call.
## Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	get_window().size=Vector2i(1600,900)
	var p=Game.progression;p.seen=p.seen.filter(func(s):return not str(s).begins_with("call_"))
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(1.5).timeout
	var ring=hub.find_child("IncomingCall",true,false)
	check(ring!=null,"incoming call rings in the hub")
	# T-120: the call opens as a big dialog that holds the hub; «Позже» folds it into the corner handset.
	check(hub.phase=="ringing" and ring.find_child("CallDialog",true,false)!=null,"call shows a big dialog")
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-call-dialog.png")
	ring.postpone();await get_tree().process_frame
	check(hub.phase=="combat" and ring.button.visible,"«Позже» keeps it ringing in the corner, the hub is playable")
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-call-hub.png")
	if ring:ring.answer()
	await get_tree().create_timer(.6).timeout
	check(hub.find_children("*","Control",true,false).any(func(n):return n.get_script()==load("res://scripts/ui/video_call.gd")),"answer opens the video call")
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-call-open.png")
	hub.queue_free();await get_tree().process_frame
	print("CALL HUB: %d failures" % failures);get_tree().quit(1 if failures else 0)
