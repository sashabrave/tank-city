extends CanvasLayer
## Presentation only: no damage, roster or input mutation.
var arena
var heading:Label
var caption:Label
var text_tween:Tween
var pulse=0.0
var last_phase=""
var departing=false
## Camera as an orbit around the field: yaw, elevation, distance and zoom are smoothed separately,
## so moving between framings is a clean arc instead of a straight slide with a spinning field.
## A "swoop" blends toward a scripted framing: in at the start of a room, out when the HQ leaves.
const YAW=10.0
## 5% closer than before (author request, 0.7.2): the border may leave the frame, the cells never do
## (camera_fit test).
const NORMAL={"yaw":YAW,"elev":53.6,"dist":23.6,"zoom":.95}
const OVERVIEW={"yaw":YAW,"elev":62.0,"dist":25.5,"zoom":1.026}
var view=NORMAL.duplicate()
var focus=Vector3.ZERO
var swoop={}
var swoop_weight=0.0
var swoop_tween:Tween
var follow:Node3D
var tilt:Node
func _ready():
	layer=30
	heading=Label.new();heading.set_meta("keep_theme_colors",true);add_child(heading);UiKit.accent(heading);heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;heading.add_theme_color_override("font_color",Color.WHITE)
	heading.add_theme_color_override("font_shadow_color",Color(0,0,0,.35));heading.add_theme_constant_override("shadow_offset_y",3)
	caption=Label.new();caption.set_meta("keep_theme_colors",true);add_child(caption);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption.add_theme_color_override("font_color",Color.WHITE)
	caption.add_theme_color_override("font_shadow_color",Color(0,0,0,.7));caption.add_theme_constant_override("shadow_offset_y",2)
	layout();get_viewport().size_changed.connect(layout);heading.modulate.a=0;caption.modulate.a=0
func layout():
	if not is_inside_tree():return
	var size=get_viewport().get_visible_rect().size
	heading.size=Vector2(size.x*.88,140);heading.pivot_offset=heading.size*.5
	heading.position=Vector2(size.x*.06,size.y*.25);heading.scale=Vector2(.72,1.18)
	heading.add_theme_font_size_override("font_size",clampi(roundi(size.x*.036),34,84))
	caption.size=Vector2(size.x*.9,50);caption.position=Vector2(size.x*.05,size.y*.25+115)
	caption.add_theme_font_size_override("font_size",clampi(roundi(size.x*.014),18,38))
func announce(title:String,subtitle:String="",hold:float=.7):
	if text_tween and text_tween.is_valid():text_tween.kill()
	Texts.set_text(heading,title);Texts.set_text(caption,subtitle);heading.modulate.a=0;caption.modulate.a=0
	text_tween=create_tween().set_parallel(true)
	text_tween.tween_property(heading,"modulate:a",1.0,.16);text_tween.tween_property(caption,"modulate:a",1.0,.16)
	text_tween.chain().tween_interval(hold)
	text_tween.chain().tween_property(heading,"modulate:a",0.0,.3)
	text_tween.parallel().tween_property(caption,"modulate:a",0.0,.3)
func fade_in():
	var shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color.BLACK;shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var tween=create_tween();tween.tween_property(shade,"color:a",0.0,.5);tween.tween_callback(shade.queue_free)
func prepare_wave(index:int):
	departing=false;pulse=0;last_phase="countdown"
	if index==0:fade_in()
	# Big letters only when they tell something new: the next wave, the boss, the last fight. The first wave just fades in.
	if Campaign.is_final(arena.room_index):announce("Последний бой","Приготовься",.9)
	elif arena.boss_room:announce("Бой с генералом","Приготовься",.9)
	elif index>0:announce("Волна %d" % (index+1),WaveDirector.wave_hint(index),.7)
func miniboss(difficulty:int):
	last_phase="combat";pulse=.75;announce("Командир "+EncounterRules.STARS[difficulty], EncounterRules.reward_text(difficulty),.9)
func _process(delta):
	if not is_instance_valid(arena) or not arena.is_inside_tree() or not is_instance_valid(arena.camera):return
	var phase=arena.phase;var base=arena.grid_size+5.0
	heading.visible=phase!="paused";caption.visible=phase!="paused"
	if phase=="paused":return
	var overview=phase in ["upgrade","map","result"] or (phase=="countdown" and arena.countdown>.85)
	var goal:Dictionary=(OVERVIEW if overview else NORMAL).duplicate()
	# Between waves the field leans a few degrees toward the cursor or a drag; never in combat.
	if tilt==null:tilt=preload("res://scripts/camera_tilt.gd").new();tilt.name="CameraTilt";add_child(tilt)
	tilt.enabled=phase in ["upgrade","result"] and swoop_weight<=0.01
	goal.yaw+=tilt.yaw();goal.elev+=tilt.pitch()
	if pulse>0:pulse=maxf(0,pulse-delta);goal.zoom=.985
	if swoop_weight>0:
		for key in goal:goal[key]=lerpf(goal[key],swoop[key],swoop_weight)
	var k=minf(1.0,delta*(9.0 if swoop_weight>0 else 4.0))
	for key in view:view[key]=lerpf(view[key],goal[key],k)
	var target=follow.global_position*.3 if is_instance_valid(follow) and swoop_weight>0 else Vector3.ZERO
	focus=focus.lerp(target,k)
	var elev=deg_to_rad(view.elev);var yaw=deg_to_rad(view.yaw)
	var offset=Vector3(0,sin(elev),cos(elev))*view.dist
	arena.camera.position=focus+offset.rotated(Vector3.UP,yaw);arena.camera.look_at(focus)
	arena.camera.size=base*view.zoom
	if phase=="combat" and last_phase=="countdown" and arena.boss_room and not arena.challenges.active():announce("","Уничтожь командира",.4)
	last_phase=phase

## Swoop in: start high and turned to the HQ's side, settle into the play framing as it parks.
func swoop_in(side:float,duration:=1.1):
	swoop={"yaw":YAW+side*26.0,"elev":68.0,"dist":27.0,"zoom":1.28}
	view=swoop.duplicate();focus=Vector3.ZERO;follow=null
	run_swoop(1.0,0.0,duration,Tween.EASE_OUT)
## Swoop out: rise and turn after the departing HQ, drifting a little after it.
func swoop_out(side:float,hq:Node3D,duration:=1.2):
	swoop={"yaw":YAW-side*18.0,"elev":64.0,"dist":26.0,"zoom":1.14};follow=hq
	run_swoop(0.0,1.0,duration,Tween.EASE_IN_OUT)
func run_swoop(from:float,to:float,duration:float,ease:int):
	if swoop_tween:swoop_tween.kill()
	swoop_weight=from
	swoop_tween=create_tween();swoop_tween.tween_property(self,"swoop_weight",to,duration).set_trans(Tween.TRANS_CUBIC).set_ease(ease)

