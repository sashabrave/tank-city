@tool
extends Control
const HEART_ICON=preload("res://assets/ui/branding_v1/health_heart.png")
const HQ_ICON=preload("res://assets/ui/branding_v1/headquarters_health.png")
@export var value=3.0:
	set(v):value=v;queue_redraw()
@export var maximum=3.0:
	set(v):maximum=v;queue_redraw()
@export_enum("heart","base","tank") var symbol="heart":
	set(v):symbol=v;queue_redraw()
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_theme_color_override("font_color",UiKit.INK)
	theme_changed.connect(queue_redraw)
func set_health(hp: float,max_hp: float):
	if value==hp and maximum==max_hp:return
	value=hp;maximum=max_hp;queue_redraw()
func _draw():
	var ratio=clampf(value/maxf(maximum,.001),0,1)
	var color=Color("d85b50").lerp(Color("e4bb54"),ratio*2) if ratio<.5 else Color("e4bb54").lerp(Color("6ba064"),(ratio-.5)*2)
	var ink=get_theme_color("font_color")
	if symbol=="heart" or symbol=="base":
		var texture=HEART_ICON if symbol=="heart" else HQ_ICON
		var dimensions=texture.get_size()
		var scale_factor=minf(34.0/dimensions.x,30.0/dimensions.y)
		var fitted=dimensions*scale_factor
		draw_texture_rect(texture,Rect2(Vector2(15,17)-fitted/2.0,fitted),false,ink if symbol=="base" else Color.WHITE)
	else:
		draw_rect(Rect2(4,10,23,14),ink);draw_line(Vector2(15,12),Vector2(15,3),ink,4)
	# Keep the last hit point readable; a living unit must never display zero.
	var current_text="%.1f" % maxf(.1,value) if value>0 and value<1 else str(roundi(value))
	draw_string(ThemeDB.fallback_font,Vector2(40,34),"%s / %s" % [current_text,str(roundi(maximum))],HORIZONTAL_ALIGNMENT_LEFT,-1,11,ink)
	var bg=StyleBoxFlat.new();bg.bg_color=Color("495244");bg.set_corner_radius_all(7)
	draw_style_box(bg,Rect2(40,10,size.x-40,14))
	if ratio>0:
		var fill=bg.duplicate();fill.bg_color=color
		draw_style_box(fill,Rect2(40,10,maxf(2,(size.x-40)*ratio),14))
