extends Control
var rows:Array=[]
var row_height=30.0
var font_size=13
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE;Texts.changed.connect(queue_redraw)
	add_theme_color_override("font_color",UiKit.INK);add_theme_color_override("font_placeholder_color",UiKit.MUTED)
	theme_changed.connect(queue_redraw)
func set_rows(value:Array):
	rows=value;queue_redraw()
func _draw():
	for i in range(rows.size()):
		var row=rows[i];var y=i*row_height
		draw_string(ThemeDB.fallback_font,Vector2(0,y+font_size),Texts.render(row[0]),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,get_theme_color("font_placeholder_color"))
		draw_string(ThemeDB.fallback_font,Vector2(0,y+font_size),UiKit.number(row[1])+str(row[3]) if row.size()>3 else UiKit.number(row[1]),HORIZONTAL_ALIGNMENT_RIGHT,size.x,font_size,get_theme_color("font_color"))
		var ratio=clampf(float(row[1])/maxf(.01,row[2]),0,1)
		var color=Color("e7a441").lerp(Color("6b9b67"),ratio)
		if ratio>0:draw_rect(Rect2(0,y+font_size+5,size.x*ratio,5),color)
