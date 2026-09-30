extends Control
## One template for every hub station: tabs on the left, a grid of item cards in the middle and a detail panel
## on the right with before → after rows, the price and the actions. A provider object supplies the data:
##   title()->String, subtitle()->String, tabs()->Array of [key,title,icon],
##   items(tab)->Array of {id,title,icon,caption,state(locked|ready|owned|active|max),dot,group},
##     items with a "group" are laid out as titled rows (station trees: one row per branch),
##   detail(tab,id)->{title,icon,text,rows:[[name,before,after]],lines:[String],actions:[{id,text,enabled,primary}]},
##   act(tab,id,action)->String (message shown on success, "" when nothing happened).
signal closed
signal changed
var provider
var tab=""
var selected=""
var notice=""
var panel:Panel
var grid:GridContainer
var detail_box:Control
var animate_cards=true
## Hub station id (fighter, arsenal, hq, garage, wardrobe) for seen-aware «Новое» chips; empty elsewhere.
var station_kind=""
const STATE_COLORS={"locked":Color("3a3f39"),"ready":Color("584a2c"),"owned":Color("2f3b33"),"active":Color("3f5a3f"),"max":Color("2f3b33")}
## One status vocabulary for every station card and detail panel. Derived from the item state and the
## detail's purchase action (text with ◈ or док.), so stations only report state + actions.
##   status: [label, chip colour, card colour, border colour]
const STATUS={
	"locked":["Закрыто",Color("6c736b"),Color("30352f"),Color("3f463f")],
	"soon":["В разработке",Color("9d8fc4"),Color("2f2d38"),Color("4a4560")],
	"buy":["Можно купить",Color("f2a33a"),Color("4a3f28"),Color("c98a33")],
	"short":["Не хватает",Color("d0705c"),Color("36302c"),Color("5a4038")],
	"owned":["Куплено",Color("8fb59a"),Color("2f3b33"),Color("47524a")],
	"upgrade":["Можно улучшить",Color("f2a33a"),Color("33402f"),Color("c98a33")],
	"upgrade_short":["Не хватает",Color("d0705c"),Color("2f3b33"),Color("5a4038")],
	"active":["Выбрано",Color("7fe08a"),Color("34503a"),Color("6fbf78")],
	"max":["Максимум",Color("e8c96a"),Color("3a3a2c"),Color("8a7a45")],
	"new":["Новое",Color("ff8a6b"),Color("2f3b33"),Color("47524a")],
}
func status(item:Dictionary)->String:
	if item.has("status"):return str(item.status)
	var state=str(item.get("state","owned"))
	var id=str(item.id)
	if item.get("soon",false) or str(item.get("group",""))=="В разработке" or id=="soon" or id.begins_with("concept") or str(item.get("caption",""))=="Скоро":return "soon"
	if state=="max":return "max"
	if state=="active":return "active"
	var purchase=purchase_action(id)
	# A disabled purchase is "not enough" only when the price really exceeds the wallet;
	# otherwise something else blocks it (a blueprint, a previous step) and the item is locked.
	var blocked=not purchase.is_empty() and not purchase.get("enabled",true)
	var poor=blocked and lacks_funds(str(purchase.get("text","")))
	# A missing blueprint or step outranks money: saving up for something you cannot buy is misleading.
	var caption=str(item.get("caption","")).to_lower()
	if state=="locked" and (caption.begins_with("нужен") or caption.begins_with("нужна") or caption.begins_with("открой") or caption.begins_with("после") or "чертёж" in caption):return "locked"
	if state=="locked":
		if purchase.is_empty() or (blocked and not poor):return "locked"
		return "short" if poor else "buy"
	if state=="ready":return "short" if poor else "buy"
	if not purchase.is_empty() and not (blocked and not poor):return "upgrade_short" if poor else "upgrade"
	return "owned"
func lacks_funds(text:String)->bool:
	var number=RegEx.new();number.compile("(\\d[\\d ]*)\\s*(◈|док\\.)")
	var found=number.search(text)
	if found==null:return false
	var price=int(found.get_string(1).replace(" ",""))
	return price>(Game.credits if found.get_string(2)=="◈" else Game.cores)
func purchase_action(id:String)->Dictionary:
	var info:Dictionary=provider.detail(tab,id)
	for action in info.get("actions",[]):
		var text=str(action.get("text",""))
		if "◈" in text or "док." in text:return action
	return {}
func status_chip(parent:Control,kind:String,pos:Vector2)->Control:
	var spec:Array=STATUS.get(kind,STATUS.owned)
	var chip=PanelContainer.new();chip.name="Status";parent.add_child(chip);chip.position=pos;chip.mouse_filter=Control.MOUSE_FILTER_PASS
	chip.tooltip_text=Texts.localized({"locked":"Нужен чертёж или предыдущий шаг","soon":"Появится в следующих обновлениях","buy":"Хватает ресурсов — можно купить","short":"Не хватает ресурсов","owned":"Уже есть","upgrade":"Можно улучшить сейчас","upgrade_short":"На улучшение пока не хватает","active":"Используется сейчас","max":"Прокачано до предела","new":"Открыто недавно"}.get(kind,""))
	var box=UiKit.style(Color(spec[1],.16),5,Color(spec[1],.5));box.content_margin_left=6;box.content_margin_right=6;box.content_margin_top=1;box.content_margin_bottom=1
	chip.add_theme_stylebox_override("panel",box)
	var label=Label.new();chip.add_child(label);Texts.set_text(label,spec[0]);label.add_theme_font_size_override("font_size",11);label.add_theme_color_override("font_color",spec[1].lightened(.15))
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return chip
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_to_group("selection_scope")
	var tabs=provider.tabs()
	if tab=="" and not tabs.is_empty():tab=tabs[0][0]
	get_viewport().size_changed.connect(fit)
	build()
func _unhandled_input(event):
	if event.is_action_pressed("pause"):get_viewport().set_input_as_handled();closed.emit()
func fit():
	if not is_instance_valid(panel):return
	var available=get_viewport_rect().size
	var factor=minf(1.0,minf((available.x-24)/panel.size.x,(available.y-24)/panel.size.y))
	panel.scale=Vector2.ONE*factor;panel.position=(available-panel.size*factor)*.5
func build():
	for child in get_children():child.queue_free()
	var shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.42)
	panel=UiKit.glass(self,Vector2.ZERO,Vector2(1120,650),Color("242d27"));panel.name="StationPanel";fit()
	UiKit.label(panel,provider.title(),Vector2(28,16),Vector2(600,40),28)
	UiKit.label(panel,provider.subtitle(),Vector2(28,54),Vector2(700,24),15,UiKit.MUTED)
	var alloy=UiKit.label(panel,"%d ◈" % Game.credits,Vector2(760,22),Vector2(150,30),18);alloy.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;alloy.name="Alloy"
	var docs=UiKit.label(panel,"%d док." % Game.cores,Vector2(920,22),Vector2(110,30),18);docs.name="Documents"
	var close=UiKit.button(panel,"",Vector2(1046,16),Vector2(52,44),func():closed.emit());close.icon=UiKit.interface_icon("close");close.expand_icon=true;close.add_theme_constant_override("icon_max_width",20);close.name="Close"
	var tabs=provider.tabs()
	for i in range(tabs.size()):
		var key=tabs[i][0]
		var b=UiKit.button(panel,tabs[i][1],Vector2(22,96+i*54),Vector2(190,46),func():tab=key;selected="";notice="";animate_cards=true;build(),key==tab);b.name="Tab_"+key
		b.icon=UiKit.icon_texture(tabs[i][2]) if tabs[i].size()>2 else null;b.expand_icon=true;b.add_theme_constant_override("icon_max_width",22);b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.add_theme_font_size_override("font_size",16)
	var scroll=ScrollContainer.new();panel.add_child(scroll);scroll.position=Vector2(232,96);scroll.size=Vector2(530,532);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var items=provider.items(tab)
	if selected=="" and not items.is_empty():selected=items[0].id
	var grouped=items.any(func(item):return item.has("group"))
	var column=VBoxContainer.new();column.name="Items";scroll.add_child(column);column.add_theme_constant_override("separation",8)
	var current_group=null;grid=null
	for item in items:
		if grouped and item.get("group")!=current_group:
			current_group=item.get("group")
			var header=UiKit.label(column,str(current_group),Vector2.ZERO,Vector2(510,24),15,UiKit.MUTED);header.custom_minimum_size=Vector2(510,24);header.clip_text=false
			grid=null
		if grid==null:
			grid=GridContainer.new();column.add_child(grid);grid.columns=3;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10)
		card(item)
	if animate_cards:
		for child in column.get_children():
			if child is GridContainer:UiKit.reveal_list(child)
		animate_cards=false
	detail_box=UiKit.panel(panel,Vector2(778,96),Vector2(320,532),Color("2c352e"));detail_box.name="Detail"
	render_detail()
func card(item:Dictionary):
	var b=Button.new();grid.add_child(b);b.name="Item_"+str(item.id);b.custom_minimum_size=Vector2(166,150);b.focus_mode=Control.FOCUS_NONE
	var state=str(item.get("state","owned"))
	var kind=status(item);var spec:Array=STATUS[kind]
	var style=UiKit.style(spec[2],10,UiKit.ORANGE if item.id==selected else spec[3])
	style.set_border_width_all(3 if item.id==selected else 1)
	for key in ["normal","hover","pressed","focus"]:b.add_theme_stylebox_override(key,style)
	b.pressed.connect(func():
		selected=item.id;notice=""
		if station_kind!="":preload("res://scripts/ui/station_notices.gd").mark_item_seen(station_kind,tab,str(item.id))
		build())
	UiKit.press_bounce(b)
	var picture=UiKit.icon(b,str(item.get("icon",item.id)),Vector2(58,24),Vector2(50,50))
	if item.has("texture"):picture.texture=item.texture
	UiKit.locked_preview(picture,kind in ["locked","soon"])
	if kind in ["soon","locked"]:picture.modulate.a=.55 if kind=="soon" else .8
	status_chip(b,kind,Vector2(6,6))
	if station_kind!="" and kind not in ["locked","soon"] and preload("res://scripts/ui/station_notices.gd").is_new(station_kind,tab,str(item.id)):
		var fresh=status_chip(b,"new",Vector2(0,6));fresh.name="New"
		fresh.position.x=b.custom_minimum_size.x-fresh.get_combined_minimum_size().x-6
	var title=UiKit.label(b,str(item.title),Vector2(8,76),Vector2(150,26),15);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.clip_text=true
	var caption=UiKit.label(b,str(item.get("caption","")),Vector2(8,102),Vector2(150,40),13,UiKit.MUTED);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if item.get("dot",false):UiKit.badge(b,str(item.get("dot_kind","news")))
func render_detail():
	for child in detail_box.get_children():child.queue_free()
	if selected=="":return
	var info:Dictionary=provider.detail(tab,selected)
	var content=Control.new();detail_box.add_child(content);content.size=detail_box.size
	var picture=UiKit.icon(content,str(info.get("icon",selected)),Vector2(16,16),Vector2(72,72))
	if info.has("texture"):picture.texture=info.texture
	var heading=UiKit.label(content,str(info.get("title","")),Vector2(100,18),Vector2(206,64),21);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var current=provider.items(tab).filter(func(i):return str(i.id)==selected)
	if not current.is_empty():status_chip(content,status(current[0]),Vector2(16,96))
	var y=126.0
	if str(info.get("text",""))!="":
		var text=UiKit.label(content,str(info.text),Vector2(16,y),Vector2(288,96),15,UiKit.MUTED);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;y+=104
	for row in info.get("rows",[]):
		UiKit.label(content,str(row[0]),Vector2(16,y),Vector2(150,24),15)
		var value="%s → %s" % [str(row[1]),str(row[2])] if str(row[1])!=str(row[2]) else str(row[1])
		var cell=UiKit.label(content,value,Vector2(160,y),Vector2(144,24),15,UiKit.ORANGE if str(row[1])!=str(row[2]) else UiKit.INK);cell.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		y+=28
	for line in info.get("lines",[]):
		var l=UiKit.label(content,str(line),Vector2(16,y),Vector2(288,24),14,UiKit.MUTED);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;y+=26
	var actions:Array=info.get("actions",[])
	var bottom=detail_box.size.y-16-(34 if notice!="" else 0)
	for i in range(actions.size()-1,-1,-1):
		var action=actions[i];bottom-=48
		var b=UiKit.button(content,str(action.text),Vector2(16,bottom),Vector2(288,44),func():perform(str(action.id)),action.get("primary",false) and action.get("enabled",true))
		b.name="Action_"+str(action.id);b.disabled=not action.get("enabled",true);b.add_theme_font_size_override("font_size",16);UiKit.muted_locked_button(b)
		bottom-=4
	if notice!="":UiKit.label(content,notice,Vector2(16,detail_box.size.y-44),Vector2(288,28),15,Color("8fe895")).name="Notice"
	UiKit.reveal(content,0,Vector2(18,0),.22)
func perform(action:String):
	var message=str(provider.act(tab,selected,action))
	if message=="":return
	Game.sound("upgrade",self);notice=message;changed.emit();build()
