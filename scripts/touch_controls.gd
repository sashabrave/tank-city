@tool
extends Control
# Independent finger tracking: moving one thumb does not release the fire thumb.
var left_fingers: Dictionary = {}
var fire_fingers: Dictionary = {}
var enabled = true
@export var fire_mode = false:
	set(v):fire_mode=v;queue_redraw()
var mouse_down = false

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE

# Visible bounds: x=30..245, preserving the hub pad's former right midpoint.
# All movement screens share this bottom-anchored layout.
func apply_movement_layout():
	anchor_left=0.0;anchor_right=0.0;anchor_top=1.0;anchor_bottom=1.0
	offset_left=30.0;offset_right=245.0
	offset_top=-237.5;offset_bottom=-22.5
	queue_redraw()

func _draw():
	if fire_mode:
		var pressed=false if Engine.is_editor_hint() else Game.touch_fire
		draw_circle(size*.5,67,Color("665135dc") if pressed else Color("252e27b8"))
		draw_arc(size*.5,73,0,TAU,64,UiKit.ORANGE,2,true)
		draw_circle(size*.5,22,Color("f0edd5"),false,3,true)
		draw_line(size*.5+Vector2(-30,0),size*.5+Vector2(30,0),Color("f0edd5"),3,true)
		draw_line(size*.5+Vector2(0,-30),size*.5+Vector2(0,30),Color("f0edd5"),3,true)
	else:
		var center=size*.5
		var pad_scale=minf(size.x,size.y)/190.0
		for d in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
			var rect=Rect2(center+(d*65-Vector2(30,30))*pad_scale,Vector2(60,60)*pad_scale)
			var color=Color("e1b05e") if not Engine.is_editor_hint() and Game.touch_direction==Vector2i(d) else Color("e0e5d6")
			draw_style_box(UiKit.style(color,int(14*pad_scale),Color("a8b39f")),rect)
			var a=center+d*66*pad_scale
			var normal=Vector2(-d.y,d.x)
			draw_colored_polygon(PackedVector2Array([a+d*12*pad_scale,a+(-d*7+normal*10)*pad_scale,a+(-d*7-normal*10)*pad_scale]),Color("bcc0ad"))
		draw_circle(center,14*pad_scale,Color("acb7a2"))

func direction_at(pos: Vector2) -> Vector2i:
	var d=pos-size*.5
	if d.length()<22*minf(size.x,size.y)/190.0: return Vector2i.ZERO
	if absf(d.x)>absf(d.y): return Vector2i(signi(int(d.x)),0)
	return Vector2i(0,signi(int(d.y)))

func _input(event):
	if Engine.is_editor_hint():return
	if not enabled or not is_visible_in_tree(): return
	var id=-100
	var point=Vector2.ZERO
	var pressed=false
	var released=false
	var motion=false
	if event is InputEventScreenTouch:
		id=event.index;point=event.position;pressed=event.pressed;released=not event.pressed
	elif event is InputEventScreenDrag:
		id=event.index;point=event.position;motion=true
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		id=-1;point=event.position;pressed=event.pressed;released=not event.pressed
	elif event is InputEventMouseMotion:
		id=-1;point=event.position;motion=true
	else: return
	var local=get_global_transform_with_canvas().affine_inverse()*point
	var within=Rect2(Vector2.ZERO,size).has_point(local)
	var fingers=fire_fingers if fire_mode else left_fingers
	if pressed and within:
		fingers[id]=local
	elif motion and fingers.has(id): fingers[id]=local
	elif released: fingers.erase(id)
	if fire_mode:
		Game.touch_fire=not fire_fingers.is_empty()
	else:
		Game.touch_direction=direction_at(left_fingers.values().back()) if not left_fingers.is_empty() else Vector2i.ZERO
	queue_redraw()

func clear():
	left_fingers.clear();fire_fingers.clear();Game.reset_input();queue_redraw()
