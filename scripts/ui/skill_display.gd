extends Control
## Ability tile overlay (design system, hub and battle). The plate under the tile shows, in order:
## seconds left while the ability recharges; the key (or gamepad button) when it is ready; nothing for
## passive and automatic tiles or on touch, where the tile itself is the button.
var progress=1.0
var cooling=false
var active=0.0
## Input action of the tile ("" for passive / automatic tiles).
var action=""
## Seconds until ready; shown on the plate while cooling.
var remaining=0.0
## Legacy fixed hint, used only when no action is set.
var key_hint=""
func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE
func plate_text()->String:
	if cooling and remaining>0.05:return str(ceili(remaining))
	if action!="":return InputScheme.glyph(action)
	return key_hint
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
	var font=UiKit.field_font()
	if active>0:
		draw_circle(Vector2(70,5),17,Color("f2f1df"))
		draw_arc(Vector2(70,5),17,0,TAU,32,Color("50565a"),2,true)
		draw_string(font,Vector2(55,11),str(ceili(active)),HORIZONTAL_ALIGNMENT_CENTER,30,16,Color("28362a"))
	var text=plate_text()
	if text=="":return
	var counting=cooling and remaining>0.05
	var width=maxf(30,font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+14)
	var plate=Rect2((76-width)*.5,80,width,22)
	draw_style_box(UiKit.style(Color("3a3222") if counting else Color("242d27"),6,UiKit.ORANGE if counting else Color("697166")),plate)
	draw_string(font,Vector2(plate.position.x,plate.position.y+16),text,HORIZONTAL_ALIGNMENT_CENTER,width,14,UiKit.ORANGE if counting else UiKit.INK)
