extends Control
signal selected(world:int,infinite:bool)
signal cancelled
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_to_group("selection_scope")
	var dim=ColorRect.new();add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,0,0,.6)
	var panel=UiKit.glass(self,(get_viewport_rect().size-Vector2(1060,630))*.5,Vector2(1060,630))
	UiKit.label(panel,"Операции / в бой",Vector2(26,20),Vector2(850,45),30)
	UiKit.button(panel,"×",Vector2(977,17),Vector2(56,46),func():cancelled.emit())
	UiKit.button(panel,"unlock-dev",Vector2(770,22),Vector2(170,38),unlock_worlds).add_theme_font_size_override("font_size",14)
	for i in range(4):
		var unlocked=Campaign.unlocked(i+1) if i<3 else Campaign.infinite_unlocked()
		var card=UiKit.panel(panel,Vector2(26+i*254,88),Vector2(244,508),Color(["d8e1cf","ccd9d5","d7cdc3","c9d1cf"][i]))
		UiKit.label(card,"Мир %d" % (i+1) if i<3 else "Бесконечный",Vector2(15,16),Vector2(214,35),22)
		UiKit.label(card,Campaign.WORLDS[i+1].name if i<3 else "Рубеж",Vector2(15,55),Vector2(214,40),22)
		var badge=UiKit.panel(card,Vector2(16,108),Vector2(212,112),Color("627866") if unlocked else Color("92988e"))
		UiKit.label(badge,"0%d" % (i+1) if i<3 else "∞",Vector2(15,15),Vector2(180,85),58,Color("ecedda"))
		var detail=["6 полей + босс\nГенерал пограничья\nБагги · ПП · дробовик · винтовка","6 полей + босс\nГенерал фронта\nБТР · снайперка","6 полей + генерал\nПередышка → гигабосс\nТанк · РПГ","Секторы без конца\nСтарт под подготовку\nКаждый сектор сильнее"][i]
		UiKit.label(card,detail,Vector2(15,240),Vector2(214,120),17).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		UiKit.label(card,"Открыто" if unlocked else "🔒 Пройдите %d-й мир" % (i if i<3 else 1),Vector2(15,374),Vector2(214,45),16,UiKit.MUTED)
		var button=UiKit.button(card,"В бой" if unlocked else "🔒 Закрыто",Vector2(15,440),Vector2(214,48),func():selected.emit(i+1 if i<3 else 1,i==3),unlocked and i==0)
		button.disabled=not unlocked;UiKit.muted_locked_button(button)

func _unhandled_input(event):
	if event.is_action_pressed("pause"):get_viewport().set_input_as_handled();cancelled.emit()

func unlock_worlds():
	Game.progression.cleared_worlds=[1,2,3];Game.save_progress()
	for child in get_children():
		remove_child(child);child.queue_free()
	_ready()
