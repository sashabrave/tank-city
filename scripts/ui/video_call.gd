extends Control
## Tutorial video call on the field tablet: Major Kravets from district HQ talks to the unlucky soldier.
## One call per trigger, shown once in the hub (progression.seen keeps "call_<id>"). Info-style, a bit ironic:
## what happens and what to do, no lectures. Adding a call is adding an entry to CALLS and a condition in due().
signal closed
const MAJOR="Майор Мурлыкин"
const SOLDIER="Боец"
const CALLS={
	"intro":[
		[MAJOR,"Рядовой, Рубеж — 13 держишь ты один. Остальных перевели."],
		[SOLDIER,"Везёт как обычно."],
		[MAJOR,"Жми «В бой» и держи штаб. Выбьют — прокачка останется."],
	],
	"first_death":[
		[MAJOR,"Страховка в Штабе сохранит часть сплава. Прокачка не сгорает."],
		[SOLDIER,"Понял: сначала вкладываюсь, потом шлёпаюсь."],
	],
	"garage":[
		[MAJOR,"Стоянка готова. Подбитую технику врага тоже можно занять."],
	],
	"general":[
		[MAJOR,"У генерала щит на 60% и 30%. Разбей генератор на фланге."],
	],
}
var id="intro"
var step=0
var panel:Panel
var portrait:TextureRect
var caller:Label
var status:Label
var line_label:Label
var rec:ColorRect
var next_button:Button
var skip_button:Button
var clock=0.0
var reveal:Tween

## First call whose condition holds and that was not shown yet; "" when none.
static func due(hub)->String:
	var p=Game.progression
	var order=["intro","first_death","garage","general"]
	for call in order:
		if "call_"+call in p.seen:continue
		match call:
			"intro":return call
			"first_death":if int(p.counters.get("deaths",0))>=1:return call
			"garage":if "garage" in Game.built_workshops:return call
			"general":if int(p.counters.get("world_depth_1",0))>=4:return call
	return ""

static func mark_seen(call:String):
	if "call_"+call not in Game.progression.seen:Game.progression.seen.append("call_"+call)
	Game.save_progress()

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
	add_to_group("selection_scope");z_index=95
	var shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.28);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel=UiKit.glass(self,Vector2.ZERO,Vector2.ZERO)
	var frame=Panel.new();frame.name="VideoFrame";panel.add_child(frame);frame.add_theme_stylebox_override("panel",UiKit.style(Color("141b17"),10,Color("3f5a4a")));frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	portrait=TextureRect.new();frame.add_child(portrait);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# Scan lines over the picture: a few thin translucent bars.
	for i in range(14):
		var bar=ColorRect.new();bar.name="Scan";frame.add_child(bar);bar.color=Color(0,0,0,.14);bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	rec=ColorRect.new();frame.add_child(rec);rec.color=Color("e2493b");rec.size=Vector2(10,10);rec.mouse_filter=Control.MOUSE_FILTER_IGNORE
	status=UiKit.label(panel,"Видеосвязь · Главная когтебаза",Vector2.ZERO,Vector2.ZERO,14,UiKit.MUTED)
	caller=UiKit.label(panel,"",Vector2.ZERO,Vector2.ZERO,20)
	line_label=UiKit.label(panel,"",Vector2.ZERO,Vector2.ZERO,20);line_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;line_label.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	skip_button=UiKit.button(panel,"Пропустить",Vector2.ZERO,Vector2.ZERO,finish)
	next_button=UiKit.button(panel,"Дальше",Vector2.ZERO,Vector2.ZERO,advance,true);next_button.focus_mode=Control.FOCUS_ALL
	resized.connect(layout);layout();show_step()
	Game.sound("telegram_accept",self)
	Game.notifications.post("Видеосвязь: "+MAJOR)
	next_button.grab_focus()

func layout():
	const PAD=24.0
	var width=minf(880,size.x-32);var height=minf(270,size.y-32)
	panel.size=Vector2(width,height);panel.position=(size-panel.size)*Vector2(.5,.78)
	var side=clampf(height-PAD*2,96,200)
	var frame=panel.get_node("VideoFrame");frame.position=Vector2(PAD,PAD);frame.size=Vector2(side,side)
	portrait.position=Vector2(8,8);portrait.size=frame.size-Vector2(16,16)
	var scans=frame.get_children().filter(func(n):return n.name.begins_with("Scan"))
	for i in range(scans.size()):scans[i].position=Vector2(0,frame.size.y*(i+.5)/scans.size());scans[i].size=Vector2(frame.size.x,1.5)
	rec.position=Vector2(frame.size.x-20,10)
	var x=PAD+side+PAD;var body=width-x-PAD
	status.position=Vector2(x,PAD-4);status.size=Vector2(body,20)
	caller.position=Vector2(x,PAD+18);caller.size=Vector2(body,28)
	var buttons=48.0
	line_label.position=Vector2(x,PAD+54);line_label.size=Vector2(body,height-PAD*2-54-buttons-10)
	# Main action on the right, the secondary one to its left.
	var button_width=minf(200,(body-12)*.5)
	next_button.size=Vector2(button_width,buttons);next_button.position=Vector2(width-PAD-button_width,height-PAD-buttons)
	skip_button.size=Vector2(button_width,buttons);skip_button.position=Vector2(next_button.position.x-12-button_width,next_button.position.y)
	line_label.add_theme_font_size_override("font_size",20 if width>=700 else 17)

func show_step():
	var lines:Array=CALLS.get(id,[])
	if step>=lines.size():finish();return
	var who:String=lines[step][0]
	Texts.set_text(caller,who)
	caller.add_theme_color_override("font_color",UiKit.ORANGE if who==MAJOR else UiKit.INK)
	portrait.texture=preload("res://scripts/ui/class_gallery.gd").texture("heavy" if who==MAJOR else Game.selected_class)
	portrait.modulate=Color("c9e0d2") if who==MAJOR else Color.WHITE
	Texts.set_text(line_label,lines[step][1])
	Texts.set_text(next_button,"Конец связи" if step==lines.size()-1 else "Дальше")
	line_label.visible_ratio=0.0
	if reveal:reveal.kill()
	reveal=create_tween();reveal.tween_property(line_label,"visible_ratio",1.0,clampf(line_label.text.length()*.018,.25,1.2))

func advance():
	if line_label.visible_ratio<1.0:
		if reveal:reveal.kill()
		line_label.visible_ratio=1.0;return
	step+=1;show_step()

func finish():
	if is_queued_for_deletion():return
	mark_seen(id);closed.emit();queue_free()

func _process(delta):
	clock+=delta
	if is_instance_valid(rec):rec.visible=fposmod(clock,1.0)<.6
	if is_instance_valid(portrait):portrait.position.y=8+sin(clock*1.3)*1.2

func _unhandled_input(event):
	if event.is_action_pressed("pause"):finish();get_viewport().set_input_as_handled()
