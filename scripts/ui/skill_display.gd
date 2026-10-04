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
## A placed mine waits for the key (T-295): the tile shows a red, blinking «Подрыв» instead of the countdown.
var detonate=false
var clock=0.0
func _process(delta):
	if detonate:clock+=delta;queue_redraw()
func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE
func plate_text()->String:
	if detonate:return Texts.render("Подрыв")+(" · "+InputScheme.glyph(action) if action!="" else "")
	if cooling and remaining>0.05:return str(ceili(remaining))
	if action!="":return InputScheme.glyph(action)
	return key_hint
func _draw():
	var center=Vector2(38,38)
	if cooling and active<=0:
		# Recharging reads at a glance: the icon is dimmed, the refilled part brightens back (T-059).
		draw_circle(center,31,Color(0,0,0,.46))
		var points=PackedVector2Array([center])
		for i in range(65):
			var angle=-PI/2+TAU*progress*i/64
			points.append(center+Vector2(cos(angle),sin(angle))*31)
		if progress>0:draw_colored_polygon(points,Color(1,1,1,.18))
		draw_arc(center,31,-PI/2,-PI/2+TAU*progress,64,Color(1,1,1,.65),2,true)
	var font=UiKit.field_font()
	if active>0:
		draw_circle(Vector2(70,5),17,Color("f2f1df"))
		draw_arc(Vector2(70,5),17,0,TAU,32,Color("50565a"),2,true)
		draw_string(font,Vector2(55,11),str(ceili(active)),HORIZONTAL_ALIGNMENT_CENTER,30,16,Color("28362a"))
	if detonate:
		# Red lamp ring, blinking like the mine itself.
		var on=fposmod(clock*2.5,1.0)<.55
		draw_arc(center,33,0,TAU,64,Color(1,.2,.2,.95 if on else .35),3,true)
		draw_circle(Vector2(64,12),6,Color("ff3b2a") if on else Color("5a1d18"))
	var text=plate_text()
	if text=="":return
	if detonate:
		var w=maxf(30,font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+14);var r=Rect2((76-w)*.5,80,w,22)
		draw_style_box(UiKit.style(Color("3a1a17"),6,Color("ff5a48")),r)
		draw_string(font,Vector2(r.position.x,r.position.y+16),text,HORIZONTAL_ALIGNMENT_CENTER,w,14,Color("ffb3a8"))
		return
	var counting=cooling and remaining>0.05
	var width=maxf(30,font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+14)
	var plate=Rect2((76-width)*.5,80,width,22)
	# Accent means "ready": the key glows in the accent colour; a countdown is plain bold white on dark.
	var ready_key=not counting and action!=""
	draw_style_box(UiKit.style(Color("3a3222") if ready_key else Color("151a17"),6,UiKit.ORANGE if ready_key else Color("8a918a")),plate)
	draw_string(font,Vector2(plate.position.x,plate.position.y+16),text,HORIZONTAL_ALIGNMENT_CENTER,width,15 if counting else 14,UiKit.ORANGE if ready_key else Color.WHITE)
