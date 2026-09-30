extends Control
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_theme_color_override("font_color",UiKit.INK);theme_changed.connect(queue_redraw)
func _draw():
	var points=PackedVector2Array()
	for i in range(33):
		var angle=i*TAU/32;points.append(Vector2(18+12*cos(angle),15+7*sin(angle)))
	draw_polyline(points,get_theme_color("font_color"),1.8,true);draw_circle(Vector2(18,15),3.5,get_theme_color("font_color"))
