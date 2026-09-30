extends Control
signal closed
signal exit_requested
signal restart_requested
var can_restart=false
var can_leave=true
var arena
var manage=false
var tab=""
const MEMORY=preload("res://scripts/ui/tablet_memory.gd")
const REMEMBERED=["selected_quest","message_tab","about_tab","quest_filter","music_folder","music_scroll","settings_tab","guide_query","guide_category","guide_section","guide_expanded","guide_scroll","nav_collapsed"]
var page_key=""
var page_scrolls:Dictionary={}
var memory_ready=false
var selected_quest=""
var message_tab="important"
var about_tab="info"
var quit_confirm:Control
var quest_filter="all"
## Width of a quest bubble; the feed spans the whole block under the tabs.
var quest_bubble_width=513.0
var waiting_key=""
var music_folder="all"
var music_scroll=0
var settings_tab="Видео"
var guide_query=""
var guide_category="Все"
var guide_section="Все подразделы"
var guide_box:VBoxContainer
var guide_count:Label
var dev_edit=false
var nav_collapsed=false
var nav_progress=0.0
var nav_tween:Tween
var nav_buttons:Array=[]
var nav_geometry:Array=[]
var nav_reference_width=775.0
var nav_toggle:Button
var guide_expanded:Dictionary={}
var guide_tree
var guide_status=""
var guide_scroll=0.0
const GUIDE=preload("res://scripts/ui/encyclopedia_catalog.gd")
var content:Control
var panel:Panel
const Q=preload("res://scripts/progression/quest_catalog.gd")
func _ready():
	var saved=MEMORY.read()
	for key in REMEMBERED:
		if saved.has(key):set(key,saved[key])
	page_scrolls=saved.get("scrolls",{}).duplicate(true)
	if tab=="":tab=saved.get("manage_tab" if manage else "tab","quests" if manage else "inventory")
	if tab=="base" and not manage:tab="inventory"
	if manage and tab not in ["quests","base","notifications","guide","tech"]:tab="quests"
	memory_ready=true
	Texts.changed.connect(func():refresh.call_deferred())
	if is_instance_valid(Game.music_controller):
		Game.music_controller.browser_folder=music_folder;Game.music_controller.browser_scroll=music_scroll
	add_to_group("selection_scope");set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);get_viewport().size_changed.connect(fit_panel);refresh()
func refresh():
	remember_page()
	var was_animating=is_instance_valid(nav_tween) and nav_tween.is_running()
	if is_instance_valid(nav_tween):nav_tween.kill()
	if not was_animating:nav_progress=1.0 if nav_collapsed else 0.0
	nav_buttons.clear();nav_geometry.clear()
	for child in get_children():remove_child(child);child.queue_free()
	var dim=ColorRect.new();add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,0,0,.38)
	panel=UiKit.glass(self,Vector2.ZERO,Vector2(1060,690),Color("283b33"));fit_panel()
	UiKit.label(panel,"Командный центр" if manage else "Полевой планшет",Vector2(82,18),Vector2(840,40),27,Color("e8ecdc"))
	var close_button=UiKit.button(panel,"",Vector2(981,17),Vector2(52,44),func():closed.emit())
	close_button.icon=UiKit.interface_icon("close");close_button.tooltip_text="Закрыть планшет";close_button.expand_icon=true;close_button.add_theme_constant_override("icon_max_width",20)
	var toggle=UiKit.button(panel,"",Vector2(22,18),Vector2(44,40),toggle_navigation)
	nav_toggle=toggle
	toggle.icon=UiKit.interface_icon("right" if nav_collapsed else "left");toggle.tooltip_text="Развернуть меню" if nav_collapsed else "Свернуть меню";toggle.expand_icon=true;toggle.add_theme_constant_override("icon_max_width",22)
	var p=Game.progression
	if tab in ["active","tracked","completed","orders"]:
		quest_filter={"completed":"completed","orders":"operations"}.get(tab,"all");tab="quests"
	var tabs=[["inventory","Снаряжение"],["fighter","Боец"],["quests","Задачи · %d" % p.quests("available" if manage else "active").size()],["notifications","Лента · %d" % Game.notifications.unread()],["music","Радио"],["settings","Настройки"],["guide","Энциклопедия"],["about","Об игре"],["tech","Тех. информация"]]
	# Command centre: quests first, then a compact summary; loadout, radio and settings stay in the field tablet.
	if manage:tabs=[tabs[2],["base","Сводка"],tabs[3],["guide","Энциклопедия"],["tech","Тех. информация"]]
	for i in range(tabs.size()):
		var key=tabs[i][0]
		var b=sidebar_button(tabs[i][1],key,80+i*(44 if manage or can_quit() else 48),40,func():tab=key;mark_section(key);refresh())
		b.add_theme_stylebox_override("normal",UiKit.style(Color("584a2c") if tab==key else Color("3c4435") if section_new(key) else Color("242d27"),6))
		if section_new(key):UiKit.badge(b,"news",0,"trailing")
	content=UiKit.panel(panel,Vector2(104 if nav_collapsed else 261,80),Vector2(932 if nav_collapsed else 775,585),Color("242d27"))
	var inner=UiKit.style(Color("242d27"),0);inner.set_border_width_all(0);inner.border_width_left=1;content.add_theme_stylebox_override("panel",inner)
	match tab:
		"base":base_page()
		"notifications":messages_page()
		"orders":orders_page()
		"inventory":inventory_page()
		"guide":guide_page()
		"about":about_page()
		"tech":content.add_child(preload("res://scripts/ui/technical_guides.gd").new())
		"fighter":preload("res://scripts/ui/tablet_pages.gd").new(self).fighter()
		"music":preload("res://scripts/ui/tablet_pages.gd").new(self).radio()
		"settings":preload("res://scripts/ui/tablet_pages.gd").new(self).settings()
		_:quest_page()

	if nav_collapsed and tab in ["inventory","fighter","settings","quests","base","about"]:expand_layout(content,932.0/775.0)
	if tab=="music":
		for child in content.get_children():
			if child is PanelContainer:child.size.x=content.size.x-44
	if not manage:
		# Actions stack upward from the panel bottom; quitting is desktop-only.
		var actions=[["Продолжить [Esc]","play",40,func():closed.emit(),true]]
		if can_restart:actions.append(["Заново","repeat",40,func():restart_requested.emit(),false])
		if can_leave:actions.append(["В хаб","base",36,func():exit_requested.emit(),false])
		if can_quit():actions.append(["Выйти из игры","exit",36,confirm_quit,false])
		var bottom=664.0
		for i in range(actions.size()-1,-1,-1):
			var action=actions[i];bottom-=action[2]
			nav_action(action[0],action[1],bottom,action[2],action[3],action[4]);bottom-=8
	content.clip_contents=true
	nav_reference_width=content.size.x
	capture_navigation_geometry(content)
	apply_navigation(nav_progress)
	if was_animating:animate_navigation()
	page_key=scroll_key()
	restore_page.call_deferred(page_key,content)

func sidebar_button(title:String,icon:String,y:float,height:float,callback:Callable,primary=false)->Button:
	var button=UiKit.button(panel,"",Vector2(22,y),Vector2(221,height),callback,primary)
	button.tooltip_text=title;button.clip_contents=true;button.name="Nav_"+icon
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style=button.get_theme_stylebox(state).duplicate()
		if style is StyleBoxFlat:
			style.set_corner_radius_all(6);style.content_margin_left=8;style.content_margin_right=8;style.content_margin_top=5;style.content_margin_bottom=5
		button.add_theme_stylebox_override(state,style)
	var picture=UiKit.icon(button,icon,Vector2(18,(height-22)*.5),Vector2(22,22));picture.texture=UiKit.interface_icon("guide" if icon=="tech" else icon);picture.name="FixedIcon";picture.modulate=Color("20271f") if primary else UiKit.INK
	var label=UiKit.label(button,title,Vector2(52,0),Vector2(159,height),14 if primary else 16,Color("20271f") if primary else UiKit.INK);label.name="Caption";label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.clip_text=true
	nav_buttons.append(button)
	return button
func nav_action(title:String,icon:String,y:float,height:float,callback:Callable,primary=false):
	sidebar_button(title,icon,y,height,callback,primary)
func toggle_navigation():
	nav_collapsed=not nav_collapsed
	nav_toggle.icon=UiKit.interface_icon("right" if nav_collapsed else "left")
	nav_toggle.tooltip_text="Развернуть меню" if nav_collapsed else "Свернуть меню"
	animate_navigation()
func animate_navigation():
	if is_instance_valid(nav_tween):nav_tween.kill()
	nav_tween=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	nav_tween.tween_method(apply_navigation,nav_progress,1.0 if nav_collapsed else 0.0,.20)
func capture_navigation_geometry(parent:Node):
	for child in parent.get_children():
		if not child is Control:continue
		nav_geometry.append({"node":child,"position":child.position,"size":child.size,"minimum":child.custom_minimum_size,"fixed":not parent is Container and is_equal_approx(child.anchor_left,child.anchor_right)})
		capture_navigation_geometry(child)
func apply_navigation(value:float):
	nav_progress=value
	for button in nav_buttons:
		button.size.x=lerpf(221,60,value)
		var label=button.get_node("Caption");label.modulate.a=clampf((button.size.x-64)/90.0,0,1)
	content.position.x=lerpf(261,104,value);content.size.x=lerpf(775,932,value)
	var factor=content.size.x/nav_reference_width
	for item in nav_geometry:
		var child=item.node
		if not is_instance_valid(child):continue
		if item.fixed:
			child.position=Vector2(item.position.x*factor,item.position.y)
			if not child is TextureRect:child.size=Vector2(item.size.x*factor,item.size.y)
		if item.minimum.x>0:child.custom_minimum_size=Vector2(item.minimum.x*factor,item.minimum.y)
func scroller(pos:Vector2,size:Vector2)->VBoxContainer:
	var scroll=ScrollContainer.new();content.add_child(scroll);scroll.position=pos;scroll.size=size;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var box=VBoxContainer.new();scroll.add_child(box);box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",8);return box
func list_button(box:VBoxContainer,text:String,callback:Callable,height=65):
	var b=Button.new();box.add_child(b);Texts.set_text(b,text);b.custom_minimum_size=Vector2(0,height);b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.add_theme_font_size_override("font_size",16);b.add_theme_color_override("font_color",UiKit.INK);b.add_theme_stylebox_override("normal",UiKit.style(Color("dae1d3"),6));b.pressed.connect(callback);return b
func quest_page():
	var p=Game.progression
	if manage:p.prepare_telegrams()
	UiKit.label(content,"Задачи",Vector2(UiKit.PAGE_PADDING,20),Vector2(700,28),UiKit.PAGE_TITLE_SIZE)
	var filters=[["all","Все"],["general","Штаб усов"],["institute","Институт"],["operations","Оперштаб"],["completed","Готово"]]
	# Horizontal tabs across the whole block; the feed takes the full width below them.
	var full=content.size.x-UiKit.PAGE_PADDING*2
	quest_bubble_width=full-56-14
	UiKit.tab_row(content,Vector2(UiKit.PAGE_PADDING,UiKit.PAGE_CONTENT_TOP),full,filters,quest_filter,func(key):quest_filter=key;refresh())
	var quests=p.quests("completed" if quest_filter=="completed" else "available" if manage else "active")
	# Feed filters follow the sender: story — Штаб усов, hub chain — Институт, briefings and orders — Оперштаб.
	var sender_filter={"general":"story","institute":"institute","operations":"operations"}.get(quest_filter,"")
	if sender_filter!="":quests=quests.filter(func(q):return Q.sender(q)==sender_filter)
	var feed_top=UiKit.PAGE_CONTENT_TOP+40+UiKit.TAB_CONTENT_GAP
	var box=scroller(Vector2(UiKit.PAGE_PADDING,feed_top),Vector2(full,content.size.y-feed_top-16));box.name="QuestFeed";box.add_theme_constant_override("separation",12)
	var incoming=quest_filter in ["all","operations"] and p.telegram.is_empty() and not p.telegram_options.is_empty() and p.order_wait==0
	if incoming:telegram_offer_card(box)
	if quests.is_empty() and not incoming:list_button(box,"Новая телеграмма после следующей вылазки" if quest_filter=="operations" and p.order_wait>0 else "Нет заданий",func():pass,60)
	var done=quest_filter=="completed"
	# Messenger order: new messages on top, then ready to hand in, then the rest.
	var ranked=quests.map(func(q):
		var order=str(q.id).begins_with("order_");var count=int(q.goal) if done else p.count(q)
		var news=p.operations_news() if order else ("quest:"+q.id not in p.seen or (count>=q.goal and "ready:"+q.id not in p.seen))
		return {"q":q,"count":count,"news":news and not done,"ready":count>=q.goal and not done})
	ranked.sort_custom(func(a,b):return int(a.news)*2+int(a.ready)>int(b.news)*2+int(b.ready))
	for i in range(ranked.size()):
		var card=quest_message(ranked[i].q,ranked[i].count,ranked[i].news,ranked[i].ready,done);box.add_child(card)
		if ranked[i].news:UiKit.arrive(card,i)
		else:UiKit.reveal(card,i)
	p.view_quest_updates(quest_filter)
## One quest as a message: sender avatar, bubble with title, hint, progress bar, rewards and actions.
func quest_message(q:Dictionary,count:int,news:bool,ready:bool,done:bool)->Control:
	var bw=quest_bubble_width
	var p=Game.progression
	var order=str(q.id).begins_with("order_");var taken=q.id in p.accepted or order
	var sender=Q.SENDERS[Q.sender(q)]
	var actions=manage and not done
	var height=(206 if not actions else (296 if order and taken else 250))
	var row=Control.new();row.name="Quest_"+str(q.id);row.custom_minimum_size=Vector2(0,height)
	var avatar=Panel.new();row.add_child(avatar);avatar.position=Vector2(0,4);avatar.size=Vector2(46,46);avatar.add_theme_stylebox_override("panel",UiKit.style(Color(sender.color),23))
	var glyph=UiKit.icon(avatar,sender.icon,Vector2(11,11),Vector2(24,24));glyph.texture=UiKit.interface_icon(sender.icon)
	var bubble=Panel.new();row.add_child(bubble);bubble.name="Bubble";bubble.position=Vector2(56,0);bubble.size=Vector2(bw,height)
	var tint=Color("eee4bf") if ready else Color("cfddbf") if news else Color("dce3d5")
	var style=UiKit.style(tint,12);style.corner_radius_top_left=3;bubble.add_theme_stylebox_override("panel",style)
	var status="готово к сдаче" if ready else "новое" if news else "выполнено" if done else ("в работе" if taken else "предложение")
	UiKit.label(bubble,sender.name+" · "+status,Vector2(14,8),Vector2(bw-93,20),13,Color(sender.color).darkened(.25))
	UiKit.label(bubble,q.text,Vector2(14,28),Vector2(bw-73,30),19)
	var hint=UiKit.label(bubble,q.get("hint",Q.hint(q.id)),Vector2(14,60),Vector2(bw-28,48),15);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hint.set_meta("literal_text",true)
	for child in hint.get_children():hint.remove_child(child);child.queue_free()
	var track=ColorRect.new();bubble.add_child(track);track.position=Vector2(14,118);track.size=Vector2(bw-28,8);track.color=Color(0,0,0,.14)
	var fill=ColorRect.new();track.add_child(fill);fill.size=Vector2((bw-28)*clampf(float(count)/maxf(1,q.goal),0,1),8);fill.color=Color(sender.color);fill.name="Progress"
	UiKit.label(bubble,"%s: %d / %d" % [Q.counter_name(q.event),count,q.goal],Vector2(14,130),Vector2(bw-28,24),15)
	var reward="%d ◈" % q.alloy+(" · %d док." % int(q.get("docs",0)) if int(q.get("docs",0))>0 else "")
	if order:reward+=" · осталось вылазок: %d" % q.get("runs_left",0)
	UiKit.label(bubble,reward,Vector2(14,158),Vector2(bw-28,24),15,UiKit.MUTED)
	if not done and taken:
		var eye=UiKit.button(bubble,"" if q.id in p.tracked else "+",Vector2(bw-51,8),Vector2(38,32),func():p.toggle_track(q.id);refresh());eye.tooltip_text="Не отслеживать" if q.id in p.tracked else "Отслеживать"
		if q.id in p.tracked:eye.add_child(preload("res://scripts/ui/tracked_eye.gd").new())
	if actions and taken:
		var claim=UiKit.button(bubble,"Забрать награду",Vector2(14,196),Vector2(bw-28,40),func():
			UiKit.leave(row,func():
				if order:p.claim_telegram()
				else:p.claim(q)
				refresh()),ready)
		claim.name="Claim";claim.disabled=count<q.goal;UiKit.muted_locked_button(claim)
		if order:UiKit.button(bubble,"Отказаться от приказа",Vector2(14,244),Vector2(bw-28,40),func():p.abandon_telegram();refresh()).add_theme_font_size_override("font_size",17)
	elif actions:
		UiKit.button(bubble,"Принять задание",Vector2(14,196),Vector2(bw-28,40),func():p.accept_quest(q.id);refresh(),true).name="Accept"
	return row
## Incoming order from Оперштаб as a message with three difficulty options.
func telegram_offer_card(box:VBoxContainer):
	var bw=quest_bubble_width
	var p=Game.progression;var sender=Q.SENDERS.operations
	var height=120+p.telegram_options.size()*64+(52 if manage else 30)
	var row=Control.new();row.name="TelegramOffer";box.add_child(row);row.custom_minimum_size=Vector2(0,height)
	var avatar=Panel.new();row.add_child(avatar);avatar.position=Vector2(0,4);avatar.size=Vector2(46,46);avatar.add_theme_stylebox_override("panel",UiKit.style(Color(sender.color),23))
	var glyph=UiKit.icon(avatar,sender.icon,Vector2(11,11),Vector2(24,24));glyph.texture=UiKit.interface_icon(sender.icon)
	var bubble=Panel.new();row.add_child(bubble);bubble.name="Bubble";bubble.position=Vector2(56,0);bubble.size=Vector2(bw,height)
	var style=UiKit.style(Color("eee4bf"),12);style.corner_radius_top_left=3;bubble.add_theme_stylebox_override("panel",style)
	UiKit.label(bubble,sender.name+" · телеграмма",Vector2(14,8),Vector2(bw-93,20),13,Color(sender.color).darkened(.25))
	UiKit.label(bubble,"Новый приказ",Vector2(14,28),Vector2(bw-73,30),19)
	UiKit.label(bubble,"Выбери сложность или откажись.",Vector2(14,60),Vector2(bw-28,26),15,UiKit.MUTED)
	for i in range(p.telegram_options.size()):
		var q=p.telegram_options[i];var y=96+i*64
		var title=UiKit.label(bubble,q.difficulty+" · "+q.text,Vector2(14,y),Vector2(310 if manage else 485,28),16);title.clip_text=true
		UiKit.label(bubble,"%d вылазки · %d ◈" % [q.run_limit,q.alloy],Vector2(14,y+28),Vector2(310,24),14,UiKit.MUTED)
		if manage:UiKit.button(bubble,"Принять",Vector2(334,y+6),Vector2(165,42),func():p.choose_telegram(i);refresh(),i==1).add_theme_font_size_override("font_size",15)
	if manage:UiKit.button(bubble,"Отказаться от телеграммы",Vector2(14,height-50),Vector2(bw-28,40),func():p.abandon_telegram();refresh()).add_theme_font_size_override("font_size",16)
	else:UiKit.label(bubble,"Принять или отказаться можно в хабе.",Vector2(14,height-30),Vector2(bw-28,24),14,UiKit.MUTED)
	UiKit.arrive(row,0)
func orders_page():
	quest_filter="operations";quest_page()
func messages_page():
	UiKit.label(content,"Лента",Vector2(UiKit.PAGE_PADDING,20),Vector2(720,28),UiKit.PAGE_TITLE_SIZE)
	for i in range(2):
		var key="important" if i==0 else "technical"
		var button=UiKit.button(content,"Важные" if i==0 else "Технические",Vector2(22+i*190,68),Vector2(180,38),func():message_tab=key;refresh())
		if message_tab==key:button.add_theme_stylebox_override("normal",UiKit.style(Color("584a2c"),6))
	UiKit.label(content,"Задания, развитие и открытия" if message_tab=="important" else "Боевые реплики · без всплывающих уведомлений",Vector2(22,106+UiKit.TAB_CONTENT_GAP),Vector2(720,26),14,UiKit.MUTED)
	var box=scroller(Vector2(22,164),Vector2(content.size.x-44,335))
	for i in range(Game.notification_history.size()-1,-1,-1):
		var entry=Game.notification_history[i]
		if Game.notifications.category(entry)!=message_tab:continue
		var card=preload("res://scripts/ui/message_card.gd").new();card.entry=entry;box.add_child(card);card.read_requested.connect(func():entry.read=true;Game.save_progress();refresh())
	if box.get_child_count()==0:UiKit.label(box,"Пока нет сообщений",Vector2.ZERO,Vector2(500,40),16,UiKit.MUTED)
	UiKit.reveal_list(box)
	UiKit.button(content,"Прочитать эту вкладку",Vector2(22,518),Vector2(300,40),func():Game.notifications.mark_all(message_tab);refresh()).add_theme_font_size_override("font_size",16)
func base_page():preload("res://scripts/ui/base_dashboard.gd").render(self)
func inventory_page():preload("res://scripts/ui/tablet_pages.gd").new(self).inventory()

func about_page():
	UiKit.label(content,"Об игре",Vector2(UiKit.PAGE_PADDING,20),Vector2(720,28),UiKit.PAGE_TITLE_SIZE)
	for i in range(2):
		var key=["info","changelog"][i]
		var button=UiKit.button(content,["Об игре","Changelog"][i],Vector2(22+i*190,68),Vector2(180,38),func():about_tab=key;refresh())
		button.name="AboutTab_"+key
		if about_tab==key:button.add_theme_stylebox_override("normal",UiKit.style(Color("584a2c"),6))
	if about_tab=="changelog":changelog_page();return
	UiKit.label(content,"War Cats",Vector2(22,130),Vector2(720,54),36)
	var description=UiKit.label(content,"Тактический экшен с развитием между вылазками. Защищай штаб, захватывай технику и пробивайся к командиру.",Vector2(22,195),Vector2(690,90),20)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	UiKit.label(content,"Версия %s · Сборка %s\nВ разработке" % [ProjectSettings.get_setting("application/config/version","0.1"),ProjectSettings.get_setting("application/config/build","1")],Vector2(22,310),Vector2(700,65),18,UiKit.MUTED)
	UiKit.label(content,"Автор · Alexander Nikolaev\ntext@test.com",Vector2(22,420),Vector2(700,75),21)
# Changelog entries carry their own ru/en text, so the box is excluded from automatic translation.
# Version tabs on top; the selected release shows a summary line and compact sections.
var changelog_version=""
func changelog_page():
	var notes=preload("res://scripts/ui/changelog.gd")
	var versions:Array=notes.versions()
	if versions.is_empty():UiKit.label(content,"—",Vector2(22,124),Vector2(300,30),16);return
	if changelog_version not in versions:changelog_version=versions[0]
	var tabs=versions.slice(0,5).map(func(v):return [v,("Альфа "+v) if v!="earlier" else "Ранее"])
	var width=content.size.x-44
	UiKit.tab_row(content,Vector2(22,118),width,tabs,changelog_version,func(v):changelog_version=v;refresh(),36)
	var chosen:Array=notes.for_version(changelog_version)
	var total=0;var newest=""
	for entry in chosen:
		total+=entry.get(Texts.language,entry.get("ru",{})).get("items",[]).size()
		var day=str(entry.get("date",""))
		if day>newest:newest=day
	var summary=UiKit.label(content,"%s · %s · изменений: %d" % [("Альфа "+changelog_version) if changelog_version!="earlier" else "Ранее",notes.date_text(newest),total],Vector2(22,164),Vector2(width,24),14,UiKit.MUTED)
	summary.set_meta("text_editor",true)
	var box=scroller(Vector2(22,194),Vector2(width,content.size.y-210));box.name="ChangelogBox";box.set_meta("text_editor",true)
	box.add_theme_constant_override("separation",10)
	for entry in chosen:
		var text:Dictionary=entry.get(Texts.language,entry.get("ru",{}))
		var items:Array=text.get("items",[])
		var card=PanelContainer.new();box.add_child(card);card.add_theme_stylebox_override("panel",UiKit.style(Color("2c352e"),7))
		var margin=MarginContainer.new();card.add_child(margin)
		for side in ["left","right"]:margin.add_theme_constant_override("margin_"+side,14)
		for side in ["top","bottom"]:margin.add_theme_constant_override("margin_"+side,10)
		var column=VBoxContainer.new();margin.add_child(column);column.add_theme_constant_override("separation",6)
		var head=HBoxContainer.new();column.add_child(head)
		var heading=Label.new();head.add_child(heading);heading.text=str(text.get("title",""));heading.add_theme_font_size_override("font_size",18);heading.add_theme_color_override("font_color",UiKit.INK);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var count=Label.new();head.add_child(count);count.text=str(items.size());count.add_theme_font_size_override("font_size",13);count.add_theme_color_override("font_color",UiKit.ORANGE)
		for item in items:
			var line=Label.new();column.add_child(line);line.text="·  "+str(item);line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;line.add_theme_font_size_override("font_size",14);line.add_theme_color_override("font_color",UiKit.INK)
	UiKit.reveal_list(box)
func can_quit()->bool:
	return not OS.has_feature("mobile") and not OS.has_feature("web")
func confirm_quit():
	if is_instance_valid(quit_confirm):return
	var in_battle=is_instance_valid(arena) and arena.is_inside_tree()
	var endless_battle=in_battle and Campaign.endless
	quit_confirm=Control.new();quit_confirm.name="QuitConfirm";add_child(quit_confirm);quit_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);quit_confirm.add_to_group("guide_confirmation")
	var shade=ColorRect.new();quit_confirm.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.6)
	var width=minf(640,get_viewport_rect().size.x-40);var box=UiKit.panel(quit_confirm,(get_viewport_rect().size-Vector2(width,270))*.5,Vector2(width,270))
	UiKit.label(box,"Выйти из игры?",Vector2(24,22),Vector2(width-48,40),28)
	var body_text="Прогресс сохранится."
	if endless_battle:body_text="Бой не сохраняется: при возвращении эта комната начнётся заново. Усиления забега сохранятся."
	elif in_battle:body_text="Бой не сохраняется: при возвращении ты окажешься на карте маршрута перед этой комнатой. Усиления забега сохранятся."
	var body=UiKit.label(box,body_text,Vector2(24,78),Vector2(width-48,96),19);body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	UiKit.button(box,"Отмена",Vector2(width*.5+6,194),Vector2((width-60)*.5,50),cancel_quit,true)
	var quit_button=UiKit.button(box,"Выйти",Vector2(24,194),Vector2((width-60)*.5,50),func():Game.quit_game())
	quit_button.name="QuitAccept"
func cancel_quit():
	if is_instance_valid(quit_confirm):quit_confirm.queue_free();quit_confirm=null
func guide_page():
	var width=content.size.x
	UiKit.label(content,"Энциклопедия",Vector2(22,18),Vector2(440,36),24)
	if Texts.dev_enabled():UiKit.button(content,"Edit dev · "+("вкл" if dev_edit else "выкл"),Vector2(width-200,18),Vector2(178,36),func():dev_edit=not dev_edit;refresh()).add_theme_font_size_override("font_size",14)
	var search=LineEdit.new();search.name="GuideSearch";content.add_child(search)
	search.position=Vector2(22,66);search.size=Vector2(width-44,42);search.placeholder_text=Texts.localized("Поиск по статьям…");search.clear_button_enabled=true;Texts.set_text(search,guide_query);search.right_icon=UiKit.interface_icon("search")
	search.add_theme_font_size_override("font_size",18);search.add_theme_color_override("font_color",UiKit.INK)
	search.add_theme_stylebox_override("normal",UiKit.style(Color("1d2621"),6))
	search.add_theme_stylebox_override("focus",UiKit.style(Color("1d2621"),6,UiKit.ORANGE))
	search.text_changed.connect(func(value):guide_query=value;render_guide())
	guide_tree=preload("res://scripts/ui/guide_tree.gd").new(self);guide_tree.build()
	guide_count=UiKit.label(content,"",Vector2(253,119),Vector2(width-275,28),14,UiKit.MUTED)
	if dev_edit:
		UiKit.button(content,"+ Статья",Vector2(width-142,118),Vector2(120,30),func():preload("res://scripts/ui/encyclopedia_editor.gd").open_new(self)).add_theme_font_size_override("font_size",14)
	guide_box=scroller(Vector2(253,157),Vector2(width-275,406));render_guide()
func render_guide():
	for child in guide_box.get_children():guide_box.remove_child(child);child.queue_free()
	guide_box.get_parent().scroll_vertical=0
	var entries=GUIDE.search(guide_query,guide_category,guide_section)
	Texts.set_text(guide_count,"Статей: %d / %d" % [entries.size(),GUIDE.entries().size()])
	if entries.is_empty():
		var empty=Label.new();guide_box.add_child(empty);Texts.set_text(empty,"Ничего не найдено. Попробуй другое слово или раздел «Все».");empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for entry in entries:
		var card=PanelContainer.new();guide_box.add_child(card);card.add_theme_stylebox_override("panel",UiKit.style(Color("2c352e"),7))
		var margin=MarginContainer.new();card.add_child(margin)
		for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,14)
		var row=VBoxContainer.new();margin.add_child(row);row.add_theme_constant_override("separation",12)
		var picture=PanelContainer.new();row.add_child(picture);picture.custom_minimum_size=Vector2(0,180 if "ui/illustrations/" in entry.image else 84);picture.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;picture.size_flags_horizontal=Control.SIZE_EXPAND_FILL;picture.add_theme_stylebox_override("panel",UiKit.style(Color("1c241f"),5))
		if entry.image!="" and ResourceLoader.exists(entry.image):
			var art=TextureRect.new();picture.add_child(art);art.texture=load(entry.image);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		else:
			var placeholder=Label.new();picture.add_child(placeholder);Texts.set_text(placeholder,"Иллюстрация");placeholder.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;placeholder.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;placeholder.add_theme_font_size_override("font_size",13);placeholder.add_theme_color_override("font_color",UiKit.MUTED)
		var body=VBoxContainer.new();row.add_child(body);body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",8)
		var section=Label.new();body.add_child(section);Texts.set_text(section,entry.category+" / "+entry.section);section.add_theme_font_size_override("font_size",12);section.add_theme_color_override("font_color",UiKit.MUTED)
		var heading=Label.new();body.add_child(heading);Texts.set_text(heading,entry.title);heading.add_theme_font_size_override("font_size",20);heading.add_theme_color_override("font_color",UiKit.INK);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		if entry.term!="":
			var summary=Label.new();body.add_child(summary);Texts.set_text(summary,Texts.description(entry.term));summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;summary.add_theme_color_override("font_color",UiKit.ORANGE)
		if dev_edit and not entry.get("auto",false):UiKit.button(body,"Редактировать"+(" · общий термин" if entry.term!="" else ""),Vector2.ZERO,Vector2(0,30),func():preload("res://scripts/ui/encyclopedia_editor.gd").open(self,entry.id)).add_theme_font_size_override("font_size",14)
		var text=Label.new();body.add_child(text);Texts.set_text(text,entry.text);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.add_theme_font_size_override("font_size",17);text.add_theme_color_override("font_color",UiKit.INK)
	UiKit.reveal_list(guide_box)

func _input(event):
	if is_instance_valid(quit_confirm) and event.is_action_pressed("pause") and not event.is_echo():
		cancel_quit();get_viewport().set_input_as_handled();return
	if waiting_key=="" or not event is InputEventKey or not event.pressed or event.echo:return
	if event.physical_keycode==KEY_ESCAPE:waiting_key="";refresh();get_viewport().set_input_as_handled();return
	if event.physical_keycode<=0:return
	var old=Settings.keys[waiting_key]
	for action in Settings.keys:
		if Settings.keys[action]==event.physical_keycode:Settings.keys[action]=old
	Settings.keys[waiting_key]=event.physical_keycode;waiting_key="";Settings.apply();Settings.save();refresh();get_viewport().set_input_as_handled()

func signature(key:String)->String:
	var value=Game.progression.update_signature(key)
	if is_instance_valid(arena):
		if key=="inventory":value+=str([arena.weapon,arena.pending_recipes,arena.abilities.slots,arena.headquarters.loadout()])
		if key=="fighter":value+=str(arena.run.upgrade_history)
	return value
func section_new(key:String)->bool:
	if key=="notifications":return Game.notifications.unread()>0
	var value=signature(key)
	return value!="" and str(Game.progression.viewed_updates.get(key,""))!=value
func mark_section(key:String):
	Game.progression.view_section(key)
	Game.progression.viewed_updates[key]=signature(key);Game.save_progress()

func expand_layout(parent:Node,factor:float):
	for child in parent.get_children():
		if not child is Control:continue
		if not parent is Container:
			child.position.x*=factor
			if not child is TextureRect:child.size.x*=factor
		if child.custom_minimum_size.x>0:child.custom_minimum_size.x*=factor
		expand_layout(child,factor)

func scroll_key()->String:
	return tab+":"+str([guide_query,guide_category,guide_section]) if tab=="guide" else tab+":"+quest_filter if tab=="quests" else tab+":"+message_tab if tab=="notifications" else tab+":"+music_folder if tab=="music" else tab
func collect_scrolls(node:Node,result:Array):
	if node is ScrollContainer:result.append(node)
	for child in node.get_children():collect_scrolls(child,result)
func remember_page():
	if not memory_ready:return
	if is_instance_valid(content) and page_key!="":
		var scrolls=[];collect_scrolls(content,scrolls)
		page_scrolls[page_key]=scrolls.map(func(scroll):return scroll.scroll_vertical)
	var saved=MEMORY.read()
	for key in REMEMBERED:saved[key]=get(key)
	saved["manage_tab" if manage else "tab"]=tab
	saved.scrolls=page_scrolls.duplicate(true)
func restore_page(key:String,target):
	await get_tree().process_frame
	if not is_instance_valid(target) or target!=content or key!=page_key:return
	var scrolls=[];collect_scrolls(target,scrolls)
	var values=page_scrolls.get(key,[])
	for i in mini(scrolls.size(),values.size()):scrolls[i].scroll_vertical=int(values[i])
func _exit_tree():
	remember_page();MEMORY.write()

func fit_panel():
	if not is_instance_valid(panel):return
	var available=get_viewport_rect().size
	var factor=minf(1.0,minf((available.x-24)/1060.0,(available.y-24)/690.0))
	panel.scale=Vector2.ONE*factor;panel.position=(available-panel.size*factor)*.5
