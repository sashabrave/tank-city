extends Control
signal closed
signal accepted
var startup=false
var panel:Panel
var status:Label
var cards:Array=[]
var confirm:Control
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_to_group("selection_scope")
	var shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color=Color("17201c") if startup else Color(0,0,0,.65)
	shade.set_meta("keep_theme_colors",true)
	panel=UiKit.glass(self,Vector2.ZERO,Vector2.ZERO)
	UiKit.label(panel,"Выбери мир",Vector2(28,22),Vector2(900,48),34)
	var subtitle=UiKit.label(panel,"Три независимых сохранения. Создай свой первый мир." if startup and not any_profiles() else "У каждого мира своя база, боец и прогресс.",Vector2(28,78),Vector2(900,46),18,UiKit.MUTED);subtitle.name="Subtitle";subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for slot in range(1,Game.profiles.COUNT+1):build_card(slot)
	status=UiKit.label(panel,Game.save_error,Vector2.ZERO,Vector2.ZERO,16,Color("f49d85"));status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if not startup:
		var back=UiKit.button(panel,"Назад [Esc]",Vector2.ZERO,Vector2(180,42),func():closed.emit());back.name="Back"
	resized.connect(layout);layout()
func any_profiles()->bool:
	for slot in range(1,Game.profiles.COUNT+1):
		if Game.profiles.exists(slot):return true
	return false
func build_card(slot:int):
	var info=Game.profiles.summary(slot)
	var card=UiKit.panel(panel,Vector2.ZERO,Vector2.ZERO,Color("303833"));cards.append(card)
	var current=Game.profiles.selected and slot==Game.profiles.active
	UiKit.label(card,"Мир %d" % slot,Vector2(18,14),Vector2(270,32),24).name="Title"
	UiKit.label(card,"Текущий" if current else "Новый мир" if info.empty else "Сохранение",Vector2(18,49),Vector2(270,25),15,UiKit.MUTED).name="State"
	var art=TextureRect.new();card.add_child(art);art.name="Art";art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	art.texture=preload("res://assets/ui/illustrations/route.tres") if info.empty else preload("res://scripts/ui/class_gallery.gd").texture(info.get("class","recruit"))
	art.modulate.a=.5 if info.empty else 1.0
	var summary="Чистый старт · новая база" if info.empty else info.error if info.has("error") else "%d сплава" % info.credits
	var caption=UiKit.label(card,summary,Vector2.ZERO,Vector2.ZERO,17,UiKit.MUTED);caption.name="Summary";caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var choose=UiKit.button(card,"Создать мир" if info.empty else "Продолжить",Vector2.ZERO,Vector2.ZERO,func():choose_slot(slot,info.empty),true);choose.name="Choose";choose.focus_mode=Control.FOCUS_ALL
	choose.disabled=current and not Game.save_blocked
	var erase=UiKit.button(card,"Удалить",Vector2.ZERO,Vector2.ZERO,func():confirm_delete(slot));erase.name="Delete";erase.disabled=info.empty;erase.visible=not info.empty
func layout():
	var width=minf(1120,size.x-32);var height=minf(610,size.y-32)
	panel.size=Vector2(width,height);panel.position=(size-panel.size)*.5
	panel.get_node("Subtitle").size.x=width-56
	var card_width=(width-80)/3;var card_height=height-210
	for i in range(cards.size()):
		var card=cards[i];card.position=Vector2(24+i*(card_width+16),136);card.size=Vector2(card_width,card_height)
		for key in ["Title","State"]:card.get_node(key).size.x=card_width-36
		var art=card.get_node("Art");art.position=Vector2(18,82);art.size=Vector2(card_width-36,maxf(64,card_height-246))
		var caption=card.get_node("Summary");caption.position=Vector2(18,card_height-172);caption.size=Vector2(card_width-36,42)
		for key in ["Choose","Delete"]:
			var button=card.get_node(key);button.position=Vector2(16,card_height-(116 if key=="Choose" else 55));button.size=Vector2(card_width-32,44 if key=="Choose" else 32);button.add_theme_font_size_override("font_size",18 if key=="Choose" else 14)
	status.position=Vector2(24,height-64);status.size=Vector2(width-245,46)
	if panel.has_node("Back"):panel.get_node("Back").position=Vector2(width-204,height-60)
func choose_slot(slot:int,create:bool):
	if Game.profiles.choose(slot,create):accepted.emit()
	else:Texts.set_text(status,Game.profiles.error)
func confirm_delete(slot:int):
	if is_instance_valid(confirm):return
	confirm=Control.new();add_child(confirm);confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade=ColorRect.new();confirm.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.7)
	var width=minf(620,size.x-40);var box=UiKit.panel(confirm,(size-Vector2(width,260))*.5,Vector2(width,260))
	UiKit.label(box,"Удалить мир %d?" % slot,Vector2(24,22),Vector2(width-48,40),28)
	var body=UiKit.label(box,"База и прогресс этого мира будут удалены. Остальные миры сохранятся.",Vector2(24,78),Vector2(width-48,80),20);body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	UiKit.button(box,"Отмена",Vector2(width*.5+6,184),Vector2((width-60)*.5,50),cancel_delete,true)
	UiKit.button(box,"Удалить",Vector2(24,184),Vector2((width-60)*.5,50),func():
		if Game.profiles.remove(slot):
			cancel_delete()
			# Active deletion opens a fresh startup picker via the main scene.
			if Game.profiles.selected:
				for card in cards:card.queue_free()
				cards.clear()
				for index in range(1,4):build_card(index)
				layout()
		else:Texts.set_text(status,Game.profiles.error);cancel_delete())
func cancel_delete():
	if is_instance_valid(confirm):confirm.queue_free();confirm=null
func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		if is_instance_valid(confirm):cancel_delete()
		elif not startup:closed.emit()
		get_viewport().set_input_as_handled()
