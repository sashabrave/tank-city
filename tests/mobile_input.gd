extends Node
var failures=0
func verify(value: bool,text: String):
	if not value:failures+=1;push_error(text)
	else:print("PASS: ",text)
func touch(pad,index,pos,pressed):
	var e=InputEventScreenTouch.new();e.index=index;e.position=pad.get_global_transform_with_canvas()*pos;e.pressed=pressed;pad._input(e)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena)
	arena.phase="combat";arena.set_physics_process(false)
	var d=arena.hud.dpad;var f=arena.hud.fire_pad;d.enabled=true;f.enabled=true
	touch(d,0,Vector2(115,40),true);touch(f,1,Vector2(90,90),true)
	verify(Game.touch_direction==Vector2i.UP and Game.touch_fire,"two-finger move and fire")
	var drag=InputEventScreenDrag.new();drag.index=0;drag.position=d.get_global_transform_with_canvas()*Vector2(200,115);d._input(drag)
	verify(Game.touch_direction==Vector2i.RIGHT and Game.touch_fire,"direction drag preserves fire finger")
	touch(d,0,Vector2(200,115),false)
	verify(Game.touch_direction==Vector2i.ZERO and Game.touch_fire,"release movement independently")
	touch(f,1,Vector2(90,90),false)
	verify(not Game.touch_fire,"release fire independently")
	touch(d,0,Vector2(115,40),true);touch(f,1,Vector2(90,90),true)
	arena.pause_battle()
	verify(Game.touch_direction==Vector2i.ZERO and not Game.touch_fire,"pause clears held fingers")

	arena.phase="combat";d.enabled=true;d.clear()
	touch(d,0,Vector2(115,40),true);touch(d,0,Vector2(115,40),false)
	touch(d,0,Vector2(115,40),true);touch(d,0,Vector2(115,40),false)
	verify(Game.touch_direction==Vector2i.ZERO,"double tap releases normally")
	touch(d,0,Vector2(115,40),true);touch(d,0,Vector2(115,40),false)
	touch(d,0,Vector2(115,40),true);touch(d,0,Vector2(115,40),false)
	verify(not InputMap.has_action("strafe"),"no strafe action remains")
	arena.free();print("MOBILE INPUT: 7 checks, ",failures," failures");get_tree().quit(failures)
