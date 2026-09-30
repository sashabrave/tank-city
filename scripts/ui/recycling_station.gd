extends RefCounted
static func build(hub)->Control:
	var root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_to_group("selection_scope")
	var dim=ColorRect.new();root.add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,0,0,.5)
	var panel=UiKit.panel(root,(hub.get_viewport().get_visible_rect().size-Vector2(650,460))*.5,Vector2(650,460))
	UiKit.label(panel,"Утилизация чертежей",Vector2(22,15),Vector2(610,38),24)
	UiKit.label(panel,"Только доставленные повторы. Открытые технологии сохранятся.",Vector2(22,59),Vector2(610,45),16).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var scroll=ScrollContainer.new();panel.add_child(scroll);scroll.position=Vector2(22,113);scroll.size=Vector2(606,238)
	var box=VBoxContainer.new();scroll.add_child(box);box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",7)
	if Game.duplicate_recipes.is_empty():
		var empty=Label.new();box.add_child(empty);Texts.set_text(empty,"Повторных чертежей пока нет.\nЕсли новые чертежи этого типа закончились,\nв сундуке может встретиться повтор для продажи.");empty.add_theme_color_override("font_color",UiKit.INK)
	var total=0
	for i in range(Game.duplicate_recipes.size()):
		var recipe=Game.duplicate_recipes[i];var price=Game.duplicate_price(recipe);total+=price
		var button=Button.new();box.add_child(button);Texts.set_text(button,Game.recipe_name(recipe)+" · продать за %d ◈" % price);button.custom_minimum_size.y=44;button.add_theme_stylebox_override("normal",UiKit.style(Color("dbe3d1"),7));button.add_theme_color_override("font_color",UiKit.INK)
		button.pressed.connect(func():
			if Game.sell_duplicate(i):hub.show_recycling()
			else:Texts.set_text(button,"Не удалось сохранить продажу"))
	var sell=UiKit.button(panel,"Продать всё · %d ◈" % total,Vector2(22,368),Vector2(350,48),func():
		if Game.sell_all_duplicates()>0:hub.show_recycling())
	sell.disabled=total==0
	UiKit.button(panel,"Закрыть [Esc]",Vector2(386,368),Vector2(242,48),hub.close_station)
	return root
static func model(hub,pos:Vector3):
	var bin=Node3D.new();hub.add_child(bin);bin.name="BlueprintRecycling";bin.position=pos
	Visuals.box(bin,Vector3(0,.025,0),Vector3(1.15,.05,1.15),Color("d8b368"))
	Visuals.box(bin,Vector3(0,.35,0),Vector3(.68,.65,.68),Color("5a6b5e"))
	Visuals.box(bin,Vector3(0,.70,0),Vector3(.8,.1,.8),Color("a7b3a0"))
	Visuals.box(bin,Vector3(0,.755,0),Vector3(.48,.02,.18),Color("283a30"))
	preload("res://scripts/interaction_prompt.gd").attach(hub,hub,"Продать повторы",pos,1.3,func():return not hub.mounted)
