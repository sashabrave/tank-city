extends Control
## Incoming video call (T-120): first a big dialog like the greeting — a large photo of the caller, his name,
## «Взять» and «Позже»; «Позже» shrinks it to the round handset in the top-right corner that keeps ringing
## until answered (a click, tap or Enter opens the call).
signal answered
signal postponed
var dialog:Control
const SIDE=72.0
const RING_EVERY=2.2
const LOUD_RINGS=3
var call_id=""
var button:Button
var caption:Label
var clock=0.0
var rings=0
var next_ring=.3
## Where the dialog stood when answered: the conversation window grows out of it (T-182).
var answered_rect:=Rect2()
var take:Button
var photo_frame:Panel
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
	button.hide();caption.hide();open_dialog()
func open_dialog():
	dialog=Control.new();dialog.name="CallDialog";add_child(dialog);dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dialog.mouse_filter=Control.MOUSE_FILTER_STOP;dialog.add_to_group("selection_scope")
	var shade=ColorRect.new();dialog.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.35);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# Adaptive (T-181): the box follows the screen, the photo never squeezes the text column.
	var screen=get_viewport_rect().size;var w=minf(760,screen.x-32);var h=clampf(screen.y*.5,220,380)
	var box=UiKit.glass(dialog,((screen-Vector2(w,h))*Vector2(.5,.6)).round(),Vector2(w,h));box.name="CallBox"
	var side=minf(h-48,w*.42)
	var frame=Panel.new();box.add_child(frame);frame.position=Vector2(24,24);frame.size=Vector2(side,side);frame.add_theme_stylebox_override("panel",UiKit.style(Color("141b17"),12,Color("3f9a5a")));photo_frame=frame
	var photo=TextureRect.new();frame.add_child(photo);photo.position=Vector2(8,8);photo.size=frame.size-Vector2(16,16);photo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;photo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;photo.clip_contents=true
	photo.texture=load("res://assets/portraits/major.png") if ResourceLoader.exists("res://assets/portraits/major.png") else preload("res://scripts/ui/class_gallery.gd").texture("heavy")
	var x=24+side+28;var body=w-x-24
	UiKit.label(box,"Входящий видеовызов",Vector2(x,34),Vector2(body,24),16,UiKit.MUTED)
	UiKit.label(box,preload("res://scripts/ui/video_call.gd").MAJOR,Vector2(x,62),Vector2(body,40),30,UiKit.ORANGE)
	var line=UiKit.label(box,"Главная когтебаза на связи. Есть новости для заставы.",Vector2(x,112),Vector2(body,70),17);line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var later=UiKit.button(box,"Позже",Vector2(x,h-24-56),Vector2((body-12)*.4,56),postpone)
	take=UiKit.button(box,"Взять",Vector2(x+(body-12)*.4+12,h-24-56),Vector2((body-12)*.6,56),answer,true);take.name="Take"
	take.icon=UiKit.interface_icon("call");take.expand_icon=true;take.add_theme_constant_override("icon_max_width",22);take.add_theme_font_size_override("font_size",20)
	# A calm phone green, like a real «answer» button (T-181); it buzzes with the ring.
	var green=StyleBoxFlat.new();green.bg_color=Color("3f9a5a");green.set_corner_radius_all(13);green.border_color=Color("8fe895");green.set_border_width_all(2)
	var lit=green.duplicate();lit.bg_color=Color("4fb16b")
	take.add_theme_stylebox_override("normal",green);take.add_theme_stylebox_override("focus",green)
	for state in ["hover","pressed"]:take.add_theme_stylebox_override(state,lit)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:take.add_theme_color_override(key,Color("f4fbef"))
	take.add_theme_color_override("icon_normal_color",Color("f4fbef"));take.add_theme_color_override("icon_hover_color",Color("f4fbef"))
	take.pivot_offset=take.size*.5
	take.focus_mode=Control.FOCUS_ALL;take.grab_focus.call_deferred()
	box.pivot_offset=box.size*.5;box.scale=Vector2.ONE*.94;box.modulate.a=0
	var pop=box.create_tween().set_parallel(true);pop.tween_property(box,"scale",Vector2.ONE,.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT);pop.tween_property(box,"modulate:a",1.0,.18)
## «Позже»: the dialog folds into the corner handset, which keeps ringing.
func postpone():
	if is_instance_valid(dialog):dialog.queue_free()
	dialog=null;button.show();caption.show();postponed.emit()
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
	if is_instance_valid(take) and UiKit.motion_enabled():
		take.rotation=sin(clock*70)*.035 if buzzing else 0.0
		take.scale=Vector2.ONE*(1.0+.03*sin(clock*5))
	if is_instance_valid(photo_frame):
		# The photo's green rim breathes like a video call waiting to connect.
		var style:StyleBoxFlat=photo_frame.get_theme_stylebox("panel");style.border_color=Color("3f9a5a").lerp(Color("8fe895"),.5+.5*sin(clock*4));style.set_border_width_all(3)
func _unhandled_input(event):
	if is_instance_valid(dialog):return
	# Enter only: Space fires in the hub range.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
		get_viewport().set_input_as_handled();answer()
func answer():
	if is_queued_for_deletion():return
	if is_instance_valid(dialog) and dialog.has_node("CallBox"):answered_rect=dialog.get_node("CallBox").get_global_rect()
	answered.emit();queue_free()
