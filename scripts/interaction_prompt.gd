extends Node3D
var context:Node
var caption=""
var radius=1.65
var panel:Panel
var text_label:Label
var amount=0.0
var key_label:Label
var enabled_check:Callable
var action="interact"
## The world sign with the same caption (e.g. «Развитие заставы» over the board): it fades while the prompt
## shows, so the two don't stack (T-166).
var twin:Label3D
var twin_searched=false
## A short reason shown in place of the caption after a refused press (T-213): «Здоровье полное», «Нужно 3 жетона».
## Toasts in the rooms go to the technical log only, so the prompt itself answers the press.
var flash_text:=""
var flash_time:=0.0
const FLASH_COLOR:=Color("ff8a7a")
static func attach(parent:Node3D,world_context:Node,text:String,at:Vector3=Vector3.ZERO,reach:float=1.65,condition:Callable=Callable()):
	var prompt=load("res://scripts/interaction_prompt.gd").new();prompt.context=world_context;prompt.caption=text;prompt.position=at;prompt.radius=reach;prompt.enabled_check=condition;parent.add_child(prompt);return prompt
func _ready():
	add_to_group("world_interaction_prompts")
	var canvas=CanvasLayer.new();canvas.layer=4;add_child(canvas)
	panel=UiKit.panel(canvas,Vector2.ZERO,Vector2(300,44),Color("29372f"))
	# Touch: the prompt itself is the action button — a tap sends the same action as the key.
	panel.mouse_filter=Control.MOUSE_FILTER_STOP;panel.gui_input.connect(tapped)
	var key=UiKit.panel(panel,Vector2(7,6),Vector2(32,32),Color("394b40"))
	key.add_theme_stylebox_override("panel",UiKit.style(Color("394b40"),5,Color("d4ddce")));key.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var letter=UiKit.label(key,"E",Vector2.ZERO,Vector2(32,32),19,Color("f2f1df"));letter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;letter.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;key_label=letter
	text_label=UiKit.label(panel,caption,Vector2(48,5),Vector2(244,34),17,Color("f2f1df"))
	text_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	panel.modulate.a=0
	if "Окоп" in caption:
		panel.size=Vector2(46,44);text_label.hide()
## Shows text over the prompt for a moment, tinted, then the caption returns.
func flash(text:String,seconds:=2.2):
	flash_text=text;flash_time=seconds;amount=maxf(amount,.6)
func window_open()->bool:
	for node in get_tree().get_nodes_in_group("selection_scope"):
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node is CanvasItem and node.is_visible_in_tree():return true
	return false
func tapped(event:InputEvent):
	var tap=(event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if not tap or amount<.5:return
	panel.accept_event()
	var press=InputEventAction.new();press.action=action;press.pressed=true;Input.parse_input_event(press)
	await get_tree().process_frame;await get_tree().process_frame
	var release=InputEventAction.new();release.action=action;release.pressed=false;Input.parse_input_event(release)
func _process(delta):
	if not is_instance_valid(context):return
	var observer:Node3D
	if "avatar" in context:
		observer=context.avatar
	elif "player" in context and is_instance_valid(context.player):observer=context.player
	var active=is_instance_valid(observer) and observer.global_position.distance_to(global_position)<radius
	if "phase" in context:
		active=active and context.phase in ["combat","countdown"]
		if context.phase not in ["combat","countdown"]:amount=0
	if "modal" in context:active=active and not is_instance_valid(context.modal)
	# Any open window (shop, weapon crate, cards, tablet…) hides the world prompts (T-232): a window re-opened
	# after a purchase is not the room's `modal` any more, so the windows group is asked as well.
	if active and window_open():active=false;amount=0
	if enabled_check.is_valid():active=active and enabled_check.call()
	if active:
		for other in get_tree().get_nodes_in_group("world_interaction_prompts"):
			if other==self or other.context!=context or not other.is_visible_in_tree():continue
			if other.enabled_check.is_valid() and not other.enabled_check.call():continue
			var distance=observer.global_position.distance_to(other.global_position)
			if distance<other.radius and (distance<observer.global_position.distance_to(global_position)-.001 or (is_equal_approx(distance,observer.global_position.distance_to(global_position)) and other.get_instance_id()<get_instance_id())):active=false;amount=0;break
	flash_time=maxf(0.0,flash_time-delta)
	if flash_time>0 and not active:flash_time=0.0
	amount=move_toward(amount,1.0 if active else 0.0,delta*7)
	if not twin_searched:
		twin_searched=true
		for node in context.find_children("*","Label3D",true,false):
			if node.text in [caption,Texts.render(caption)] and node.global_position.distance_to(global_position)<3.0:twin=node;break
	if is_instance_valid(twin):twin.modulate.a=1.0-amount;twin.outline_modulate.a=1.0-amount
	var camera=get_viewport().get_camera_3d()
	panel.modulate.a=amount;panel.visible=amount>0 and is_visible_in_tree() and is_instance_valid(camera)
	if panel.visible:
		var compact=is_instance_valid(observer) and "hidden_in_trench" in observer and observer.hidden_in_trench and "Окоп" in caption
		var shown=flash_text if flash_time>0 else caption
		Texts.set_text(text_label,shown)
		text_label.add_theme_color_override("font_color",FLASH_COLOR if flash_time>0 else Color("f2f1df"))
		action="hide_trench" if compact else "interact"
		var glyph=InputScheme.glyph(action);var keyed=glyph!=""
		Texts.set_text(key_label,glyph);key_label.get_parent().visible=keyed
		var inset=48.0 if keyed else 16.0
		var width=clampf(text_label.get_theme_font("font").get_string_size(Texts.render(shown),HORIZONTAL_ALIGNMENT_LEFT,-1,17).x+inset+18,90,420)
		panel.size=Vector2(46 if "Окоп" in caption else width,44)
		text_label.position.x=inset;text_label.size=Vector2(panel.size.x-inset-10,34)
		panel.scale=Vector2.ONE*(.42 if compact else 1.0)
		var anchor=global_position+Vector3.UP*(.05 if compact else 2.05+amount*.2)
		panel.visible=not camera.is_position_behind(anchor)
		panel.position=camera.unproject_position(anchor)-Vector2(panel.size.x*.5,44)*panel.scale+Vector2(0,30 if compact else 0)
