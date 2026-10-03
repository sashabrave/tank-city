extends Control
var rows:Array=[]
var row_height=30.0
var font_size=13
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE;Texts.changed.connect(queue_redraw)
	add_theme_color_override("font_color",UiKit.INK);add_theme_color_override("font_placeholder_color",UiKit.MUTED)
	theme_changed.connect(queue_redraw)
## Smooth change (2026-10-03): each number glides to its new value (tenths while it moves) instead of jumping.
var shown:={}
func set_rows(value:Array):
	rows=value
	for row in rows:
		if not shown.has(row[0]) or not UiKit.motion_enabled():shown[row[0]]=float(row[1])
	set_process(true);queue_redraw()
func _process(delta):
	var moving=false
	for row in rows:
		var target=float(row[1]);var now=float(shown.get(row[0],target))
		if absf(target-now)<.005:shown[row[0]]=target;continue
		shown[row[0]]=lerpf(now,target,minf(1.0,delta*9.0));moving=true
	queue_redraw()
	if not moving:set_process(false)
func live(row:Array)->float:
	var value=float(shown.get(row[0],row[1]))
	return value if absf(value-float(row[1]))<.005 else snappedf(value,.1)
func _draw():
	for i in range(rows.size()):
		var row=rows[i];var y=i*row_height
		draw_string(ThemeDB.fallback_font,Vector2(0,y+font_size),Texts.render(row[0]),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,get_theme_color("font_placeholder_color"))
		draw_string(ThemeDB.fallback_font,Vector2(0,y+font_size),UiKit.number(live(row))+str(row[3]) if row.size()>3 else UiKit.number(live(row)),HORIZONTAL_ALIGNMENT_RIGHT,size.x,font_size,get_theme_color("font_color"))
		var ratio=clampf(live(row)/maxf(.01,row[2]),0,1)
		var color=Color("e7a441").lerp(Color("6b9b67"),ratio)
		if ratio>0:draw_rect(Rect2(0,y+font_size+5,size.x*ratio,5),color)
