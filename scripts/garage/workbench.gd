extends Control
signal closed
signal changed
var selected_kind="buggy"
func _ready():add_to_group("selection_scope");set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);refresh()
func refresh():
	for child in get_children():remove_child(child);child.queue_free()
	var shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.5)
	var panel=UiKit.panel(self,(get_viewport_rect().size-Vector2(960,670))*.5,Vector2(960,670))
	UiKit.label(panel,"Стоянка",Vector2(25,15),Vector2(630,40),28)
	UiKit.button(panel,"×",Vector2(882,12),Vector2(52,44),func():closed.emit())
	var foot=UiKit.button(panel,"Пешком"+(" · выбрано" if Game.garage.selected=="" else ""),Vector2(650,65),Vector2(282,38),func():Game.garage.choose("");changed.emit();refresh());foot.add_theme_font_size_override("font_size",17)
	UiKit.label(panel,"Машина остаётся на базе. Каждая вылазка — с полной бронёй.",Vector2(25,64),Vector2(620,40),16,UiKit.MUTED)
	var kinds=GarageCatalog.VEHICLES.keys()
	for i in range(3):
		var kind=kinds[i]
		var tab=UiKit.button(panel,("● " if selected_kind==kind else "")+GarageCatalog.VEHICLES[kind].name,Vector2(25,120+i*66),Vector2(205,54),func():selected_kind=kind;refresh());tab.add_theme_font_size_override("font_size",19)
		if kind!=selected_kind:continue
		var v=GarageCatalog.VEHICLES[kind];var known="vehicle_"+kind in Game.garage.unlocks;var owned=kind in Game.garage.owned
		var card=UiKit.panel(panel,Vector2(250,120),Vector2(684,515),Color("dce3d5") if owned else Color("d7dcd2"))
		if known or owned:preload("res://scripts/ui/build_catalog.gd").item_dot(card,"garage","vehicle_"+kind,Vector2(650,12))
		var preview=preload("res://scripts/garage/model_preview.gd").new();preview.kind=kind;preview.position=Vector2(46,275);preview.size=Vector2(204,170);card.add_child(preview)
		UiKit.label(card,("" if known or owned else "🔒 ")+v.name,Vector2(14,16),Vector2(182,35),23)
		UiKit.label(card,"%d ◈" % v.price,Vector2(14,54),Vector2(268,24),13,UiKit.MUTED)
		if known or owned:
			var stats=GarageCatalog.stats(kind)
			var base=Balance.CONFIG.enemy(kind)
			UiKit.stat_bars(card,Vector2(14,92),266,[["Броня",stats.hp,base.health*1.15],["Урон",stats.damage,(base.damage+Game.meta_damage()*(.25 if kind=="buggy" else 1.0))*1.15],["Темп",1/stats.interval,1/base.fire_interval*1.1," /с"]],29)
		else:UiKit.label(card,"🔒 Найди чертёж в вылазке",Vector2(14,106),Vector2(266,60),16,UiKit.MUTED)
		var caption="Выбрано" if Game.garage.selected==kind else "Выбрать" if owned else "🔒 Чертёж" if not known else "🔒 Сначала "+GarageCatalog.VEHICLES[v.previous].name if v.previous!="" and v.previous not in Game.garage.owned else "Купить · %d ◈" % v.price
		var purchase=UiKit.button(card,caption,Vector2(14,193),Vector2(266,42),func():
			if owned:Game.garage.choose(kind)
			else:Game.garage.buy(kind)
			changed.emit();refresh())
		purchase.add_theme_font_size_override("font_size",16);purchase.disabled=Game.garage.selected==kind or (not owned and not Game.garage.can_buy(kind));UiKit.muted_locked_button(purchase)
		UiKit.label(card,"Оборудование",Vector2(340,18),Vector2(320,24),13,UiKit.MUTED)
		var branches=GarageCatalog.BRANCHES.keys()
		for j in range(3):
			var branch=branches[j];var info=GarageCatalog.BRANCHES[branch];var unlocked=kind+"_"+branch in Game.garage.unlocks;var n=Game.garage.level(kind,branch);var y=65+j*130
			if unlocked:preload("res://scripts/ui/build_catalog.gd").item_dot(card,"garage",kind+"_"+branch,Vector2(658,y))
			UiKit.label(card,("" if unlocked else "🔒 ")+info.name+(" · %d/%d" % [n,Game.garage.cap(kind)] if unlocked else ""),Vector2(340,y),Vector2(320,24),14)
			var buy=UiKit.button(card,"🔒 Чертёж" if not unlocked else "🔒 Купи транспорт" if not owned else "Максимум" if n>=Game.garage.cap(kind) else "+%d%% · %d ◈" % [roundi(info.step*100),Game.garage.cost(kind,branch)],Vector2(340,y+38),Vector2(320,42),func():Game.garage.upgrade(kind,branch);changed.emit();refresh())
			buy.add_theme_font_size_override("font_size",13);var style=buy.get_theme_stylebox("normal").duplicate();style.content_margin_top=3;style.content_margin_bottom=3;buy.add_theme_stylebox_override("normal",style)
			buy.disabled=not unlocked or not owned or n>=Game.garage.cap(kind) or Game.credits<Game.garage.cost(kind,branch);UiKit.muted_locked_button(buy)
