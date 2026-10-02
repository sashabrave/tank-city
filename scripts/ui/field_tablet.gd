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
const REMEMBERED=["selected_quest","message_tab","about_tab","quest_filter","music_folder","music_scroll","settings_tab","guide_query","guide_category","guide_section","guide_expanded","guide_scroll","nav_collapsed","guide_open"]
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
var guide_box:Container
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
var guide_open=""  # article id shown in the reader, "" = grid
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
	var tabs=[["inventory","Снаряжение"],["fighter","Боец"],["quests","Задачи"],["notifications","Лента"],["music","Радио"],["settings","Настройки"],["guide","Энциклопедия"],["about","Об игре"],["tech","Тех. информация"]]
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

	# Pages built from content.size (quests) already know the collapsed width; scaling them again pushed cards out.
	if nav_collapsed and tab in ["inventory","fighter","settings","base","about"]:expand_layout(content,932.0/775.0)
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
## Children of a label (inline currency icons) follow their label's text, and nodes marked nav_static lay
## themselves out; neither is scaled with the menu animation.
func capture_navigation_geometry(parent:Node):
	if parent is Label or parent.has_meta("nav_static"):return
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
	# One feed, no sender tabs: what needs you is on top, taken work sinks, finished orders go to the bottom.
	var full=content.size.x-UiKit.PAGE_PADDING*2
	quest_bubble_width=full-56-14
	quest_filter="all"
	var quests=p.quests("available" if manage else "active")
	var finished=p.quests("completed").slice(-8)
	var feed_top=UiKit.PAGE_CONTENT_TOP
	var box=scroller(Vector2(UiKit.PAGE_PADDING,feed_top),Vector2(full,content.size.y-feed_top-16));box.name="QuestFeed";box.add_theme_constant_override("separation",12)
	var incoming=p.telegram.is_empty() and not p.telegram_options.is_empty() and p.order_wait==0
	if incoming:telegram_offer_card(box)
	if quests.is_empty() and finished.is_empty() and not incoming:list_button(box,"Нет заданий",func():pass)
	# Rank: ready to hand in 4, new 3, offer not taken yet 2, in progress 1; finished entries follow at the bottom.
	var ranked=quests.map(func(q):
		var order=str(q.id).begins_with("order_");var count=p.count(q);var taken=q.id in p.accepted or order
		var news=p.operations_news() if order else ("quest:"+q.id not in p.seen or (count>=q.goal and "ready:"+q.id not in p.seen))
		var ready=count>=q.goal
		return {"q":q,"count":count,"news":news,"ready":ready,"done":false,"rank":4 if ready else 3 if news else 2 if not taken else 1})
	ranked.sort_custom(func(a,b):return a.rank>b.rank)
	for q in finished:ranked.append({"q":q,"count":int(q.goal),"news":false,"ready":false,"done":true,"rank":0})
	for i in range(ranked.size()):
		var card=quest_message(ranked[i].q,ranked[i].count,ranked[i].news,ranked[i].ready,ranked[i].done);box.add_child(card)
		if ranked[i].done:card.modulate.a=.55
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
	var reward="%d ◈" % (int(q.alloy)+int(q.get("docs",0))*Game.DOC_ALLOY)
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
## Incoming order from Оперштаб: a message with the three difficulties as tiles in a row. The bubble and
## the row follow the feed width (anchors and an HBox), so a collapsed or wider menu never pushes them out.
const ORDER_TILE_HEIGHT=264.0
const DIFFICULTY_COLORS={"Лёгкий":Color("8fe895"),"Обычный":Color("f1cf55"),"Сложный":Color("ff8a6b")}
func telegram_offer_card(box:VBoxContainer):
	var p=Game.progression;var sender=Q.SENDERS.operations
	var height=92+ORDER_TILE_HEIGHT+(62 if manage else 40)
	var row=Control.new();row.name="TelegramOffer";box.add_child(row);row.custom_minimum_size=Vector2(0,height)
	var avatar=Panel.new();row.add_child(avatar);avatar.position=Vector2(0,4);avatar.size=Vector2(46,46);avatar.add_theme_stylebox_override("panel",UiKit.style(Color(sender.color),23))
	var glyph=UiKit.icon(avatar,sender.icon,Vector2(11,11),Vector2(24,24));glyph.texture=UiKit.interface_icon(sender.icon)
	var bubble=Panel.new();row.add_child(bubble);bubble.name="Bubble"
	bubble.anchor_right=1.0;bubble.anchor_bottom=1.0;bubble.offset_left=56;bubble.offset_right=-14
	var style=UiKit.style(Color("eee4bf"),12);style.corner_radius_top_left=3;bubble.add_theme_stylebox_override("panel",style)
	var header=VBoxContainer.new();bubble.add_child(header);header.anchor_right=1.0;header.offset_left=16;header.offset_right=-16;header.offset_top=10;header.add_theme_constant_override("separation",2);header.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for line in [[sender.name+" · телеграмма",13,Color(sender.color).darkened(.25)],["Новый приказ",19,UiKit.INK],["Выбери сложность или откажись",15,UiKit.MUTED]]:
		var label=Label.new();header.add_child(label);Texts.set_text(label,line[0]);label.add_theme_font_override("font",UiKit.field_font());label.add_theme_font_size_override("font_size",line[1]);label.add_theme_color_override("font_color",UiKit.text_color(line[2]));label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var tiles=HBoxContainer.new();tiles.name="OrderTiles";bubble.add_child(tiles);tiles.anchor_right=1.0;tiles.offset_left=16;tiles.offset_right=-16;tiles.offset_top=92;tiles.offset_bottom=92+ORDER_TILE_HEIGHT;tiles.add_theme_constant_override("separation",12)
	for i in range(p.telegram_options.size()):tiles.add_child(order_tile(p.telegram_options[i],i))
	if manage:
		var refuse=UiKit.button(bubble,"Отказаться от телеграммы",Vector2.ZERO,Vector2(10,40),func():p.abandon_telegram();refresh());refuse.add_theme_font_size_override("font_size",16)
		refuse.anchor_top=1.0;refuse.anchor_bottom=1.0;refuse.anchor_right=1.0;refuse.offset_left=16;refuse.offset_right=-16;refuse.offset_top=-54;refuse.offset_bottom=-14
	else:
		var later=UiKit.label(bubble,"Принять или отказаться можно в хабе",Vector2.ZERO,Vector2(10,24),14,UiKit.MUTED)
		later.anchor_top=1.0;later.anchor_bottom=1.0;later.anchor_right=1.0;later.offset_left=16;later.offset_right=-16;later.offset_top=-34;later.offset_bottom=-10
	UiKit.arrive(row,0)
## One difficulty as a square tile: difficulty, goal icon, goal, terms, accept. Everything centred.
func order_tile(q:Dictionary,index:int)->Control:
	var p=Game.progression
	var tile=PanelContainer.new();tile.name="Order_%d" % index;tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tile.mouse_filter=Control.MOUSE_FILTER_PASS
	var look=UiKit.style(Color("2c352e"),10,Color(1,1,1,.08));look.set_content_margin_all(12);tile.add_theme_stylebox_override("panel",look)
	var column=VBoxContainer.new();tile.add_child(column);column.add_theme_constant_override("separation",6);column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var tone:Color=DIFFICULTY_COLORS.get(str(q.difficulty),UiKit.MUTED)
	column.add_child(centered_label(str(q.difficulty),14,tone))
	# Every goal icon sits on the same round badge, so enemy art, vehicles and line icons read as one set.
	var holder=Control.new();holder.custom_minimum_size=Vector2(0,72);holder.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.set_meta("nav_static",true);column.add_child(holder)
	var badge=Panel.new();holder.add_child(badge);badge.size=Vector2(72,72);badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var round=StyleBoxFlat.new();round.bg_color=Color(tone,.14);round.border_color=Color(tone,.45);round.set_border_width_all(1);round.set_corner_radius_all(36)
	badge.add_theme_stylebox_override("panel",round)
	var art=order_icon(str(q.get("event","")));badge.add_child(art)
	# Line icons are drawn edge to edge, artwork has its own margin: the line set gets a smaller box.
	var inset=18.0 if art.has_meta("line_icon") else 12.0;art.position=Vector2.ONE*inset;art.size=Vector2.ONE*(72-inset*2)
	holder.resized.connect(func():badge.position=Vector2((holder.size.x-72)*.5,0))
	var goal=centered_label(str(q.text),16,UiKit.INK);goal.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;goal.custom_minimum_size.y=48;goal.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;column.add_child(goal)
	var terms=UiKit.label(column,"%d вылазки · %d ◈" % [q.run_limit,q.alloy],Vector2.ZERO,Vector2(10,22),14,UiKit.MUTED);terms.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;terms.custom_minimum_size.y=22
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(spacer)
	if manage:
		var accept=UiKit.button(column,"Принять",Vector2.ZERO,Vector2(10,40),func():p.choose_telegram(index);refresh(),index==1);accept.custom_minimum_size.y=40;accept.add_theme_font_size_override("font_size",15);accept.name="Accept"
	return tile
func centered_label(text:String,font_size:int,color:Color)->Label:
	var label=Label.new();Texts.set_text(label,text);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",UiKit.field_font());label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",UiKit.text_color(color));label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return label
## Context icon of an order goal: the enemy to destroy, the vehicle to ride, a token, waves or explosives.
func order_icon(event:String)->Control:
	var picture=TextureRect.new();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var enemy={"infantry":"soldier","armor":"tank","drones":"drone"}.get(event,"")
	var art={"kills_buggy":"buggy","kills_apc":"apc","kills_tank":"tank","tokens":"token","barrel_kills":"dynamite"}.get(event,"")
	if enemy!="":
		var icons=preload("res://scripts/ui/enemy_type_icon.gd");var sheet=icons.atlas();var index=icons.index_for(enemy)
		var cell=Vector2(sheet.get_width()/4.0,sheet.get_height()/4.0)
		var region=AtlasTexture.new();region.atlas=sheet;region.region=Rect2(Vector2(index%4,int(index/4))*cell,cell);picture.texture=region
	elif art!="":picture.texture=UiKit.trimmed(UiKit.icon_texture(art))
	else:
		picture.texture=UiKit.interface_icon("repeat" if event=="waves" else "quests");picture.modulate=UiKit.INK;picture.set_meta("line_icon",true)
	return picture

func orders_page():
	quest_filter="operations";quest_page()
func messages_page():
	UiKit.label(content,"Лента",Vector2(UiKit.PAGE_PADDING,20),Vector2(720,28),UiKit.PAGE_TITLE_SIZE)
	for button in UiKit.tab_row(content,Vector2(22,68),content.size.x-44,[["important","Важные"],["technical","Технические"]],message_tab,func(key):message_tab=key;refresh()):button.add_theme_font_size_override("font_size",16)
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
	for button in UiKit.tab_row(content,Vector2(22,68),content.size.x-44,[["info","Об игре"],["changelog","Изменения"]],about_tab,func(key):about_tab=key;refresh()):
		button.add_theme_font_size_override("font_size",16);button.name="AboutTab_"+button.name.trim_prefix("Tab_")
	if about_tab=="changelog":changelog_page();return
	UiKit.label(content,"War Cats",Vector2(22,130),Vector2(720,54),36)
	var description=UiKit.label(content,"Тактический экшен с развитием между вылазками. Защищай штаб, захватывай технику и пробивайся к командиру.",Vector2(22,195),Vector2(690,90),20)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	UiKit.label(content,"Версия %s · Сборка %s\nВ разработке" % [ProjectSettings.get_setting("application/config/version","0.1"),ProjectSettings.get_setting("application/config/build","1")],Vector2(22,310),Vector2(700,65),18,UiKit.MUTED)
	UiKit.label(content,"Автор · Alexander Nikolaev\ntext@test.com",Vector2(22,420),Vector2(700,75),21)
# Changelog entries carry their own ru/en text, so the box is excluded from automatic translation.
# Version tabs on top; the selected release shows a summary line and compact sections.
var changelog_version=""
## Changelog as one vertical feed: a narrow rail of versions on the left jumps the feed to that release,
## the feed lists every release with its date, titled blocks and items. Nothing hides behind tabs.
func changelog_page():
	var notes=preload("res://scripts/ui/changelog.gd")
	var versions:Array=notes.versions()
	if versions.is_empty():UiKit.label(content,"—",Vector2(22,124),Vector2(300,30),16);return
	if changelog_version not in versions:changelog_version=versions[0]
	var rail_width=150.0;var top=124.0;var height=content.size.y-top-16
	var rail=scroller(Vector2(22,top),Vector2(rail_width,height));rail.name="ChangelogRail";rail.add_theme_constant_override("separation",4)
	var feed=scroller(Vector2(22+rail_width+16,top),Vector2(content.size.x-44-rail_width-16,height));feed.name="ChangelogBox";feed.set_meta("text_editor",true)
	feed.add_theme_constant_override("separation",6)
	var scroll:ScrollContainer=feed.get_parent();var anchors={}
	for version in versions:
		var chosen:Array=notes.for_version(version);var newest=""
		for entry in chosen:
			if str(entry.get("date",""))>newest:newest=str(entry.get("date",""))
		var name=("Альфа "+version) if version!="earlier" else "Ранее"
		var header=VBoxContainer.new();feed.add_child(header);header.add_theme_constant_override("separation",0);anchors[version]=header
		var title=Label.new();header.add_child(title);title.text=Texts.render(name);title.add_theme_font_size_override("font_size",22);title.add_theme_color_override("font_color",UiKit.ORANGE if version==versions[0] else UiKit.INK)
		var date=Label.new();header.add_child(date);date.text=notes.date_text(newest);date.add_theme_font_size_override("font_size",13);date.add_theme_color_override("font_color",UiKit.MUTED)
		for entry in chosen:
			var text:Dictionary=entry.get(Texts.language,entry.get("ru",{}))
			var heading=Label.new();feed.add_child(heading);heading.text=str(text.get("title",""));heading.add_theme_font_size_override("font_size",16);heading.add_theme_color_override("font_color",UiKit.INK);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			for item in text.get("items",[]):
				var row=HBoxContainer.new();feed.add_child(row);row.add_theme_constant_override("separation",10)
				var dot=Label.new();row.add_child(dot);dot.text="•";dot.add_theme_color_override("font_color",UiKit.ORANGE);dot.add_theme_font_size_override("font_size",14);dot.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
				var line=Label.new();row.add_child(line);line.text=str(item);line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;line.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_theme_font_size_override("font_size",14);line.add_theme_color_override("font_color",UiKit.INK)
		var gap=Control.new();gap.custom_minimum_size.y=18;feed.add_child(gap)
		var jump=UiKit.button(rail,name,Vector2.ZERO,Vector2(rail_width,36),func():changelog_version=version;scroll.scroll_vertical=int(anchors[version].position.y),version==changelog_version)
		jump.custom_minimum_size=Vector2(rail_width,36);jump.add_theme_font_size_override("font_size",14);jump.name="Version_"+version
	# Reopening keeps the release that was chosen last.
	(func():
		if is_instance_valid(scroll) and anchors.has(changelog_version):scroll.scroll_vertical=int(anchors[changelog_version].position.y)).call_deferred()
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
## Encyclopedia: picture-first and touch-friendly. A row of category chips, a grid of cards (big picture,
## title, one short line), and a reader for the full article. The old tree of sections is gone: on a phone it
## ate a third of the width.
func guide_page():
	var width=content.size.x
	if guide_open!="":guide_article(width);return
	UiKit.label(content,"Энциклопедия",Vector2(22,18),Vector2(220,36),24)
	var search=LineEdit.new();search.name="GuideSearch";content.add_child(search)
	var search_x=250.0;var search_w=width-search_x-22-(190 if Texts.dev_enabled() else 0)
	search.position=Vector2(search_x,16);search.size=Vector2(search_w,42);search.placeholder_text=Texts.localized("Поиск по статьям…");search.clear_button_enabled=true;Texts.set_text(search,guide_query);search.right_icon=UiKit.interface_icon("search")
	search.add_theme_font_size_override("font_size",17);search.add_theme_color_override("font_color",UiKit.INK)
	search.add_theme_stylebox_override("normal",UiKit.style(Color("1d2621"),8))
	search.add_theme_stylebox_override("focus",UiKit.style(Color("1d2621"),8,UiKit.ORANGE))
	search.text_changed.connect(func(value):guide_query=value;render_guide())
	if Texts.dev_enabled():
		UiKit.button(content,"Edit dev · "+("вкл" if dev_edit else "выкл"),Vector2(width-200,16),Vector2(178,42),func():dev_edit=not dev_edit;refresh()).add_theme_font_size_override("font_size",13)
	# Category chips: one horizontal, scrollable row with big tap targets.
	var chips_scroll=ScrollContainer.new();content.add_child(chips_scroll);chips_scroll.position=Vector2(22,70);chips_scroll.size=Vector2(width-44,48)
	chips_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;chips_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var chips=HBoxContainer.new();chips_scroll.add_child(chips);chips.add_theme_constant_override("separation",8)
	for category in GUIDE.categories():
		var chip=Button.new();chips.add_child(chip);Texts.set_text(chip,category);chip.custom_minimum_size=Vector2(0,40);chip.add_theme_font_size_override("font_size",15)
		var active=category==guide_category
		chip.add_theme_stylebox_override("normal",UiKit.style(Color("584a2c") if active else Color("2c352e"),20,UiKit.ORANGE if active else Color(1,1,1,.08)))
		chip.add_theme_stylebox_override("hover",UiKit.style(Color("3d4639"),20,UiKit.ORANGE if active else Color(1,1,1,.16)))
		for state in ["normal","hover","pressed"]:
			var box=chip.get_theme_stylebox(state).duplicate();box.content_margin_left=16;box.content_margin_right=16;chip.add_theme_stylebox_override(state,box)
		chip.add_theme_color_override("font_color",UiKit.INK if active else UiKit.MUTED)
		chip.pressed.connect(func():guide_category=category;guide_section="Все подразделы";refresh())
	if dev_edit:
		UiKit.button(content,"+ Статья",Vector2(width-142,128),Vector2(120,32),func():preload("res://scripts/ui/encyclopedia_editor.gd").open_new(self)).add_theme_font_size_override("font_size",14)
	var scroll=ScrollContainer.new();content.add_child(scroll);scroll.position=Vector2(22,128+(40 if dev_edit else 0));scroll.size=Vector2(width-44,content.size.y-scroll.position.y-14)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var grid=GridContainer.new();scroll.add_child(grid);grid.columns=3 if width>=700 else 2
	grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	guide_box=grid;render_guide()

## Short line under a card title: the term description, or the first sentence of the text.
func guide_teaser(entry:Dictionary)->String:
	var text=Texts.description(entry.term) if entry.term!="" else Texts.render(str(entry.text))
	text=text.split("\n")[0]
	var stop=text.find(". ");if stop>0:text=text.substr(0,stop+1)
	return text if text.length()<=58 else text.substr(0,56).rstrip(" ,.")+"…"

func render_guide():
	for child in guide_box.get_children():guide_box.remove_child(child);child.queue_free()
	var entries=GUIDE.search(guide_query,guide_category,guide_section)
	var columns:int=guide_box.columns;var card_w=(content.size.x-44-12*(columns-1)-14)/float(columns)
	if entries.is_empty():
		var empty=Label.new();guide_box.add_child(empty);Texts.set_text(empty,"Ничего не найдено. Попробуй другое слово или раздел «Все».");empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;empty.custom_minimum_size=Vector2(card_w*2,0)
	for entry in entries:
		var card=Button.new();guide_box.add_child(card);card.custom_minimum_size=Vector2(card_w,236);card.focus_mode=Control.FOCUS_ALL
		card.add_theme_stylebox_override("normal",UiKit.style(Color("2c352e"),10,Color(1,1,1,.06)))
		card.add_theme_stylebox_override("hover",UiKit.style(Color("343e36"),10,UiKit.ORANGE))
		card.add_theme_stylebox_override("pressed",UiKit.style(Color("3a4438"),10,UiKit.ORANGE))
		card.add_theme_stylebox_override("focus",UiKit.style(Color(0,0,0,0),10,UiKit.ORANGE))
		var id=str(entry.id);card.pressed.connect(func():guide_open=id;refresh())
		var picture=Panel.new();card.add_child(picture);picture.position=Vector2(8,8);picture.size=Vector2(card_w-16,146);picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
		picture.add_theme_stylebox_override("panel",UiKit.style(Color("1f2722"),8))
		guide_picture(picture,entry,Vector2(card_w-16,146))
		# A long title takes two lines and the teaser gives up one, so nothing is cut mid-word.
		var heading=UiKit.label(card,str(entry.title),Vector2(14,160),Vector2(card_w-28,26),16);heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var teaser=UiKit.label(card,guide_teaser(entry),Vector2(14,190),Vector2(card_w-28,40),13,UiKit.MUTED);teaser.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;teaser.max_lines_visible=2;teaser.mouse_filter=Control.MOUSE_FILTER_IGNORE;teaser.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		if heading.get_theme_font("font").get_string_size(heading.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x>card_w-28:
			heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;heading.size.y=42;heading.add_theme_constant_override("line_spacing",-2)
			teaser.position.y=206;teaser.size.y=22;teaser.max_lines_visible=1
	UiKit.reveal_list(guide_box)

func guide_picture(frame:Control,entry:Dictionary,area:Vector2):
	if entry.image!="" and ResourceLoader.exists(entry.image):
		var art=TextureRect.new();frame.add_child(art);art.texture=load(entry.image);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var pad=6.0 if "illustrations/" in entry.image else 18.0
		art.position=Vector2.ONE*pad;art.size=area-Vector2.ONE*pad*2;art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	else:
		# No picture of its own: a big icon of the topic instead of an empty frame.
		var topic={"Бой":"rifle","Враги":"tank","Окружение":"wall","Хаб":"repair","Развитие":"star","Ресурсы":"alloy","Основы":"vehicle","Справочник":"recipe"}.get(str(entry.category),"recipe")
		var mark=TextureRect.new();frame.add_child(mark);mark.texture=UiKit.icon_texture(topic);mark.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;mark.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var side=minf(area.y-24,area.x-24);mark.size=Vector2(side,side);mark.position=(area-mark.size)*.5;mark.mouse_filter=Control.MOUSE_FILTER_IGNORE

## Reader: big picture on top, then the title and the full text; back returns to the grid.
func guide_article(width:float):
	var entry={}
	for candidate in GUIDE.entries():
		if str(candidate.id)==guide_open:entry=candidate;break
	if entry.is_empty():guide_open="";guide_page();return
	var back=UiKit.button(content,"← Все статьи",Vector2(22,16),Vector2(170,42),func():guide_open="";refresh());back.add_theme_font_size_override("font_size",15)
	UiKit.label(content,str(entry.category)+" · "+str(entry.section),Vector2(206,26),Vector2(width-230,24),14,UiKit.MUTED)
	var scroll=ScrollContainer.new();content.add_child(scroll);scroll.position=Vector2(22,72);scroll.size=Vector2(width-44,content.size.y-86);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var column=VBoxContainer.new();scroll.add_child(column);column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",14)
	var picture=Panel.new();column.add_child(picture);picture.custom_minimum_size=Vector2(width-58,270);picture.add_theme_stylebox_override("panel",UiKit.style(Color("1f2722"),10))
	guide_picture(picture,entry,Vector2(width-58,270))
	var heading=Label.new();column.add_child(heading);Texts.set_text(heading,entry.title);heading.add_theme_font_size_override("font_size",26);heading.add_theme_color_override("font_color",UiKit.INK);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if entry.term!="":
		var summary=Label.new();column.add_child(summary);Texts.set_text(summary,Texts.description(entry.term));summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;summary.add_theme_color_override("font_color",UiKit.ORANGE);summary.add_theme_font_size_override("font_size",17)
	var text=Label.new();column.add_child(text);Texts.set_text(text,entry.text);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.add_theme_font_size_override("font_size",18);text.add_theme_color_override("font_color",UiKit.INK)
	if dev_edit and not entry.get("auto",false):UiKit.button(column,"Редактировать",Vector2.ZERO,Vector2(0,36),func():preload("res://scripts/ui/encyclopedia_editor.gd").open(self,entry.id))

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
## Equipment and fighter news only make sense inside a run (a new card, a picked-up blueprint): in the hub the
## player changes them himself. A run keeps its own "viewed" mark, so returning to the hub never lights them (T-033).
func viewed_key(key:String)->String:return key+"@run" if key in ["inventory","fighter"] and is_instance_valid(arena) else key
func section_new(key:String)->bool:
	if key=="notifications":return Game.notifications.unread()>0
	if key in ["inventory","fighter"] and not is_instance_valid(arena):return false
	var value=signature(key)
	return value!="" and str(Game.progression.viewed_updates.get(viewed_key(key),""))!=value
func mark_section(key:String):
	Game.progression.view_section(key)
	Game.progression.viewed_updates[viewed_key(key)]=signature(key);Game.save_progress()

func expand_layout(parent:Node,factor:float):
	for child in parent.get_children():
		if not child is Control:continue
		if not parent is Container:
			child.position.x*=factor
			if not child is TextureRect:child.size.x*=factor
		if child.custom_minimum_size.x>0:child.custom_minimum_size.x*=factor
		expand_layout(child,factor)

func scroll_key()->String:
	return tab+":"+str([guide_query,guide_category,guide_section,guide_open]) if tab=="guide" else tab+":"+quest_filter if tab=="quests" else tab+":"+message_tab if tab=="notifications" else tab+":"+music_folder if tab=="music" else tab
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
	var fit=minf((available.x-24)/1060.0,(available.y-24)/690.0)
	# Phones and tablets: grow to fill the screen (text stays readable); desktop keeps 1:1 at most.
	var factor=minf(fit,1.35) if InputScheme.touch() else minf(1.0,fit)
	panel.scale=Vector2.ONE*factor;panel.position=(available-panel.size*factor)*.5
