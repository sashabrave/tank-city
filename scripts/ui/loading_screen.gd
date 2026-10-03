extends CanvasLayer
## Loading screen (2026-10-03): covers the first frames of a heavy scene — the hub at launch and the first
## battle of a session — while the GPU compiles shader pipelines (a cold first launch stalls for seconds, a
## warm one barely at all). It stays until frames run smoothly for a short while, then fades out; the
## warm case therefore only flashes for about half a second. Visual only: no game state, no RNG.
const STEADY_FRAMES:=8      # this many smooth frames in a row…
const SMOOTH_MS:=40.0       # …each faster than this, and the scene is warm
const MIN_SECONDS:=.5
const MAX_SECONDS:=40.0
const TIPS=["Окопы роются, каша варится","Майор ищет очки","Коты занимают позиции","Штаб пересчитывает сплав","Танкисты протирают перископы","Бочки расставлены, не курить"]
static var first_battle_done:=false
var started:=0
var steady:=0
var last:=0
var bar:Control
var stripe:ColorRect
var tip:Label
var closing:=false

## Covers the screen until the next scene is warm. Returns the screen; it frees itself.
static func cover(parent:Node,text:="")->CanvasLayer:
	var screen=load("res://scripts/ui/loading_screen.gd").new();screen.name="LoadingScreen";parent.add_child(screen)
	if text!="":Texts.set_text(screen.tip,text)
	return screen
## The first battle of a session compiles the battle effects: cover it once.
static func cover_first_battle(parent:Node):
	if first_battle_done or DisplayServer.get_name()=="headless":return
	first_battle_done=true;cover(parent,"Выдвигаемся на позиции")

func _init():
	layer=128;process_mode=Node.PROCESS_MODE_ALWAYS
	var root=Control.new();add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_STOP;root.name="Root"
	var bg=ColorRect.new();root.add_child(bg);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.color=Color("1d2420")
	var center=CenterContainer.new();root.add_child(center);center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column=VBoxContainer.new();center.add_child(column);column.add_theme_constant_override("separation",22);column.alignment=BoxContainer.ALIGNMENT_CENTER
	var logo=TextureRect.new();column.add_child(logo);logo.texture=load("res://assets/ui/branding_v1/war_cats_logo_v2.png");logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;logo.custom_minimum_size=Vector2(420,220)
	bar=Panel.new();column.add_child(bar);bar.custom_minimum_size=Vector2(320,8);bar.clip_contents=true
	var track=StyleBoxFlat.new();track.bg_color=Color(1,1,1,.08);track.set_corner_radius_all(4);bar.add_theme_stylebox_override("panel",track)
	stripe=ColorRect.new();bar.add_child(stripe);stripe.color=Color("f2a33a");stripe.size=Vector2(96,8)
	tip=Label.new();column.add_child(tip);tip.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;tip.add_theme_color_override("font_color",Color("9fa89a"));tip.add_theme_font_size_override("font_size",18)
	Texts.set_text(tip,TIPS[Time.get_ticks_usec()%TIPS.size()])  # visual only: never the game RNG
func _ready():
	started=Time.get_ticks_msec()
	if DisplayServer.get_name()=="headless":queue_free()
func _process(_delta):
	var now=Time.get_ticks_msec()
	# The stripe runs across the bar; a stall shows as a pause, which is honest.
	stripe.position.x=fposmod(now*.25,bar.size.x+stripe.size.x)-stripe.size.x
	if last>0:steady=steady+1 if now-last<SMOOTH_MS else 0
	last=now
	if closing:return
	var elapsed=(now-started)/1000.0
	if (elapsed>=MIN_SECONDS and steady>=STEADY_FRAMES) or elapsed>=MAX_SECONDS:
		closing=true
		var root:Control=get_node("Root")
		var t=root.create_tween();t.tween_property(root,"modulate:a",0.0,.25);t.tween_callback(queue_free)
