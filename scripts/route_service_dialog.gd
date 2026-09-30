extends RefCounted
static func build(route,branch:String,confirm:Callable=Callable())->Control:
	if not confirm.is_valid():confirm=route.confirm_service
	var modal=Control.new();route.root.add_child(modal);modal.add_to_group("selection_scope");modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade=ColorRect.new();modal.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.48)
	var panel=UiKit.glass(modal,(route.get_viewport().get_visible_rect().size-Vector2(640,330))*.5,Vector2(640,330))
	UiKit.label(panel,{"vehicle":"Ангар / механик","ability":"Пункт подготовки","headquarters":"Мастерская штаба","merchant":"Торговец"}[branch],Vector2(25,20),Vector2(590,40),27)
	var text="Жетоны с врагов меняются на карты, лечение, перебросы и чертежи.\nЕсть игровой автомат." if branch=="merchant" else "Выбор одного усиления транспорта.\nМеханик подготовит машину к следующему бою." if branch=="vehicle" else "Выбор модуля или усиления штаба.\nДействует до конца вылазки." if branch=="headquarters" else "Выбор одного усиления способности.\nСила, перезарядка или дополнительный эффект."
	UiKit.label(panel,text,Vector2(25,85),Vector2(590,85),19)
	UiKit.label(panel,"Аптечки: %d · без боя · одна точка на выбор" % Game.camp_level,Vector2(25,183),Vector2(590,32),16,UiKit.MUTED)
	UiKit.button(panel,"Войти [E]",Vector2(330,247),Vector2(285,52),confirm,true)
	UiKit.button(panel,"Отказаться",Vector2(25,247),Vector2(285,52),route.cancel_entry)
	return modal
