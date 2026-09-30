extends Control
signal closed
var slot=0
var category="all"
func _ready():add_to_group("selection_scope");set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);refresh()
func refresh():
	for child in get_children():remove_child(child);child.queue_free()
	var shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.5)
	var panel=UiKit.panel(self,(get_viewport_rect().size-Vector2(1180,686))*.5,Vector2(1180,686),Color("d9e1d4"))
	UiKit.label(panel,"Технологии штаба",Vector2(24,15),Vector2(800,40),UiKit.PAGE_TITLE_SIZE)
	UiKit.button(panel,"×",Vector2(1103,12),Vector2(52,44),func():closed.emit())
	UiKit.label(panel,"Один модуль поддержки · ручная активация: 2",Vector2(244,57),Vector2(910,28),15,UiKit.MUTED)
	for i in range(Game.hq_slots):
		var equipped=Game.hq_loadout();var id=equipped[i] if i<equipped.size() else ""
		var button=UiKit.button(panel,("● " if slot==i else "")+"Слот %d: " % (i+1)+(HQCatalog.DATA[id].name if id!="" else "пусто"),Vector2(244+i*308,80),Vector2(299,38),func():slot=i;refresh());button.add_theme_font_size_override("font_size",14)
	preload("res://scripts/ui/build_catalog.gd").preview(panel,"headquarters",Vector2(24,88),Vector2(194,112))
	var categories=[["all","Все технологии"],["passive","Пассивные"],["auto","Автоматические"],["active","Активные · 2"]]
	for i in range(categories.size()):
		var key=categories[i][0];var b=UiKit.button(panel,("● " if category==key else "")+categories[i][1],Vector2(20,214+i*64),Vector2(204,52),func():category=key;refresh());b.add_theme_font_size_override("font_size",16)
	var ids=HQCatalog.DATA.keys().filter(func(id):return category=="all" or HQCatalog.DATA[id].mode==category)
	for i in range(ids.size()):
		var id=ids[i];var data=HQCatalog.DATA[id];var known=id in Game.hq_unlocks;var usable=HQCatalog.available(id);var level=int(Game.hq_levels.get(id,0))
		var card=UiKit.panel(panel,Vector2(244+(i%3)*308,146+int(i/3.0)*171),Vector2(298,161))
		if known:preload("res://scripts/ui/build_catalog.gd").item_dot(card,"headquarters",id,Vector2(273,9))
		UiKit.label(card,("" if known else "🔒 ")+data.name,Vector2(12,7),Vector2(270,25),17)
		UiKit.label(card,("2 · Активный" if data.mode=="active" else "Автоматический" if data.mode=="auto" else "Пассивный"),Vector2(12,33),Vector2(278,20),11,UiKit.MUTED)
		if known:
			var desc=UiKit.label(card,data.description,Vector2(12,57),Vector2(274,40),12);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			UiKit.label(card,HQCatalog.stat(id,level),Vector2(12,98),Vector2(274,23),12)
		else:UiKit.label(card,"🔒 Добудь и донеси чертёж",Vector2(12,66),Vector2(274,35),15,UiKit.MUTED)
		var equipped=id in Game.hq_modules or id==Game.hq_active
		var equip=UiKit.button(card,"Выбрано" if equipped else ("Взять" if id in Game.purchased_hq else "%d ◈" % Game.hq_purchase_cost(id)) if usable else "🔒 Чертёж",Vector2(10,126),Vector2(121,27),func():Game.equip_hq(id,slot);refresh());equip.disabled=equipped or not usable
		var buy=UiKit.button(card,"Макс." if level>=HQCatalog.cap() else "+1 · %d ◈" % HQCatalog.permanent_cost(id),Vector2(141,126),Vector2(147,27),func():Game.upgrade_hq(id);refresh());buy.disabled=not usable or level>=HQCatalog.cap() or Game.credits<HQCatalog.permanent_cost(id);buy.visible=known
		for b in [equip,buy]:
			b.add_theme_font_size_override("font_size",12)
			for state in ["normal","hover","pressed","disabled"]:
				var style=b.get_theme_stylebox(state).duplicate();style.content_margin_top=3;style.content_margin_bottom=3;style.content_margin_left=5;style.content_margin_right=5;b.add_theme_stylebox_override(state,style)
			b.size.y=27
			UiKit.muted_locked_button(b)
		buy.tooltip_text=HQCatalog.stat(id,level)+" → "+HQCatalog.stat(id,level+1)
