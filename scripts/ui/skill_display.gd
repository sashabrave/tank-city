extends Control
var progress=1.0
var cooling=false
var active=0.0
var key_hint="F"
func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw():
	var center=Vector2(38,38)
	if cooling and active<=0:
		draw_circle(center,31,Color(0,0,0,.14))
		var points=PackedVector2Array([center])
		for i in range(65):
			var angle=-PI/2+TAU*progress*i/64
			points.append(center+Vector2(cos(angle),sin(angle))*31)
		if progress>0:draw_colored_polygon(points,Color(1,1,1,.4))
		draw_arc(center,31,-PI/2,-PI/2+TAU*progress,64,Color(1,1,1,.65),2,true)
	if active>0:
		draw_circle(Vector2(70,5),17,Color("f2f1df"))
		draw_arc(Vector2(70,5),17,0,TAU,32,Color("50565a"),2,true)
		draw_string(ThemeDB.fallback_font,Vector2(55,10),str(ceili(active)),HORIZONTAL_ALIGNMENT_CENTER,30,16,Color("28362a"))
	draw_style_box(UiKit.style(Color("242d27"),5),Rect2(23,80,30,22))
	draw_string(ThemeDB.fallback_font,Vector2(0,96),key_hint,HORIZONTAL_ALIGNMENT_CENTER,76,14,UiKit.INK)
