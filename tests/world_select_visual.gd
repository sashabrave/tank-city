extends Node
## World select: collectible cards, last unlocked world preselected (E starts it), locked cards dark.
## Window shots /tmp/r13-worlds-*.png. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func settle(n:=3):
	for i in n:await get_tree().process_frame
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	get_window().size=Vector2i(1600,900)
	var before=Game.progression.cleared_worlds.duplicate()
	Game.progression.cleared_worlds=[]
	var picker=preload("res://scripts/ui/world_select.gd").new();add_child(picker);await settle(10)
	check(picker.current==0,"only world 1 open: it is preselected")
	var chosen=[]
	picker.selected.connect(func(w,inf):chosen.append([w,inf]))
	var press=InputEventAction.new();press.action="interact";press.pressed=true;Input.parse_input_event(press);await settle(3)
	check(chosen.size()==1 and chosen[0][0]==1,"E starts the preselected world")
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-worlds-first.png")
	picker.queue_free();await settle(3)
	Game.progression.cleared_worlds=[1]
	picker=preload("res://scripts/ui/world_select.gd").new();add_child(picker);await settle(10)
	check(picker.current==1,"after world 1 the newest open world (2) is preselected")
	picker.focus(2);var none=[];picker.selected.connect(func(w,inf):none.append(w));picker.launch()
	check(none.is_empty(),"a locked world does not start")
	picker.focus(1)
	if DisplayServer.get_name()!="headless":await settle(10);await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-worlds-second.png")
	Game.progression.cleared_worlds=before
	print("WORLD SELECT: %d failures" % failures);get_tree().quit(1 if failures else 0)
