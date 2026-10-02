extends Control
## Incoming video call: a round handset button in the top-right corner that pulses and buzzes softly
## until the player answers. It never blocks movement; a click, tap or Enter opens the call.
signal answered
const SIDE=72.0
const RING_EVERY=2.2
const LOUD_RINGS=3
var call_id=""
var button:Button
var caption:Label
var clock=0.0
var rings=0
var next_ring=.3
func _ready():
	name="IncomingCall";mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=60
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button=Button.new();add_child(button);button.name="Answer";button.size=Vector2(SIDE,SIDE);button.pivot_offset=Vector2(SIDE,SIDE)*.5
	var round=StyleBoxFlat.new();round.bg_color=Color("3f9a5a");round.set_corner_radius_all(int(SIDE*.5));round.border_color=Color("e8f3df");round.set_border_width_all(3)
	var hover=round.duplicate();hover.bg_color=Color("4fb16b")
	for state in ["normal","focus"]:button.add_theme_stylebox_override(state,round)
	for state in ["hover","pressed"]:button.add_theme_stylebox_override(state,hover)
	button.icon=UiKit.interface_icon("call");button.expand_icon=true;button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;button.add_theme_constant_override("icon_max_width",30)
	button.tooltip_text=Texts.localized("Ответить на вызов")
	button.pressed.connect(answer)
	caption=UiKit.label(self,"Вызов · "+preload("res://scripts/ui/video_call.gd").MAJOR,Vector2.ZERO,Vector2(260,22),14,Color("f2f1df"))
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption.add_theme_color_override("font_outline_color",Color(0,0,0,.6));caption.add_theme_constant_override("outline_size",4)
	resized.connect(layout);layout()
func layout():
	button.position=Vector2(size.x-SIDE-28,104)
	caption.position=Vector2(button.position.x+SIDE-caption.size.x,button.position.y+SIDE+6)
func _process(delta):
	clock+=delta
	next_ring-=delta
	if next_ring<=0:
		next_ring=RING_EVERY;rings+=1
		if rings<=LOUD_RINGS:Game.sound("call_ring",self)
	# Two short shakes per ring, like a phone vibrating on a table, then a calm pulse.
	var phase=fposmod(clock+.3,RING_EVERY)
	var buzzing=rings<=LOUD_RINGS and (phase<.3 or (phase>.42 and phase<.72))
	button.rotation=sin(clock*70)*.09 if buzzing else 0.0
	button.scale=Vector2.ONE*(1.0+.05*sin(clock*4))
func _unhandled_input(event):
	# Enter only: Space fires in the hub range.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
		get_viewport().set_input_as_handled();answer()
func answer():
	if is_queued_for_deletion():return
	answered.emit();queue_free()
