extends CanvasLayer
## Hints on touch screens, where there is no hover: a tap on an info element (icon, chip, label with a
## tooltip) or a long press on any control shows its tooltip in a small bubble for a moment.
## With a mouse the regular hover tooltip is used; this node stays idle.
const HOLD=.45
const SHOW=2.6
var bubble:PanelContainer
var text:Label
var press_at=-1.0
var press_pos=Vector2.ZERO
var left=0.0

func _ready():
	layer=120;process_mode=Node.PROCESS_MODE_ALWAYS
	bubble=PanelContainer.new();add_child(bubble);bubble.visible=false;bubble.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var box=UiKit.style(Color("1d2520f0"),8,Color(1,1,1,.18));box.content_margin_left=10;box.content_margin_right=10;box.content_margin_top=6;box.content_margin_bottom=6
	bubble.add_theme_stylebox_override("panel",box)
	text=Label.new();bubble.add_child(text);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.custom_minimum_size=Vector2(220,0)
	text.add_theme_font_size_override("font_size",15);text.add_theme_color_override("font_color",UiKit.INK);text.set_meta("text_editor",true)

func _input(event):
	if not InputScheme.touch():return
	if event is InputEventScreenTouch:
		if event.pressed:press_at=Time.get_ticks_msec()/1000.0;press_pos=event.position
		else:
			var held=Time.get_ticks_msec()/1000.0-press_at
			press_at=-1.0
			if event.position.distance_to(press_pos)>18:return
			var control=hint_owner(event.position,held>=HOLD)
			if control:show_hint(control,event.position)
	elif event is InputEventScreenDrag and event.position.distance_to(press_pos)>18:press_at=-1.0

## The control under the finger that carries a tooltip. Buttons answer only to a long press, so a tap
## still presses them; info elements (labels, icons, chips) answer to a tap.
func hint_owner(pos:Vector2,long_press:bool)->Control:
	# Screen-space test through each control's canvas transform (layers may be offset or scaled).
	# Among hits the one drawn on top wins: higher canvas layer, then later in tree order.
	var best:Control=null;var best_layer=-INF
	for node in get_tree().root.find_children("*","Control",true,false):
		var control:Control=node
		if control.tooltip_text.strip_edges()=="" or not control.is_visible_in_tree():continue
		if control is BaseButton and not long_press:continue
		var rect=control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)
		if not rect.has_point(pos):continue
		var layer=float(control.get_canvas_layer_node().layer) if control.get_canvas_layer_node() else 0.0
		if layer>=best_layer:best=control;best_layer=layer
	return best

func show_hint(control:Control,pos:Vector2):
	Texts.set_text(text,Texts.localized(control.tooltip_text))
	bubble.reset_size();bubble.visible=true;bubble.modulate.a=0.0
	var size=get_viewport().get_visible_rect().size
	bubble.position=(pos+Vector2(-bubble.size.x*.5,-bubble.size.y-24)).clamp(Vector2(8,8),size-bubble.size-Vector2(8,8))
	create_tween().tween_property(bubble,"modulate:a",1.0,.12)
	left=SHOW

func _process(delta):
	if left>0:
		left-=delta
		if left<=0:
			var tween=create_tween();tween.tween_property(bubble,"modulate:a",0.0,.18);tween.tween_callback(func():bubble.visible=false)
