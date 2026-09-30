extends Control
signal closed
## Hub greeting: short first-person tips about the game from the ironic, resourceful soldier.
const TIPS=["Бочку я не обхожу. Я подвожу к ней врагов. Бум — и спор окончен.","Жетоны с врагов живут до конца вылазки. Копить их незачем — несу торговцу.","Штаб за спиной — не мебель. Упадёт штаб — упаду и я. Так что прикрываю.","Тайник всегда с сюрпризом: откроешь — набегут. Открываю, но сперва встаю поудобнее.","Одна карта — прибавка. Три похожих — уже схема, от которой враги плачут.","Не нравятся карты — есть переброс. Я не гордый, перетасую.","Чертежи лежат в сундуках командиров. Донёс до базы — построил станцию. Не донёс — ну, бывает.","В «Штабе» есть страховка сплава. Я человек осторожный: страхую и сплав, и нервы.","Пешком далеко не уйдёшь. Вижу машину — сажусь. Это смекалка, а не лень.","Пройденная комната — отметка на карте. Выйду из игры — продолжу с неё же. Удобно, как старые валенки.","Дорога на карте ветвится. Ищу торговца и испытания — прямо ходят только поезда.","В напёрстках штаб прячут под колпаком. Слежу, не моргаю. Глаз-алмаз.","Задания выдают в командном центре, там же платят сплавом и документами. Бесплатно только советы, как этот.","«Боец» открыт сразу: оболочки, здоровье, аптечки. С него и начинаю — классика.","У торговца стоит автомат удачи. Знаю, что глупо. Знаю. Дёргаю.","Сплав — на станции, документы — на редкие открытия. Считать умею, хоть и делаю вид, что нет.","Проиграл — не беда: прокачка на базе остаётся. Возвращаюсь сильнее и чуть злее.","Бесконечный режим не кончается. Как и мои идеи, как всё это сломать.","Хочу проверить сборку без риска — иду в песочницу. Там я бессмертный и очень смелый.","Турели в «Штабе» стреляют, пока я думаю. Люблю, когда за меня работают."]
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
	var shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.22)
	panel=UiKit.glass(self,Vector2.ZERO,Vector2.ZERO)
	portrait=TextureRect.new();panel.add_child(portrait);portrait.texture=preload("res://scripts/ui/class_gallery.gd").texture(Game.selected_class);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	speaker=UiKit.label(panel,"Боец",Vector2.ZERO,Vector2.ZERO,20,UiKit.MUTED)
	words=HFlowContainer.new();panel.add_child(words);words.add_theme_constant_override("h_separation",9);words.add_theme_constant_override("v_separation",8);words.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var available=TIPS.filter(func(line):return line!=last_lines.get("tip",""))
	var line=available.pick_random();last_lines["tip"]=line
	# Translate the whole sentence before splitting so words retain their natural case.
	var spoken=Texts.render(line)
	for word in spoken.split(" ",false):
		var slot=Control.new();words.add_child(slot)
		var label=Label.new();slot.add_child(label);label.set_meta("text_editor",true);label.text=word;label.add_theme_font_override("font",UiKit.field_font());label.add_theme_color_override("font_color",UiKit.INK)
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for caption in ["Учту","Понял"]:
		var button=UiKit.button(panel,caption,Vector2.ZERO,Vector2.ZERO,dismiss,caption=="Понял");button.focus_mode=Control.FOCUS_ALL;answers.append(button)
	resized.connect(layout);layout()
	animation=create_tween().set_parallel(true)
	for i in range(words.get_child_count()):
		var label=words.get_child(i).get_child(0);label.modulate.a=0;label.position.y=7
		animation.tween_property(label,"modulate:a",1.0,.12).set_delay(i*.045)
		animation.tween_property(label,"position:y",0.0,.12).set_delay(i*.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	answers[-1].grab_focus()
func layout():
	const PAD=24.0
	var width=minf(1000,size.x-32);var height=minf(300,size.y-32)
	panel.size=Vector2(width,height);panel.position=(size-panel.size)*Vector2(.5,.72)
	var side=clampf(minf(width*.26,height-PAD*2),96,height-PAD*2)
	portrait.position=Vector2(PAD,PAD);portrait.size=Vector2(side,side)
	var body_x=PAD+side+PAD;var body_width=width-body_x-PAD
	speaker.position=Vector2(body_x,PAD-2);speaker.size=Vector2(body_width,26)
	var button_height=50.0
	words.position=Vector2(body_x,PAD+36);words.size=Vector2(body_width,height-PAD*2-36-button_height-14)
	var font_size=26 if width>=750 else 20
	for slot in words.get_children():
		var label=slot.get_child(0);label.add_theme_font_size_override("font_size",font_size);slot.custom_minimum_size=label.get_minimum_size();label.size=slot.custom_minimum_size
	for i in range(answers.size()):
		answers[i].position=Vector2(body_x+i*(body_width+12)*.5,height-PAD-button_height);answers[i].size=Vector2((body_width-12)*.5,button_height)
func _unhandled_key_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_ESCAPE,KEY_1,KEY_2]:
		get_viewport().set_input_as_handled();dismiss()
func dismiss():
	if dismissed:return
	dismissed=true
	if animation:animation.kill()
	Game.reset_input();closed.emit();queue_free()
