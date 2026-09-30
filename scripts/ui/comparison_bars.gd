extends Control
var rows:Array=[]
var row_height=64.0
var adaptive_columns=false
func columns()->int:return 2 if adaptive_columns and size.x>=440 else 1
func content_height()->float:return ceilf(float(rows.size())/columns())*row_height
func reflow():
	custom_minimum_size.y=content_height();size.y=content_height();queue_redraw()
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_theme_color_override("font_color",UiKit.INK);add_theme_color_override("font_placeholder_color",UiKit.MUTED)
	Texts.changed.connect(queue_redraw);Settings.changed.connect(func():queue_redraw.call_deferred())
	resized.connect(reflow);reflow()
func _draw():
	var font=UiKit.field_font()
	for i in range(rows.size()):
		var cols=columns();var width=(size.x-24*(cols-1))/cols;var x=(i%cols)*(width+24)
		var r=rows[i];var y=floori(float(i)/cols)*row_height;var delta=float(r.current)-float(r.base)
		var value=UiKit.number(r.current)+Texts.localized(r.unit)
		if absf(delta)>.005:value+="  ("+UiKit.number(r.base)+(" + " if delta>0 else " − ")+UiKit.number(absf(delta))+")"
		var title=TextParagraph.new();title.width=width;title.add_string(Texts.render(r.title),font,14)
		title.draw(get_canvas_item(),Vector2(x,y),get_theme_color("font_color"))
		draw_string(font,Vector2(x,y+row_height-21),value,HORIZONTAL_ALIGNMENT_RIGHT,width,13,get_theme_color("font_placeholder_color"))
		var cap=maxf(maxf(r.base,r.current)*1.15,1)
		draw_rect(Rect2(x,y+row_height-14,width,4),Color("c7cbbb") if Settings.values.ui_theme=="light" else Color("454d43"))
		draw_rect(Rect2(x,y+row_height-14,width*minf(r.base,r.current)/cap,4),Color("687663") if Settings.values.ui_theme=="light" else Color("a7afa0"))
		if absf(delta)>.005:draw_rect(Rect2(x+width*minf(r.base,r.current)/cap,y+row_height-14,width*absf(delta)/cap,4),Color("ff9b21") if delta>0 else Color("cb725c"))
