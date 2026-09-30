extends Control
## Progress pips (design system): done — light, current — accent, ahead — dim. Used for fields and waves.
var count=6
var done=0
var current=0
const SIZE=Vector2(14,6)
const GAP=5.0
func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE
func set_state(total:int,finished:int,active:int):
	if total==count and finished==done and active==current:return
	count=total;done=finished;current=active;custom_minimum_size=Vector2(count*(SIZE.x+GAP)-GAP,SIZE.y);size=custom_minimum_size;queue_redraw()
func _draw():
	for i in range(count):
		var color=UiKit.ORANGE if i==current else Color(UiKit.INK,.8) if i<done else Color(UiKit.MUTED,.3)
		draw_style_box(UiKit.style(color,3,color),Rect2(Vector2(i*(SIZE.x+GAP),0),SIZE))
