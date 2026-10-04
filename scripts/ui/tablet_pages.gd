extends RefCounted
const STATS=preload("res://scripts/ui/stat_snapshot.gd")
var view
var arena
var content
func _init(owner):view=owner;arena=owner.arena;content=owner.content
func page(title:String,height:float=720)->Control:
	UiKit.accent(UiKit.label(content,title,Vector2(UiKit.PAGE_PADDING,20),Vector2(727,28),UiKit.PAGE_TITLE_SIZE))
	var box=view.scroller(Vector2(UiKit.PAGE_PADDING,UiKit.PAGE_CONTENT_TOP),Vector2(727,505))
	var body=Control.new();box.add_child(body);body.custom_minimum_size=Vector2(705,height);return body
func details(title:String,body:String,action:Callable=Callable()):
	var overlay=Control.new();view.add_child(overlay);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_to_group("selection_scope")
	var dim=ColorRect.new();overlay.add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,0,0,.5)
	var card=UiKit.glass(overlay,(view.get_viewport_rect().size-Vector2(570,300))*.5,Vector2(570,300))
	UiKit.label(card,title,Vector2(22,15),Vector2(480,42),23)
	var text=UiKit.label(card,body,Vector2(22,65),Vector2(520,155),18);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	UiKit.button(card,"Понятно",Vector2(22,235),Vector2(250 if action.is_valid() else 526,44),overlay.queue_free)
	if action.is_valid():UiKit.button(card,"Оставить на поле",Vector2(284,235),Vector2(264,44),func():action.call();overlay.queue_free())
func state_chip(parent:Control,pos:Vector2,item:Dictionary):
	var chip=Panel.new();parent.add_child(chip);chip.position=pos;chip.size=Vector2(222,48);chip.mouse_filter=Control.MOUSE_FILTER_PASS;chip.tooltip_text=Texts.render(str(item.title)+": "+str(item.value))
	chip.add_theme_stylebox_override("panel",UiKit.style(Color(1,1,1,.04),10,Color(1,1,1,.1)))
	var art=TextureRect.new();chip.add_child(art);art.texture=UiKit.icon_texture(str(item.icon));art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.position=Vector2(11,11);art.size=Vector2(26,26);art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if item.remaining!=null:
		var sector=preload("res://scripts/ui/timer_sector.gd").new();chip.add_child(sector);sector.position=Vector2(6,6);sector.size=Vector2(36,36);sector.mouse_filter=Control.MOUSE_FILTER_IGNORE;sector.set_remaining(float(item.remaining))
	UiKit.label(chip,str(item.title),Vector2(50,4),Vector2(166,22),14).clip_text=true
	UiKit.label(chip,str(item.value),Vector2(50,24),Vector2(166,20),12,UiKit.MUTED).clip_text=true
func cell(parent,pos:Vector2,id:String,title:String,info:String,locked=false,dimensions=Vector2(96,96),action:Callable=Callable()):
	var b=UiKit.button(parent,"🔒" if locked else "",pos,dimensions,func():details(title,info,action));b.tooltip_text=title+"\n"+info
	if not locked and id!="":UiKit.icon(b,id,Vector2(9,7),dimensions-Vector2(18,22))
	if locked:b.add_theme_stylebox_override("normal",UiKit.style(Color("d5dbcf"),9))
	return b
func inventory():
	# T-113: the gear screen from the author's sketch (scripts/ui/gear_page.gd); the old layout below is kept
	# only as inventory_legacy() for reference until the new one is accepted.
	preload("res://scripts/ui/gear_page.gd").new(view).build()
func inventory_legacy():
	var body=page("Снаряжение",775)
	var weapon=arena.weapon if is_instance_valid(arena) else Game.selected_weapon
	var data=Game.LOOT.WEAPONS[weapon]
	var weapon_stats=CombatStats.weapon(arena if is_instance_valid(arena) else null,weapon)
	var portrait=TextureRect.new();body.add_child(portrait);portrait.texture=preload("res://scripts/ui/class_gallery.gd").texture(Game.selected_class,true);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.position=Vector2(0,5);portrait.size=Vector2(205,330)
	UiKit.label(body,Game.CLASSES[Game.selected_class].name,Vector2(0,338),Vector2(205,30),18).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	# Weapons are wide: a landscape cell, the art fills it edge to edge (facing right, no plate).
	var weapon_cell=cell(body,Vector2(225,0),"",data.name,"Характеристики и улучшения — кнопка «Подробнее».",false,Vector2(170,82))
	UiKit.icon(weapon_cell,weapon,Vector2(8,6),Vector2(154,70)).name="WeaponArt"
	UiKit.label(body,data.name,Vector2(411,4),Vector2(290,30),22)
	UiKit.button(body,"Подробнее",Vector2(411,43),Vector2(180,34),func():weapon_details(weapon)).add_theme_font_size_override("font_size",15)
	var bars=STATS.add_bars(body,Vector2(225,95),470,STATS.weapon(arena if is_instance_valid(arena) else null,weapon),64,true)
	# Everything below the weapon bars flows from their real height (no fixed gap under compact rows).
	var shift=95+bars.content_height()+6-288
	UiKit.label(body,"Серый — база · оранжевый + · красный −",Vector2(225,288+shift),Vector2(475,28),12,UiKit.MUTED)
	UiKit.label(body,"Способности",Vector2(225,326+shift),Vector2(210,28),17)
	var abilities=Game.class_loadout()
	for i in range(2):
		var id=abilities[i] if i<abilities.size() else ""
		cell(body,Vector2(225+i*85,362+shift),id,AbilityCatalog.DATA.get(id,{}).get("name","Второй навык класса"),AbilityCatalog.DATA.get(id,{}).get("description","Открывается в «Казарме»: уровень класса 5, затем 2500 сплава."),i>=abilities.size(),Vector2(76,76))
	UiKit.label(body,"Гаджет",Vector2(425,326+shift),Vector2(110,28),17)
	cell(body,Vector2(425,362+shift),Game.gadget,AbilityCatalog.DATA.get(Game.gadget,{}).get("name","Гаджет"),AbilityCatalog.DATA.get(Game.gadget,{}).get("description","Выбирается в «Арсенале» → Гаджеты."),Game.gadget=="",Vector2(76,76))
	UiKit.label(body,"Штаб",Vector2(540,326+shift),Vector2(140,28),17)
	var hq=Game.hq_loadout();var module=hq[0] if not hq.is_empty() else ""
	cell(body,Vector2(540,362+shift),module,HQCatalog.DATA.get(module,{}).get("name","Поддержка штаба"),HQCatalog.DATA.get(module,{}).get("description","Выбери модуль в «Штабе» → Технологии."),false,Vector2(76,76))
	# State: live effect timers and this run's bullet effects, three compact chips per row.
	var state=STATS.state(arena if is_instance_valid(arena) else null)
	var section=Control.new();section.name="StateSection";body.add_child(section);section.position=Vector2(0,462+shift);section.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UiKit.label(section,"Состояние",Vector2.ZERO,Vector2(690,30),UiKit.SECTION_SIZE)
	for i in state.size():state_chip(section,Vector2((i%3)*232,38+floori(i/3.0)*56),state[i])
	shift+=38+ceilf(state.size()/3.0)*56+14
	UiKit.label(body,"Трофеи · открыто %d из 6 ячеек" % Game.backpack_slots,Vector2(0,462+shift),Vector2(690,30),UiKit.SECTION_SIZE)
	var recipes=arena.pending_recipes if is_instance_valid(arena) else []
	for i in range(6):
		var locked=i>=Game.backpack_slots;var recipe=recipes[i] if i<recipes.size() else {}
		var title=Game.recipe_name(recipe) if not recipe.is_empty() else "Закрытая ячейка" if locked else "Пустая ячейка"
		var info="«Казарма» → Снаряжение → Рюкзак. Следующая ячейка: %d сплава." % Game.bag_cost() if locked else "Сюда попадает найденный чертёж. Донеси его в хаб." if recipe.is_empty() else "Чертёж найден в вылазке. Доставь в хаб, чтобы открыть: "+title
		var discard:Callable=Callable()
		if not recipe.is_empty():discard=func():arena.pending_recipes.erase(recipe);view.refresh()
		var b=cell(body,Vector2(i*115,505+shift),str(recipe.get("id","")),title,info,locked,Vector2(104,100),discard)
		UiKit.label(b,str(i+1),Vector2(8,76),Vector2(88,24),13,UiKit.MUTED)
	UiKit.label(body,"Ресурсы / не занимают ячейки",Vector2(0,626+shift),Vector2(690,28),18)
	cell(body,Vector2(0,666+shift),"","Сплав","Всего: %d. В этой вылазке: %d." % [Game.credits,arena.earned if is_instance_valid(arena) else 0]);UiKit.label(body,"%d ◈" % Game.credits,Vector2(5,700+shift),Vector2(90,30),18)
	body.custom_minimum_size.y=maxf(775,775+shift)
	if is_instance_valid(arena) and not arena.recipe_offer.is_empty():
		var take=UiKit.button(body,"Подобрать: "+Game.recipe_name(arena.recipe_offer.recipe),Vector2(0,778+shift),Vector2(680,45),func():arena.take_offered_recipe();view.closed.emit());take.disabled=recipes.size()>=Game.backpack_slots;body.custom_minimum_size.y=835+maxf(0,shift)
	STATS.follow_grid(body,bars)
## «Вылазка» (meta stage 2): a report of the current sortie, outside a run — of the last one.
func fighter():
	var body=page("Вылазка",600);var live=is_instance_valid(arena)
	var report=preload("res://scripts/ui/sortie_report.gd")
	report.build(body,report.snapshot(arena) if live else Game.progression.last_run,live)
	if live:
		var y=body.custom_minimum_size.y
		for line in STATS.status(arena):
			UiKit.label(body,line,Vector2(0,y),Vector2(690,44),15).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			y+=48
		body.custom_minimum_size.y=y
func weapon_details(id:String):
	var overlay=Control.new();view.add_child(overlay);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_to_group("selection_scope")
	var dim=ColorRect.new();overlay.add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,0,0,.65)
	var card=UiKit.glass(overlay,(view.get_viewport_rect().size-Vector2(650,540))*.5,Vector2(650,540))
	UiKit.label(card,Game.LOOT.WEAPONS[id].name+" · улучшения",Vector2(24,18),Vector2(600,38),24)
	STATS.add_bars(card,Vector2(24,70),600,STATS.weapon(arena if is_instance_valid(arena) else null,id))
	var mods=arena.run.weapon_mods[id] if is_instance_valid(arena) else {"damage":0.0,"interval":1.0,"intercept":0.0}
	var text="Постоянная сила оружия: ×%s\nУрон оружия за вылазку: +%s%%\nИнтервал между выстрелами: ×%s\nДобавка к напору: +%s п.п." % [UiKit.number(Game.weapon_factor(id)),UiKit.number(mods.damage*100),UiKit.number(mods.interval),UiKit.number(mods.intercept*100)]
	if is_instance_valid(arena):text+="\nОбщий бонус урона: +%s%% · интервал: ×%s" % [UiKit.number(arena.run.damage_bonus*30),UiKit.number(arena.run.fire_multiplier)]
	UiKit.label(card,text,Vector2(24,279),Vector2(602,130),16).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	UiKit.label(card,"Изменить улучшения можно на станциях хаба.",Vector2(24,432),Vector2(602,30),15,UiKit.MUTED)
	UiKit.button(card,"Закрыть",Vector2(24,480),Vector2(602,38),overlay.queue_free)
func radio():
	UiKit.label(content,"Радио",Vector2(22,18),Vector2(710,40),24)
	var player=preload("res://scenes/ui/music_mini_player.tscn").instantiate();content.add_child(player);player.position=Vector2(22,68);player.size=Vector2(731,105)
	var c=Game.music_controller
	if not is_instance_valid(c):return
	# Minimal two-pane radio: playlists on the left, tracks on the right, the playing one highlighted.
	var lists=[["main",c.MAIN_THEME]]
	for theme in c.themes:lists.append(["theme:"+theme,c.themes[theme].title])
	lists.append(["singles","Отдельные треки"])
	var ids=lists.map(func(l):return l[0])
	if view.music_folder not in ids:view.music_folder="main";c.browser_folder="main";view.music_scroll=0;c.browser_scroll=0
	var playing_theme=c.theme_of(c.current_track)
	var playing_list="theme:"+playing_theme if playing_theme!="" else "singles"
	var left=view.scroller(Vector2(22,186),Vector2(200,370));left.add_theme_constant_override("separation",2)
	for entry in lists:
		var id:String=entry[0]
		var node=Button.new();left.add_child(node);Texts.set_text(node,entry[1]);node.alignment=HORIZONTAL_ALIGNMENT_LEFT;node.custom_minimum_size=Vector2(0,34);node.clip_text=true;node.add_theme_font_size_override("font_size",14)
		var box=StyleBoxFlat.new();box.content_margin_left=10 if id=="main" else 22;box.bg_color=Color("584a2c") if view.music_folder==id else Color(0,0,0,0)
		for corner in ["corner_radius_top_left","corner_radius_top_right","corner_radius_bottom_left","corner_radius_bottom_right"]:box.set(corner,5)
		node.add_theme_stylebox_override("normal",box);var hover=box.duplicate();hover.bg_color=Color("3d4a3f");node.add_theme_stylebox_override("hover",hover)
		if id==playing_list or (id=="main" and c.current_track!=""):node.add_theme_color_override("font_color",UiKit.ORANGE)
		node.pressed.connect(func():view.music_folder=id;c.browser_folder=id;view.music_scroll=0;c.browser_scroll=0;view.refresh())
	var x0=238;var width=content.size.x-x0-22
	var box=view.scroller(Vector2(x0,186),Vector2(width,370));box.add_theme_constant_override("separation",3)
	var scroll=box.get_parent();scroll.get_v_scroll_bar().value_changed.connect(func(value):view.music_scroll=int(value);c.browser_scroll=int(value));scroll.set_deferred("scroll_vertical",view.music_scroll)
	var folder:String=view.music_folder
	if folder=="main":
		var on_air=c.mood_themes()
		var note=UiKit.label(box,"Станция: %s — %d подтем и %d треков. Сменить: настройки → звук." % [c.STATIONS[c.station()],on_air.size(),c.single_tracks().size()],Vector2.ZERO,Vector2(width,40),14,UiKit.MUTED)
		note.custom_minimum_size=Vector2(width,40);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.clip_text=false
		for theme in c.themes:
			var id="theme:"+theme
			var row=Button.new();box.add_child(row);Texts.set_text(row,c.themes[theme].title);row.alignment=HORIZONTAL_ALIGNMENT_LEFT;row.custom_minimum_size=Vector2(0,40);row.add_theme_font_size_override("font_size",15)
			row.add_theme_stylebox_override("normal",UiKit.style(Color("584a2c") if theme==playing_theme else Color("303a31"),5))
			if theme not in on_air:row.modulate.a=.45  # not on the current station
			row.pressed.connect(func():view.music_folder=id;c.browser_folder=id;view.music_scroll=0;c.browser_scroll=0;view.refresh())
		return
	var rows=[]
	if folder.begins_with("theme:"):
		var theme=folder.trim_prefix("theme:")
		for group in ["battle","hub","map","miniboss","boss"]:
			if c.themes[theme].has(group):rows.append([c.themes[theme][group],c.CONTEXT_NAMES[group]])
	else:
		for pair in c.single_tracks():rows.append([pair[0],c.CONTEXT_NAMES[pair[1]]])
	for entry in rows:
		var id:String=entry[0]
		var row=HBoxContainer.new();box.add_child(row);row.add_theme_constant_override("separation",6)
		var label=c.catalog.get(id,{}).get("title",id) if folder=="singles" else entry[1]
		var track=Button.new();row.add_child(track);Texts.set_text(track,("▶ " if c.current_track==id else "")+label);track.custom_minimum_size=Vector2(0,40);track.size_flags_horizontal=Control.SIZE_EXPAND_FILL;track.clip_text=true;track.alignment=HORIZONTAL_ALIGNMENT_LEFT;track.add_theme_font_size_override("font_size",15)
		track.add_theme_stylebox_override("normal",UiKit.style(Color("584a2c") if c.current_track==id else Color("303a31"),5))
		track.pressed.connect(func():c.paused=false;c.quick_switch=true;c.play_track(id);view.refresh())
		if folder=="singles":
			var section=Label.new();row.add_child(section);Texts.set_text(section,entry[1]);section.custom_minimum_size.x=100;section.add_theme_font_size_override("font_size",12);section.add_theme_color_override("font_color",UiKit.MUTED)
		var seconds=int(c.track_length(id));var time=Label.new();row.add_child(time);Texts.set_text(time,"%d:%02d" % [seconds/60,seconds%60]);time.custom_minimum_size.x=50;time.add_theme_font_size_override("font_size",12);time.add_theme_color_override("font_color",UiKit.MUTED)
func settings():
	UiKit.accent(UiKit.label(content,"Настройки",Vector2(UiKit.PAGE_PADDING,20),Vector2(727,28),UiKit.PAGE_TITLE_SIZE))
	var tabs=["Графика","Экран","Звук","Управление","Интерфейс"]
	if view.settings_tab=="Видео":view.settings_tab="Графика"
	# Same full-width tab row as the quest filters: equal sizes, the active tab only changes colour. Built at the
	# base 775 px page width: a collapsed menu stretches the page afterwards (T-103 — tabs ran off the panel).
	for button in UiKit.tab_row(content,Vector2(UiKit.PAGE_PADDING,UiKit.PAGE_CONTENT_TOP),775.0-UiKit.PAGE_PADDING*2,tabs.map(func(t):return [t,t]),view.settings_tab,func(key):view.settings_tab=key;view.waiting_key="";view.refresh()):
		button.add_theme_font_size_override("font_size",16)
	var box=view.scroller(Vector2(UiKit.PAGE_PADDING,UiKit.PAGE_CONTENT_TOP+40+UiKit.TAB_CONTENT_GAP),Vector2(727,366))
	var body=Control.new();box.add_child(body);body.custom_minimum_size=Vector2(705,350)
	var y=0
	if view.settings_tab=="Графика":
		# Two plain groups (author, 2026-10-03; measured on M4 Air, fullscreen Retina, a battle): what costs speed
		# and heat, and what only changes the look. One preset on top sets everything at once.
		setting_choice(body,["graphics_preset","Пресет графики",["Экономно","Стандарт","Кино"],["eco","standard","cinema"],"Экономно — быстрее и меньше греет ноутбук. Стандарт — по умолчанию. Кино — 3D в полном разрешении, примерно вдвое тяжелее."],y);y+=96
		y=graphics_group(body,"Влияет на скорость и нагрев",y)
		setting_choice(body,["render_scale","Разрешение 3D",["Авто","100%","75%","50%"],["auto","100","75","50"],"Самая сильная настройка: 100% почти вдвое тяжелее «Авто». Интерфейс всегда чёткий. Применяется кнопкой «Применить»."],y);y+=96
		y=graphics_toggle(body,"shaders","Шейдеры · уютный свет и металл","Весь мягкий свет, тени и блики разом. Выключение — +15% кадров днём, до +40% ночью; картинка станет простой.",y)
		for entry in [["ambient_occlusion","Затенение углов","Мягкая тень в углах и у стен. Около +9% кадров, если выключить."],["tilt_shift","Размытие краёв","Мягкий фокус сверху и снизу. Около +10% кадров, если выключить."],["glow","Свечение","Блики металла, золота и ламп. Около +4% кадров, если выключить."]]:
			y=graphics_toggle(body,entry[0],entry[1],entry[2],y,true)
		setting_choice(body,["light_budget","Источники света",["Экономно · 6","Обычно · 10","Больше света · 14"],[6,10,14],"Сколько ближних фонарей светит одновременно. Больше — тяжелее, особенно ночью."],y);y+=96
		y=graphics_group(body,"Только внешний вид — на скорость почти не влияют",y)
		var holder=Control.new();holder.name="AppearanceCard";body.add_child(holder);holder.position=Vector2(0,y);holder.mouse_filter=Control.MOUSE_FILTER_PASS
		preload("res://scripts/ui/appearance_card.gd").build(holder)
		y+=250
		setting_choice(body,["shader_style","Стиль картинки",["Пастель · мягкий мульт","Уютный · как раньше","Золотой час","Пасмурный фронт"],Settings.SHADER_STYLES,"Цвет солнца, тени, дымка и небо."],y);y+=96
		if Settings.values.get("world_lighting","day")=="night":setting_choice(body,["sun_night","Луна и солнце в бою",["Случайно","Конец заката","Луна","Перед рассветом"],["random","dusk","moon","predawn"],"Положение ночного света на поле."],y)
		else:setting_choice(body,["sun_day","Солнце в бою",["Случайно","Рассвет","Утро","Полдень","Золотой час","Закат"],["random","dawn","morning","noon","golden","sunset"],"Цвет и направление солнца; ниже 30° оно не опускается."],y)
		y+=96
		setting_choice(body,["weather","Погода в бою",["Случайно","Ясно","Дождь","Снег","Туман","Песчаная буря"],["random","clear","rain","snow","fog","sandstorm"],"Только оформление, на бой не влияет."],y);y+=96
		for entry in [["soft_shadows","Мягкие тени","Размытые края теней."],["haze","Дымка вдали","Лёгкий воздух у горизонта."],["rim_light","Контурный свет","Светлый край у моделей."],["shiny_metal","Блестящий металл","Отражения на металле."],["depth_light","Глубина света","Мягкие тени у стен, теплее солнце."],["cinematic_light","Киношный свет","Цветная подсветка сзади, у каждой комнаты своя."],["atmosphere","Атмосферные частицы","Пыль, листья, ночные светлячки."]]:
			y=graphics_toggle(body,entry[0],entry[1],entry[2],y,true)
	elif view.settings_tab=="Экран":
		setting_choice(body,["fullscreen","Режим экрана",["Окно","Полный экран"],[false,true],"Полный экран занимает весь дисплей."],y);y+=88
		var sizes=Settings.resolutions()
		var labels=["Как сейчас"]+sizes.map(func(r):return r.replace("x"," × "))
		setting_choice(body,["resolution","Разрешение окна",labels,["auto"]+sizes,"Размер окна в режиме «Окно». В полном экране игра занимает весь дисплей."],y);y+=88
		var retina=CheckButton.new();body.add_child(retina);retina.position=Vector2(0,y);retina.size=Vector2(700,40);Texts.set_text(retina,"Retina · полная чёткость")
		retina.button_pressed=bool(Settings.shown("retina"));retina.toggled.connect(func(on):Settings.change("retina",on);view.refresh.call_deferred())
		UiKit.label(body,"Без галочки мир рисуется в стандартном разрешении — в два раза меньше по каждой стороне на Retina-экране. Быстрее, но мягче.",Vector2(0,y+42),Vector2(700,44),14,UiKit.MUTED).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;y+=96
		for entry in [["vsync","Вертикальная синхронизация",["Выключена","Включена"],[false,true],"Убирает разрывы изображения; может ограничивать FPS."],["quality","Сглаживание MSAA",["Выключено","2×","4×"],[0,1,2],"Сглаживает края моделей. 4× сильнее нагружает графику."],["fps","Лимит кадров",["30 FPS","60 FPS","120 FPS","Без ограничения"],[30,60,120,0],"Верхняя граница; реальная частота зависит от устройства и VSync."]]:
			setting_choice(body,entry,y);y+=88
	elif view.settings_tab=="Звук":
		for entry in [["master","Общая громкость","Меняет громкость всей игры."],["music","Музыка","Музыкальные композиции и радио."],["effects","Звуки игры","Выстрелы, взрывы и звуковые сигналы."]]:
			UiKit.label(body,entry[1],Vector2(0,y),Vector2(305,34),19)
			var slider=HSlider.new();body.add_child(slider);slider.position=Vector2(320,y+7);slider.size=Vector2(290,28);slider.max_value=100;slider.step=1;slider.value=Settings.values[entry[0]]*100
			var value_label=UiKit.label(body,str(roundi(slider.value))+"%",Vector2(625,y),Vector2(75,34),17)
			slider.value_changed.connect(func(value):Settings.change(entry[0],value/100.0);Texts.set_text(value_label,str(roundi(value))+"%"))
			UiKit.label(body,entry[2],Vector2(0,y+41),Vector2(700,30),14,UiKit.MUTED);y+=96
		setting_choice(body,["music_mood","Музыкальная тема",["Главная","Ночная","Дневная","Авто"],["main","night","day","auto"],"Главная — все 12 подтем. Ночная — шесть спокойных, дневная — шесть энергичных. Авто — по времени суток мира: ночью ночная, днём дневная. Меняется при следующем переходе."],y);y+=96
	elif view.settings_tab=="Интерфейс":
		setting_choice(body,["input_scheme","Схема управления",["Авто","Клавиатура","Геймпад","Тач"],["auto","keyboard","gamepad","touch"],"Авто — по последнему устройству: касание экрана показывает экранные кнопки, клавиша или геймпад их прячут."],0)
		setting_choice(body,["biome_info","Подпись биома",["Скрыта","Показана"],[false,true],"Номер, название и покрытия карты под характеристиками оружия."],96)
		setting_choice(body,["language","Язык / Language",["Русский","English"],["ru","en"],"Язык интерфейса. Названия своих статей сохраняются как написаны."],192)
		setting_choice(body,["ui_motion","Анимации интерфейса",["Выключены","Включены"],[false,true],"Карточки и сообщения выезжают, кнопки пружинят при нажатии."],288)
		setting_choice(body,["show_fps","Счётчик кадров",["Скрыт","Показан"],[false,true],"FPS в углу экрана во всех режимах, в хабе — ещё и номер сборки."],384)
		setting_choice(body,["ui_glass","Стекло интерфейса",["Выключено","Включено"],[false,true],"Размытый полупрозрачный фон у окон. Выключи на слабом устройстве."],480)
		setting_choice(body,["ui_accent","Акцентный цвет",["Абрикос","Коралл","Мята","Лимон","Небо","Лаванда"],["apricot","coral","mint","lemon","sky","lavender"],"Цвет главных кнопок, выделения и цен."],576)
		y=672
	else:
		UiKit.label(body,"Нажми кнопку и новую клавишу. Esc — отмена. Занятые клавиши меняются местами.",Vector2(0,0),Vector2(700,46),14,UiKit.MUTED).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;y=55
		for group in [["Движение",["north","south","west","east"]],["Бой и действия",["fire","interact","hide_trench","ammo_switch","use_medkit","melee"]],["Способности",["class_ability","skill_1","ability","hq_ability"]]]:
			UiKit.label(body,group[0],Vector2(0,y),Vector2(700,30),15,UiKit.MUTED);y+=36
			for action in group[1]:
				UiKit.label(body,{"north":"Вверх / вперёд","south":"Вниз / назад","west":"Влево","east":"Вправо","fire":"Огонь","interact":"Выбрать / взаимодействовать","hide_trench":"Спрятаться в окопе","ammo_switch":"Сменить боеприпасы","use_medkit":"Аптечка из рюкзака","melee":"Удар лапой / прикладом","ability":"Гаджет","class_ability":"Навык класса","skill_1":"Второй навык класса","hq_ability":"Поддержка штаба"}[action],Vector2(0,y),Vector2(420,36),17)
				var button=UiKit.button(body,OS.get_keycode_string(Settings.keys[action]),Vector2(440,y),Vector2(260,36),func():view.waiting_key=action;view.refresh())
				if view.waiting_key==action:Texts.set_text(button,"Нажми клавишу…")
				y+=46
		UiKit.label(body,"Esc — открыть / закрыть планшет (постоянная клавиша).",Vector2(0,y),Vector2(700,36),14,UiKit.MUTED);y+=40
	body.custom_minimum_size.y=maxf(350,y)
	var waiting=not Settings.pending.is_empty()
	UiKit.label(content,"Есть неприменённые настройки экрана." if waiting else "Экран — кнопками «Применить» и «Сохранить»; остальное меняется сразу.",Vector2(22,498),Vector2(731,28),14,UiKit.ORANGE if waiting else UiKit.MUTED)
	var apply_button=UiKit.button(content,"Применить",Vector2(453,535),Vector2(150,36),func():Settings.apply_pending();view.refresh();keep_prompt())
	apply_button.disabled=not waiting;apply_button.add_theme_font_size_override("font_size",15)
	UiKit.button(content,"Сохранить",Vector2(613,535),Vector2(150,36),func():
		var had=not Settings.pending.is_empty();Settings.save_all();view.refresh()
		if had:keep_prompt(),true).add_theme_font_size_override("font_size",15)
	UiKit.button(content,"Сбросить вкладку",Vector2(22,535),Vector2(220,36),func():
		if view.settings_tab=="Управление":Settings.keys=Settings.DEFAULT_KEYS.duplicate()
		else:
			var group={"Графика":["graphics_preset","atmosphere","tilt_shift","ui_theme","shaders","shader_style","sun_day","sun_night","weather","soft_shadows","ambient_occlusion","glow","haze","rim_light","shiny_metal","depth_light","cinematic_light","world_lighting","light_budget"],"Экран":["fullscreen","resolution","retina","vsync","render_scale","quality","fps"],"Звук":["master","music","effects"],"Интерфейс":["input_scheme","biome_info","language","ui_motion","show_fps","ui_glass","ui_accent"]}[view.settings_tab]
			for key in group:Settings.values[key]=Settings.DEFAULT_VALUES[key];Settings.pending.erase(key)
		Settings.apply();Settings.save();view.waiting_key="";view.refresh()).add_theme_font_size_override("font_size",15)
## Industry-standard safety net for screen changes: «Оставить эти настройки?» with a 15 s countdown; no answer
## puts the old mode, size and quality back (a wrong mode can leave the screen unreadable).
func keep_prompt():
	if Settings.before_apply.is_empty():return
	var layer=view.get_tree().root
	var shade=ColorRect.new();shade.name="KeepDisplayPrompt";shade.color=Color(0,0,0,.45);shade.mouse_filter=Control.MOUSE_FILTER_STOP
	# The tablet pauses the game: the prompt must keep working (buttons, countdown) while paused.
	var canvas=CanvasLayer.new();canvas.layer=125;canvas.process_mode=Node.PROCESS_MODE_ALWAYS;layer.add_child(canvas);canvas.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_to_group("selection_scope")
	var box=Panel.new();shade.add_child(box);box.size=Vector2(460,170);box.add_theme_stylebox_override("panel",UiKit.style(Color("242d27"),16,Color("4a5a4f")))
	box.set_anchors_preset(Control.PRESET_CENTER);box.position=(shade.get_viewport_rect().size-box.size)*.5
	UiKit.label(box,"Оставить эти настройки экрана?",Vector2(24,20),Vector2(412,30),20)
	var timer_label=UiKit.label(box,"",Vector2(24,56),Vector2(412,26),15,UiKit.MUTED)
	var left=[15.0]
	var close=func(keep:bool):
		if not keep:Settings.revert_display()
		else:Settings.before_apply={};Settings.save()
		if is_instance_valid(canvas):canvas.queue_free()
		if is_instance_valid(view):view.refresh()
	UiKit.button(box,"Вернуть",Vector2(24,104),Vector2(196,44),func():close.call(false))
	var keep_button=UiKit.button(box,"Оставить",Vector2(240,104),Vector2(196,44),func():close.call(true),true);keep_button.grab_focus()
	var tick=func():
		left[0]-=1.0
		if left[0]<=0:close.call(false);return
		if is_instance_valid(timer_label):Texts.set_text(timer_label,Texts.render("Вернутся прежние через %d с") % int(left[0]))
	Texts.set_text(timer_label,Texts.render("Вернутся прежние через %d с") % 15)
	var t=Timer.new();t.wait_time=1.0;t.autostart=true;canvas.add_child(t);t.timeout.connect(tick)
## A group heading in the settings list.
func graphics_group(body:Control,title:String,y:float)->float:
	UiKit.label(body,title,Vector2(0,y+6),Vector2(700,28),UiKit.SECTION_SIZE,UiKit.MUTED)
	var line=ColorRect.new();body.add_child(line);line.position=Vector2(0,y+38);line.size=Vector2(700,1);line.color=Color(1,1,1,.14)
	return y+50
## One on/off setting with a short line of what it does; shader effects grey out while shaders are off.
func graphics_toggle(body:Control,key:String,title:String,note:String,y:float,needs_shaders:=false)->float:
	var toggle=CheckButton.new();body.add_child(toggle);Texts.set_text(toggle,title);toggle.position=Vector2(0,y);toggle.size=Vector2(700,36);toggle.name="Toggle_"+key
	toggle.button_pressed=bool(Settings.values.get(key,true));toggle.disabled=needs_shaders and not Settings.values.get("shaders",true)
	toggle.toggled.connect(func(enabled):
		Settings.change(key,enabled)
		if key=="shaders":view.refresh.call_deferred())
	UiKit.label(body,note,Vector2(0,y+36),Vector2(700,22),13,UiKit.MUTED).clip_text=true
	return y+66
func setting_choice(body,entry,y):
	UiKit.label(body,entry[1],Vector2(0,y),Vector2(380,34),18)
	var option=OptionButton.new();body.add_child(option);option.position=Vector2(395,y);option.size=Vector2(305,36);option.add_theme_font_size_override("font_size",17)
	for label in entry[2]:option.add_item(label)
	option.select(entry[3].find(Settings.shown(entry[0])));option.item_selected.connect(func(index):
		Settings.change(entry[0],entry[3][index])
		if entry[0] in Settings.DISPLAY_KEYS:view.refresh.call_deferred()
		# A preset flips many switches: redraw the page so they show it.
		if entry[0]=="graphics_preset":view.refresh.call_deferred())
	var hint=UiKit.label(body,entry[4],Vector2(0,y+42),Vector2(700,44),14,UiKit.MUTED);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
