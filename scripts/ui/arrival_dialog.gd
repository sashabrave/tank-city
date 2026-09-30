extends Control
signal closed
const WAKE=["Я проснулся и готов!","Снова на ногах. Я готов!","Новый день — новый шанс!","Выспался. Можно начинать!","Я в строю! Что у нас сегодня?"]
const RETURN=["Наконец-то я вернулся!","Дома! Как же здесь хорошо.","Вернулся целым. Уже неплохо!","Вот и база. Можно выдохнуть!","Я вернулся! Есть что рассказать."]
static var last_lines:Dictionary={}
var reason="wake"
var panel:Panel
var portrait:TextureRect
var speaker:Label
var words:HFlowContainer
var answers:Array=[]
var animation:Tween
var dismissed=false
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
	add_to_group("selection_scope");z_index=90
	var shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.48)
	panel=UiKit.panel(self,Vector2.ZERO,Vector2.ZERO)
	portrait=TextureRect.new();panel.add_child(portrait);portrait.texture=preload("res://scripts/ui/class_gallery.gd").texture(Game.selected_class);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	speaker=UiKit.label(panel,"Боец",Vector2.ZERO,Vector2.ZERO,20,UiKit.MUTED)
	words=HFlowContainer.new();panel.add_child(words);words.add_theme_constant_override("h_separation",9);words.add_theme_constant_override("v_separation",8);words.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var lines=RETURN if reason=="return" else WAKE
	var available=lines.filter(func(line):return line!=last_lines.get(reason,""))
	var line=available.pick_random();last_lines[reason]=line
	# Translate the whole sentence before splitting so words retain their natural case.
	var spoken=Texts.render(line)
	for word in spoken.split(" ",false):
		var slot=Control.new();words.add_child(slot)
		var label=Label.new();slot.add_child(label);label.set_meta("text_editor",true);label.text=word;label.add_theme_font_override("font",UiKit.field_font());label.add_theme_color_override("font_color",UiKit.INK)
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for caption in (["Супер","Молодец!"] if reason=="return" else ["Да","Конечно"]):
		var button=UiKit.button(panel,caption,Vector2.ZERO,Vector2.ZERO,dismiss,answers.is_empty());button.focus_mode=Control.FOCUS_ALL;answers.append(button)
	resized.connect(layout);layout()
	animation=create_tween().set_parallel(true)
	for i in range(words.get_child_count()):
		var label=words.get_child(i).get_child(0);label.modulate.a=0;label.position.y=7
		animation.tween_property(label,"modulate:a",1.0,.12).set_delay(i*.045)
		animation.tween_property(label,"position:y",0.0,.12).set_delay(i*.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	answers[0].grab_focus()
func layout():
	var width=minf(1040,size.x-32);var height=minf(370,size.y-32)
	panel.size=Vector2(width,height);panel.position=(size-panel.size)*Vector2(.5,.72)
	var left=clampf(width*.27,100,280);var inset=20.0;var body_x=left+32;var body_width=width-body_x-inset
	portrait.position=Vector2(12,16);portrait.size=Vector2(left,height-32)
	speaker.position=Vector2(body_x,22);speaker.size=Vector2(body_width,28)
	words.position=Vector2(body_x,68);words.size=Vector2(body_width,height-164)
	var font_size=32 if width>=750 else 23
	for slot in words.get_children():
		var label=slot.get_child(0);label.add_theme_font_size_override("font_size",font_size);slot.custom_minimum_size=label.get_minimum_size();label.size=slot.custom_minimum_size
	for i in range(answers.size()):
		answers[i].position=Vector2(body_x+i*(body_width+12)*.5,height-76);answers[i].size=Vector2((body_width-12)*.5,54)
func _unhandled_key_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_ESCAPE,KEY_1,KEY_2]:
		get_viewport().set_input_as_handled();dismiss()
func dismiss():
	if dismissed:return
	dismissed=true
	if animation:animation.kill()
	Game.reset_input();closed.emit();queue_free()
