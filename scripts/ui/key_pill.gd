extends Panel
## Small key hint: shows the key (or gamepad button) for an action; on touch it is the button itself.
## Used where a full interaction prompt would cover the field (trench).
var action="interact"
var label:Label
func _ready():
	custom_minimum_size=Vector2(30,30);size=Vector2(30,30)
	var s=UiKit.style(Color("29372f"),8,Color("d4ddce"));s.set_border_width_all(2);add_theme_stylebox_override("panel",s)
	label=UiKit.label(self,"",Vector2.ZERO,size,16,Color("f2f1df"));label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	mouse_filter=Control.MOUSE_FILTER_STOP;gui_input.connect(tapped)
func refresh():
	var glyph=InputScheme.glyph(action)
	Texts.set_text(label,glyph if glyph!="" else ("▼" if action=="hide_trench" else "⤴"))
	size.x=maxf(30,label.get_minimum_size().x+14);label.size=size
func tapped(event:InputEvent):
	var tap=(event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if not tap or not visible:return
	accept_event()
	var press=InputEventAction.new();press.action=action;press.pressed=true;Input.parse_input_event(press)
	await get_tree().process_frame;await get_tree().process_frame
	var release=InputEventAction.new();release.action=action;release.pressed=false;Input.parse_input_event(release)
