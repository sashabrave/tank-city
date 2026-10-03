extends Control
## Progress pips (design system): done — translucent fill, current — accent, ahead — outline only. Used for
## fields and waves. With fit_width the pips stretch or shrink to the space left in the panel (T-078); an
## optional big boss dot closes the strip (the field commander after the last wave).
var count=6
var done=0
var current=0
var boss=-1  # -1 none, 0 ahead, 1 now, 2 beaten
var fit_width=0.0
const SIZE=Vector2(14,6)
const GAP=5.0
const BOSS=14.0
const BOSS_COLOR=Color("e2493b")
func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE
func set_state(total:int,finished:int,active:int,boss_state:int=-1,width:float=0.0):
	if total==count and finished==done and active==current and boss_state==boss and is_equal_approx(width,fit_width):return
	count=total;done=finished;current=active;boss=boss_state;fit_width=width
	custom_minimum_size=Vector2(fit_width if fit_width>0 else count*(pip_width()+GAP)-GAP+boss_extra(),BOSS if boss>=0 else SIZE.y);size=custom_minimum_size;queue_redraw()
func boss_extra()->float:return GAP+3.0+BOSS if boss>=0 else 0.0
func pip_width()->float:
	if fit_width<=0:return SIZE.x
	return clampf((fit_width-boss_extra()-GAP*(count-1))/maxf(1,count),5.0,24.0)
func _draw():
	var w=pip_width();var y=(size.y-SIZE.y)*.5
	for i in range(count):
		var rect=Rect2(Vector2(i*(w+GAP),y),Vector2(w,SIZE.y))
		if i==current:draw_style_box(UiKit.style(UiKit.ORANGE,3,UiKit.ORANGE),rect)
		elif i<done:draw_style_box(UiKit.style(Color(UiKit.INK,.38),3,Color(UiKit.INK,.38)),rect)
		else:
			var hollow=UiKit.style(Color.TRANSPARENT,3,Color(UiKit.MUTED,.55));hollow.set_border_width_all(1);draw_style_box(hollow,rect)
	if boss>=0:
		var center=Vector2(count*(w+GAP)-GAP+GAP+3.0+BOSS*.5,size.y*.5)
		if boss==1:draw_circle(center,BOSS*.5,BOSS_COLOR)
		elif boss==2:draw_circle(center,BOSS*.5,Color(BOSS_COLOR,.38))
		else:draw_arc(center,BOSS*.5-.75,0,TAU,24,Color(BOSS_COLOR,.75),1.5,true)
