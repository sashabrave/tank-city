extends Node3D
## The number on the HQ wall (T-174, narrative direction 2026-10-03): «9», minus one for every boss beaten.
## Nobody explains it. It shows up now and then (about 20% of the time, in slow fades) like chalk you notice
## out of the corner of your eye; after a boss victory the hero comes back and watches it click down.
## What happens at 0 is not decided yet (it will open something — the endless front, maybe).
const START:=9
const CYCLE:=30.0  # seconds of one fade cycle
const SHOWN:=6.0   # seconds of it visible: 20% of the cycle
var label:Label3D
var clock:=0.0
var clicking:=false

static func value()->int:return maxi(0,START-int(Game.progression.counters.get("boss_wins",0)))

func _ready():
	name="WallCounter"
	label=Label3D.new();label.name="Number";add_child(label)
	label.font_size=240;label.pixel_size=.006;label.outline_size=0
	# A dark stencil: it reads on the light upper wall.
	label.modulate=Color("353a2e");label.shaded=false;label.double_sided=false
	label.alpha_cut=Label3D.ALPHA_CUT_DISABLED;label.no_depth_test=false
	var shown=int(Game.progression.counters.get("wall_shown",START))
	label.text=str(shown)
	# Start somewhere inside the cycle so a hub visit does not always open on it.
	clock=fposmod(float(Time.get_ticks_msec())*.001,CYCLE)
	if shown>value():click_down.call_deferred(shown)

## The drama: the old number holds, shakes, and gives way to the new one.
func click_down(from:int):
	clicking=true;label.text=str(from);label.modulate.a=0.0
	var t=create_tween()
	t.tween_interval(1.2)
	t.tween_property(label,"modulate:a",1.0,1.0)
	t.tween_interval(1.4)
	t.tween_method(func(v:float):label.position.x=sin(v*60.0)*.03,0.0,1.0,.5)
	t.tween_callback(func():
		label.text=str(value());label.position.x=0;label.scale=Vector3.ONE*1.35
		Game.sound("rare_reveal",self)
		Game.progression.counters["wall_shown"]=value();Game.save_progress())
	t.tween_property(label,"scale",Vector3.ONE,.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(4.0)
	t.tween_callback(func():clicking=false;clock=SHOWN)

func _process(delta):
	if clicking:return
	clock=fposmod(clock+delta,CYCLE)
	# Fade in over a second, hold, fade out — only during the first SHOWN seconds of the cycle.
	var a=0.0
	if clock<SHOWN:a=clampf(minf(clock,SHOWN-clock),0.0,1.0)
	label.modulate.a=a*.85
	visible=a>0.0
