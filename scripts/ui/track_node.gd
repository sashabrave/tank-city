extends Control
## A node on a progress track (class path, «Развитие заставы»): a round medal for milestones, a small dot for
## plain steps. done — green with a tick (or its icon); goal — glowing, with a ring that fills as the player
## gets closer (progress 0..1, e.g. alloy saved for the price); later — hollow and dimmed.
var status:="later"
var icon:Texture2D
var progress:=0.0
var milestone:=false
var glow:=0.0
## A step number drawn in the middle instead of ticks and icons (roadmap, T-191): done — dark on green,
## goal — light on dark with the orange ring, later — muted.
var number:=""
const GREEN=Color("8fe895")

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE;pivot_offset=size*.5
	if status=="goal" and UiKit.motion_enabled():
		var t=create_tween().set_loops();t.tween_property(self,"glow",1.0,.9).set_trans(Tween.TRANS_SINE);t.tween_property(self,"glow",0.0,.9).set_trans(Tween.TRANS_SINE)
func _process(_d):
	if status=="goal":queue_redraw()
## A short pop when the node was just reached (level bought, reward claimed).
func celebrate():
	scale=Vector2.ONE*1.5
	var t=create_tween();t.tween_property(self,"scale",Vector2.ONE,.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _draw():
	var c=size*.5;var r=minf(size.x,size.y)*.5
	if status=="goal":
		draw_circle(c,r+4+glow*5,Color(UiKit.ORANGE,.10+glow*.10))
		draw_circle(c,r+2,Color(UiKit.ORANGE,.18))
	var fill=Color("2f4a36") if status=="done" else Color("3a3122") if status=="goal" else Color("232924")
	if status=="done" and (not milestone or number!=""):fill=GREEN
	draw_circle(c,r-1,fill)
	var width=3.0 if milestone else 2.0
	draw_arc(c,r-width*.5,0,TAU,48,Color(1,1,1,.14) if status!="done" else GREEN,width,true)
	if status=="goal" and progress>0.0:
		draw_arc(c,r-width*.5,-PI*.5,-PI*.5+TAU*clampf(progress,0,1),48,UiKit.ORANGE,width+1,true)
	if number!="":
		var font=get_theme_default_font();var fs=int(r*.9)
		var ink=Color("1b211d") if status=="done" else UiKit.INK if status=="goal" else Color(UiKit.MUTED,.8)
		var w=font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
		draw_string(font,c+Vector2(-w*.5,fs*.36),number,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,ink)
		return
	if icon:
		var side=r*1.25;var tint=Color(1,1,1,1.0 if status!="later" else .4)
		draw_texture_rect(icon,Rect2(c-Vector2(side,side)*.5,Vector2(side,side)),false,tint)
	elif status=="done":
		var font=get_theme_default_font();var fs=int(r*1.1)
		draw_string(font,c+Vector2(-fs*.32,fs*.36),"✓",HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color("1b211d"))
	if status=="done" and milestone:
		draw_circle(c+Vector2(r*.68,r*.68),r*.28,GREEN)
		var font=get_theme_default_font();var fs=int(r*.42)
		draw_string(font,c+Vector2(r*.68-fs*.32,r*.68+fs*.36),"✓",HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color("1b211d"))
