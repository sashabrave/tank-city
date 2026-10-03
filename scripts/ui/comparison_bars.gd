extends Control
## Compact comparison bars: name and value on one line, the bar right under them. A row {"group": "…"}
## starts a titled block; rows inside a block flow in one or two columns (adaptive_columns, width ≥ 440).
var rows:Array=[]
var row_height=64.0
var adaptive_columns=false
const GROUP_HEIGHT=30.0
const GROUP_GAP=10.0
## Smooth change (2026-10-03): every stat remembers the value last shown under its title; a new value glides
## there in ANIMATE seconds and the number counts in tenths, so a swap of gun or ammo reads as a change.
const ANIMATE:=.45
static var shown:={}
var from:={}
var progress:=1.0
func columns()->int:return 2 if adaptive_columns and size.x>=440 else 1
## Position of every row: [x, y, width] (group rows span the full width), plus the total height.
func layout()->Dictionary:
	var cols=columns();var width=(size.x-24*(cols-1))/cols
	var places=[];var top=0.0;var index=0
	for r in rows:
		if r.has("group"):
			# A new block starts under the rows of the previous one.
			top+=ceilf(float(index)/cols)*row_height+(GROUP_GAP if not places.is_empty() else 0.0)
			places.append([0.0,top,size.x]);top+=GROUP_HEIGHT;index=0;continue
		places.append([(index%cols)*(width+24),top+floorf(float(index)/cols)*row_height,width]);index+=1
	return {"places":places,"height":top+ceilf(float(index)/cols)*row_height}
func content_height()->float:return layout().height
func reflow():
	custom_minimum_size.y=content_height();size.y=custom_minimum_size.y;queue_redraw()
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_theme_color_override("font_color",UiKit.INK);add_theme_color_override("font_placeholder_color",UiKit.MUTED)
	Texts.changed.connect(queue_redraw);Settings.changed.connect(func():queue_redraw.call_deferred())
	row_height=minf(row_height,46.0)
	resized.connect(reflow);reflow()
	for r in rows:
		if r.has("group") or not r.has("current"):continue
		var key=str(r.title)+str(r.get("unit",""))
		if shown.has(key) and absf(float(shown[key])-float(r.current))>.0001:from[key]=float(shown[key])
		shown[key]=float(r.current)
	if not from.is_empty() and UiKit.motion_enabled():progress=0.0
	set_process(progress<1.0)
func _process(delta):
	progress=minf(1.0,progress+delta/ANIMATE);queue_redraw()
	if progress>=1.0:set_process(false)
## The value drawn this frame: eased from the last shown one, in tenths while it moves.
func live(r:Dictionary)->float:
	var key=str(r.title)+str(r.get("unit",""))
	if progress>=1.0 or not from.has(key):return float(r.current)
	var k=1.0-pow(1.0-progress,3.0)
	return snappedf(lerpf(float(from[key]),float(r.current),k),.1)
func _draw():
	var font=UiKit.field_font();var places=layout().places
	for i in range(rows.size()):
		var r=rows[i];var x=places[i][0];var y=places[i][1];var width=places[i][2]
		if r.has("group"):
			draw_string(font,Vector2(x,y+19),Texts.render(r.group),HORIZONTAL_ALIGNMENT_LEFT,width,13,get_theme_color("font_placeholder_color"))
			draw_rect(Rect2(x,y+GROUP_HEIGHT-4,width,1),Color(get_theme_color("font_placeholder_color"),.35))
			continue
		var current=live(r)
		var delta=current-float(r.base)
		var value=UiKit.number(current)+Texts.localized(r.unit)
		if absf(delta)>.005:value+="  ("+UiKit.number(r.base)+(" + " if delta>0 else " − ")+UiKit.number(absf(delta))+")"
		var value_w=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		draw_string(font,Vector2(x,y+18),Texts.render(r.title),HORIZONTAL_ALIGNMENT_LEFT,maxf(40,width-value_w-10),15,get_theme_color("font_color"))
		draw_string(font,Vector2(x,y+18),value,HORIZONTAL_ALIGNMENT_RIGHT,width,14,UiKit.ORANGE if delta>.005 else get_theme_color("font_placeholder_color"))
		var cap=maxf(maxf(r.base,maxf(r.current,current))*1.15,1);var bar_y=y+27
		draw_rect(Rect2(x,bar_y,width,5),Color("c7cbbb") if Settings.values.ui_theme=="light" else Color("3d453b"))
		draw_rect(Rect2(x,bar_y,width*minf(r.base,current)/cap,5),Color("687663") if Settings.values.ui_theme=="light" else Color("a7afa0"))
		if absf(delta)>.005:draw_rect(Rect2(x+width*minf(r.base,current)/cap,bar_y,width*absf(delta)/cap,5),Color("ff9b21") if delta>0 else Color("cb725c"))
