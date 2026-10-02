extends Control
## Remaining time of an effect drawn like an ability cooldown: the spent part of the circle is shaded
## clockwise from 12 o'clock, a thin orange arc shows what is left. remaining <0 means "active, no timer".
var remaining=1.0
func set_remaining(value:float):
	if is_equal_approx(value,remaining):return
	remaining=value;queue_redraw()
func _draw():
	var center=size*.5;var radius=minf(size.x,size.y)*.5-1
	if remaining<0:
		draw_arc(center,radius,0,TAU,40,Color(UiKit.ORANGE,.8),2,true);return
	var spent=1.0-clampf(remaining,0,1)
	if spent>0:
		var points=PackedVector2Array([center])
		for i in range(41):
			var angle=-PI/2+TAU*remaining+TAU*spent*i/40
			points.append(center+Vector2(cos(angle),sin(angle))*radius)
		draw_colored_polygon(points,Color(0,0,0,.5))
	draw_arc(center,radius,-PI/2,-PI/2+TAU*remaining,40,UiKit.ORANGE,2,true)
