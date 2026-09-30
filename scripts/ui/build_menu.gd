extends RefCounted
const Catalog=preload("res://scripts/ui/build_catalog.gd")
static func show(hub):
	hub.close_station();hub.phase="workshop";hub.dpad.enabled=false;hub.fire_pad.enabled=false;hub.start_button.disabled=true
	var root=Control.new();hub.build_menu=root;hub.root.add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_to_group("selection_scope")
	var shade=ColorRect.new();root.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.5)
	var panel=UiKit.panel(root,(root.get_viewport_rect().size-Vector2(1060,690))*.5,Vector2(1060,690))
	UiKit.label(panel,"Строительство",Vector2(24,18),Vector2(750,40),UiKit.PAGE_TITLE_SIZE)
	UiKit.button(panel,"×",Vector2(984,18),Vector2(50,42),hub.close_station)
	UiKit.label(panel,"Развивай базу между вылазками · %d ◈" % Game.credits,Vector2(24,65),Vector2(980,28),16,UiKit.MUTED)
	for i in range(3):
		var button=UiKit.button(panel,["Верстаки","Площадки","Снаряжение"][i],Vector2(24+i*338,106),Vector2(326,40),func():hub.build_tab=i;show(hub))
		if i==hub.build_tab:button.add_theme_stylebox_override("normal",UiKit.style(Color("584a2c"),8))
		var ids=Catalog.IDS.slice(0,4) if i==0 else Catalog.IDS.slice(4) if i==1 else ["reroll"]
		if ids.any(func(id):return Catalog.has_news(id)):Catalog.dot(button,Vector2(295,8))
	var scroll=ScrollContainer.new();panel.add_child(scroll);scroll.position=Vector2(24,146+UiKit.TAB_CONTENT_GAP);scroll.size=Vector2(1012,462);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var grid=GridContainer.new();scroll.add_child(grid);grid.columns=2;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",16);grid.add_theme_constant_override("v_separation",16)
	if hub.build_tab<2:
		for id in (Catalog.IDS.slice(0,4) if hub.build_tab==0 else Catalog.IDS.slice(4)):
			var card=Panel.new();grid.add_child(card);card.custom_minimum_size=Vector2(485,302);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_theme_stylebox_override("panel",UiKit.style(Color("30382f"),12))
			var built=id in Game.built_workshops;var known=id in Game.research_unlocks
			UiKit.locked_preview(Catalog.preview(card,id,Vector2(10,12),Vector2(185,160)),not known)
			UiKit.label(card,Catalog.INFO[id][0],Vector2(204,20),Vector2(267,56),21).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			UiKit.label(card,"Построено" if built else ("Можно построить" if Game.credits>=Game.BUILD_COST[id] else "Нужно ещё %d ◈" % (Game.BUILD_COST[id]-Game.credits)) if known else "Нужен чертёж",Vector2(204,87),Vector2(266,28),15,UiKit.MUTED)
			var desc=UiKit.label(card,Catalog.INFO[id][1],Vector2(16,174),Vector2(451,64),15);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			if Catalog.has_news(id):
				var dot=Catalog.dot(card,Vector2(455,12))
				card.mouse_entered.connect(func():Catalog.mark(id);dot.hide())
			var title=("К полигону" if id=="range" else "Открыть") if built else "Построить · %d ◈" % Game.BUILD_COST[id] if known else "Найди чертёж в вылазке"
			var button=UiKit.button(card,title,Vector2(16,249),Vector2(453,38),func():
				Catalog.mark(id)
				if built:hub.close_station();Catalog.open_bench(hub,id)
				elif Game.build_workshop(id):hub.update_bench_visuals();show(hub))
			button.add_theme_font_size_override("font_size",16);button.disabled=not built and (not known or Game.credits<Game.BUILD_COST[id]);UiKit.muted_locked_button(button)
			button.tooltip_text="Не хватает %d сплава" % maxi(0,Game.BUILD_COST[id]-Game.credits) if known and not built and button.disabled else Catalog.INFO[id][1]
	else:
		for id in ["bag","reroll"]:
			var card=Panel.new();grid.add_child(card);card.custom_minimum_size=Vector2(485,300);card.add_theme_stylebox_override("panel",UiKit.style(Color("30382f"),12))
			UiKit.icon(card,"inventory" if id=="bag" else "repeat",Vector2(185,20),Vector2(110,100))
			UiKit.label(card,"Рюкзак · %d / 6" % Game.backpack_slots if id=="bag" else "Перебросы · %d / 5" % Game.reroll_level,Vector2(18,134),Vector2(450,35),22)
			UiKit.label(card,"Больше места для чертежей. Ресурсы не занимают ячейки." if id=="bag" else "Повторный выбор карточек. Запас восстанавливается в начале вылазки.",Vector2(18,177),Vector2(450,64),15).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			var price=Game.bag_cost() if id=="bag" else Game.reroll_cost();var full=Game.backpack_slots>=6 if id=="bag" else Game.reroll_level>=5;var known=id=="bag" or "reroll" in Game.research_unlocks
			var button=UiKit.button(card,"Максимум" if full else "Нужен чертёж" if not known else "+1 · %d ◈" % price,Vector2(18,249),Vector2(450,38),func():Game.upgrade_backpack() if id=="bag" else Game.upgrade_rerolls();Catalog.mark(id);show(hub));button.disabled=full or not known or Game.credits<price
	UiKit.label(panel,"Чертёж открывает постройку. Строительство и улучшения сохраняются после вылазки.",Vector2(24,646),Vector2(1005,28),14,UiKit.MUTED)
