extends Control
## One template for every hub station: tabs on the left (or on top, provider.tabs_on_top(), T-220), a grid of item cards in the middle and a detail panel
## on the right with before → after rows, the price and the actions. A provider object supplies the data:
##   title()->String, subtitle()->String, tabs()->Array of [key,title,icon],
##   items(tab)->Array of {id,title,icon,caption,state(locked|ready|owned|active|max),dot,group},
##     items with a "group" are laid out as titled rows (station trees: one row per branch),
##   detail(tab,id)->{title,icon,text,rows:[[name,before,after]],lines:[String],actions:[{id,text,enabled,primary}]},
##   act(tab,id,action)->String (message shown on success, "" when nothing happened).
##   Optional: tabs_on_top()->bool, page_for(tab)->Control (a page drawn instead of cards + detail), tab_dot(tab).
## Hub stations (card_mode) draw no detail panel: each item is a card scene (scenes/ui/components/station_card.tscn)
## with its main action and level bar (item.level / item.cap); «i» opens the full detail with every action in a popup.
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
## Item shown in the «i» popup ("" when closed); the popup is rebuilt with the screen, so it survives a purchase.
var info_id=""
var info_popup:Control
var scroll_memory={}
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
	"done":["Готово",Color("8fb59a"),Color("2f3b33"),Color("47524a")],
	"goal":["Следующая цель",Color("f2a33a"),Color("4a3f28"),Color("c98a33")],
	"later":["Позже",Color("6c736b"),Color("30352f"),Color("3f463f")],
}
## Something on tab `key` can be bought or upgraded right now (status() reads the current tab, so it is swapped).
func affordable_in(key:String)->bool:
	var saved=tab;tab=key
	var found=provider.items(key).any(func(item):return status(item) in ["buy","upgrade"])
	tab=saved;return found
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
	chip.tooltip_text=Texts.localized(STATUS_TIPS.get(kind,""))
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
	if not event.is_action_pressed("pause"):return
	get_viewport().set_input_as_handled()
	# Esc closes the «i» popup first, the station on the next press.
	if info_id!="":close_info()
	else:closed.emit()
## Q / E walk the horizontal tabs (T-178), taken before the GUI so E does not press the focused button.
func _input(event):
	if get_tree().get_nodes_in_group("selection_scope").back()!=self and not is_ancestor_of(get_tree().get_nodes_in_group("selection_scope").back()):return
	if info_id!="":return  # tabs stay put under the «i» popup
	var step=UiKit.tab_step(event)
	if step!=0 and UiKit.cycle_h_tabs(self,step):get_viewport().set_input_as_handled()
func fit():
	if not is_instance_valid(panel):return
	var available=get_viewport_rect().size
	var factor=minf(1.0,minf((available.x-24)/panel.size.x,(available.y-24)/panel.size.y))
	panel.scale=Vector2.ONE*factor;panel.position=(available-panel.size*factor)*.5
func build():
	# Card stations keep their scroll position across a purchase (the screen is rebuilt).
	if is_instance_valid(panel):
		var cards=panel.get_node_or_null("Cards")
		if cards:scroll_memory[tab]=cards.scroll_vertical
	for child in get_children():child.queue_free()
	var shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.42)
	panel=UiKit.glass(self,Vector2.ZERO,Vector2(1120,650),Color("242d27"));panel.name="StationPanel";fit()
	UiKit.accent(UiKit.label(panel,provider.title(),Vector2(28,16),Vector2(600,40),28))
	UiKit.label(panel,provider.subtitle(),Vector2(28,54),Vector2(700,24),15,UiKit.MUTED)
	# The global currency strip at the top already shows alloy; the station window keeps no second counter (T-030).
	var close=UiKit.button(panel,"",Vector2(1046,16),Vector2(52,44),func():closed.emit());close.icon=UiKit.interface_icon("close");close.expand_icon=true;close.add_theme_constant_override("icon_max_width",20);close.name="Close"
	# The item shown in the detail panel counts as viewed before the dots are drawn (T-179): its «Новое» and,
	# with the last one, the tab dot go out at once.
	if selected=="" and not provider.has_method("page_for") and not card_mode():
		var first_items=provider.items(tab)
		if not first_items.is_empty():selected=str(first_items[0].id)
	if selected!="" and station_kind not in ["","roadmap"]:preload("res://scripts/ui/station_notices.gd").mark_item_seen(station_kind,tab,str(selected))
	var tabs=provider.tabs()
	# Content area: right of the tab column, or under the tab row when the station puts its tabs on top (Barracks, T-220).
	var top=provider.has_method("tabs_on_top") and provider.tabs_on_top()
	var area=Rect2(22,146,1076,484) if top else Rect2(232,96,866,532)
	var tab_buttons=[]
	for i in range(tabs.size()):
		var key=tabs[i][0]
		var tab_w=(area.size.x-(tabs.size()-1)*8.0)/tabs.size() if top else 190.0
		var b=UiKit.button(panel,tabs[i][1],Vector2(22+i*(tab_w+8),88) if top else Vector2(22,96+i*54),Vector2(tab_w,46),func():tab=key;selected="";notice="";info_id="";animate_cards=true;build(),key==tab);b.name="Tab_"+key
		tab_buttons.append(b)
		b.icon=tab_icon(str(tabs[i][2])) if tabs[i].size()>2 else null;
		for state in ["normal","hover","pressed","disabled"]:
			var tight=b.get_theme_stylebox(state).duplicate();tight.content_margin_left=14;tight.content_margin_right=10;b.add_theme_stylebox_override(state,tight)
		b.expand_icon=true;b.add_theme_constant_override("icon_max_width",22);b.add_theme_constant_override("h_separation",10);b.alignment=HORIZONTAL_ALIGNMENT_CENTER if top else HORIZONTAL_ALIGNMENT_LEFT;b.add_theme_font_size_override("font_size",16)
		# T-052: a tab with something affordable right now carries a «ready» dot, as everywhere else.
		# One rule (0.8.0): a station tab is lit while any of its items is new; plain screens keep «affordable».
		var lit=provider.tab_dot(key) if provider.has_method("tab_dot") else preload("res://scripts/ui/station_notices.gd").tab_new(station_kind,key) if station_kind not in ["","roadmap"] else affordable_in(key)
		if key!=tab and lit:UiKit.badge(b,"ready",0,"trailing")
		# One size for every tab (T-198): a long name keeps the font and fades out before the dot.
		for inline in b.get_children():if inline.has_method("fit"):b.remove_child(inline);inline.queue_free()
		UiKit.fade_text(b,tabs[i][1],26.0 if key!=tab and lit else 0.0)
	# Tabs on top are horizontal tabs: Q / E walk them (T-178).
	if top:UiKit.mark_h_tabs(tab_buttons,tabs.map(func(t):return t[0]).find(tab))
	# A tab can draw its own page instead of cards + detail (Barracks → «Классы», 0.8.0).
	if provider.has_method("page_for"):
		var page=provider.page_for(tab)
		if page:
			page.name="Page";panel.add_child(page);page.position=area.position;page.setup(self,area.size)
			return  # the page shows its own feedback (the notice line overlapped the class bio)
	if card_mode():
		info_cards(area)
		return
	var detail_w=320.0;var list_w=area.size.x-detail_w-16
	var scroll=ScrollContainer.new();panel.add_child(scroll);scroll.position=area.position;scroll.size=Vector2(list_w,area.size.y);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var items=provider.items(tab)
	if selected=="" and not items.is_empty():selected=items[0].id

	var grouped=items.any(func(item):return item.has("group"))
	var column=VBoxContainer.new();column.name="Items";scroll.add_child(column);column.add_theme_constant_override("separation",8)
	var current_group=null;grid=null
	# The roadmap is a path (T-124): vertical milestones on one line instead of a grid.
	if provider.has_method("path_layout") and provider.path_layout():
		milestones(column,items)
		items=[]
	for item in items:
		if grouped and item.get("group")!=current_group:
			current_group=item.get("group")
			var header=UiKit.label(column,str(current_group),Vector2.ZERO,Vector2(list_w-20,24),15,UiKit.MUTED);header.custom_minimum_size=Vector2(list_w-20,24);header.clip_text=false
			grid=null
		if grid==null:
			grid=GridContainer.new();column.add_child(grid);grid.columns=maxi(3,int((list_w-20+10)/176.0));grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10)
		card(item)
	if animate_cards:
		for child in column.get_children():
			if child is GridContainer:UiKit.reveal_list(child)
		animate_cards=false
	detail_box=UiKit.panel(panel,Vector2(area.end.x-detail_w,area.position.y),Vector2(detail_w,area.size.y),Color("2c352e"));detail_box.name="Detail"
	render_detail()
## Vertical milestones (T-191, the same quiet look as the class path): a thin track through big numbered
## circles — done green, the next goal with an orange ring, later hollow — and an airy card per step.
## A tap selects the step for the detail panel.
func milestones(column:VBoxContainer,items:Array):
	const ROW=104.0;const NODE=46.0;const X=8.0;const GAP=14.0
	var holder=Control.new();holder.name="Path";column.add_child(holder);holder.custom_minimum_size=Vector2(510,ROW*items.size()+8)
	var axis=X+NODE*.5;var card_h=ROW-GAP;var mid=func(i:int)->float:return i*ROW+card_h*.5
	if items.size()>1:
		var rail=Panel.new();holder.add_child(rail);rail.mouse_filter=Control.MOUSE_FILTER_IGNORE;rail.position=Vector2(axis-3,mid.call(0));rail.size=Vector2(6,mid.call(items.size()-1)-mid.call(0))
		rail.add_theme_stylebox_override("panel",bar_style(Color(1,1,1,.08),3))
		var last=-1
		for i in range(items.size()):
			if str(items[i].get("status",""))=="done":last=i
		if last>0:
			var fill=Panel.new();holder.add_child(fill);fill.mouse_filter=Control.MOUSE_FILTER_IGNORE;fill.position=Vector2(axis-3,mid.call(0));fill.size=Vector2(6,mid.call(last)-mid.call(0))
			fill.add_theme_stylebox_override("panel",bar_style(Color("8fe895"),3))
	var left=X+NODE+20
	for i in range(items.size()):
		var item=items[i];var status=str(item.get("status","later"));var y=i*ROW
		var row=Button.new();holder.add_child(row);row.name="Item_"+str(item.id);row.position=Vector2(left,y);row.size=Vector2(510-left-14,card_h);row.focus_mode=Control.FOCUS_NONE
		var chosen=str(item.id)==selected
		var bg=Color(UiKit.ORANGE,.16) if status=="goal" else Color(1,1,1,.05) if status=="done" else Color(0,0,0,.14)
		var style=UiKit.style(bg,14,UiKit.ORANGE if chosen else Color(1,1,1,.07));style.set_border_width_all(2 if chosen else 1)
		for state in ["normal","hover","pressed","focus"]:row.add_theme_stylebox_override(state,style)
		var id=str(item.id)
		row.pressed.connect(func():selected=id;notice="";build())
		var node=preload("res://scripts/ui/track_node.gd").new();node.status=status;node.milestone=true;node.number=str(i+1);node.size=Vector2(NODE,NODE);node.position=Vector2(axis-NODE*.5,mid.call(i)-NODE*.5);node.name="Node_"+id
		if status=="goal":node.progress=float(item.get("progress",0.0))
		holder.add_child(node)
		if id==str(get_meta("just_claimed","")):node.celebrate.call_deferred()
		var pic=card_h-28
		var art=TextureRect.new();row.add_child(art);art.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.position=Vector2(14,14);art.size=Vector2(pic,pic)
		art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture=item.get("texture",UiKit.icon_texture(str(item.get("icon",""))))
		if status=="later":
			var grey=ShaderMaterial.new();grey.shader=GREY;art.material=grey;art.self_modulate=Color(.8,.8,.8,.55);art.set_meta("kit_layer",true)
		var reward=int(item.get("reward",0));var right=112.0 if reward>0 else 14.0
		var text_x=14+pic+16;var text_w=row.size.x-text_x-right
		var title=UiKit.label(row,str(item.title),Vector2(text_x,card_h*.5-26),Vector2(text_w,26),18,UiKit.INK if status!="later" else Color(UiKit.INK,.62));title.clip_text=true
		UiKit.label(row,str(item.get("caption","")),Vector2(text_x,card_h*.5+2),Vector2(text_w,22),13,Color("8fe895") if status=="done" else UiKit.ORANGE if status=="goal" else Color(UiKit.MUTED,.85)).clip_text=true
		# The reward: a pill with the coin; a reached, unclaimed one becomes a «+N» button right in the row.
		if reward>0:
			if status=="done" and item.get("claimable",false):
				var claim=UiKit.button(row,"+%d" % reward,Vector2(row.size.x-104,card_h*.5-20),Vector2(92,40),func():selected=id;perform("claim");set_meta("just_claimed",id),true);claim.name="Claim_"+id
				claim.icon=UiKit.icon_texture("alloy");claim.expand_icon=true;claim.add_theme_constant_override("icon_max_width",20);claim.tooltip_text=Texts.render("Забрать награду")
				if UiKit.motion_enabled():
					claim.pivot_offset=claim.size*.5;var t=claim.create_tween().set_loops();t.tween_property(claim,"scale",Vector2.ONE*1.06,.5);t.tween_property(claim,"scale",Vector2.ONE,.5)
			else:
				var pill=UiKit.panel(row,Vector2(row.size.x-104,card_h*.5-16),Vector2(92,32),Color(1,1,1,.06) if status!="goal" else Color(UiKit.ORANGE,.24))
				var amount=UiKit.label(pill,("" if status=="done" else "+")+str(reward),Vector2(6,4),Vector2(56,24),15,Color("8fe895") if status=="done" else UiKit.INK if status=="goal" else UiKit.MUTED);amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
				UiKit.icon(pill,"alloy",Vector2(66,6),Vector2(20,20)).modulate=Color(1,1,1,1.0 if status!="later" else .5)
static var GREY:Shader:
	get:
		if _grey==null:
			_grey=Shader.new();_grey.code="shader_type canvas_item;\nvoid fragment(){vec4 c=texture(TEXTURE,UV);float l=dot(c.rgb,vec3(.299,.587,.114));COLOR=vec4(vec3(l),c.a)*COLOR;}"
		return _grey
static var _grey:Shader
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
	# The roadmap shows progress, not unlocks: no «Новое» badges there.
	if station_kind not in ["","roadmap"] and kind not in ["locked","soon","done","goal","later"] and preload("res://scripts/ui/station_notices.gd").item_new(station_kind,tab+":"+str(item.id),kind):
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
	var heading=UiKit.label(content,str(info.get("title","")),Vector2(100,18),Vector2(206,64),20);UiKit.accent(heading);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var current=provider.items(tab).filter(func(i):return str(i.id)==selected)
	if not current.is_empty():status_chip(content,status(current[0]),Vector2(16,96))
	var actions:Array=info.get("actions",[])
	var bottom=detail_box.size.y-16-(34 if notice!="" else 0)
	# Text, rows and lines scroll in the space above the buttons: long cards overlapped them (T-098 shot).
	var area_top=126.0;var area_bottom=bottom-actions.size()*52-6
	var scroll=ScrollContainer.new();scroll.name="DetailScroll";content.add_child(scroll);scroll.position=Vector2(0,area_top);scroll.size=Vector2(content.size.x,maxf(40,area_bottom-area_top))
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var body=Control.new();scroll.add_child(body);body.custom_minimum_size=Vector2(content.size.x-12,0)
	var y=0.0
	if str(info.get("text",""))!="":
		var text=UiKit.label(body,str(info.text),Vector2(16,y),Vector2(288,96),15,UiKit.MUTED);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		# Height follows the text: a fixed 96 px left a hole under short descriptions and hid the lines below.
		text.size.y=wrapped_height(text,288,15);y+=text.size.y+10
	if not info.get("rows",[]).is_empty():
		var table=rows_table(info.rows,15);body.add_child(table);table.position=Vector2(16,y);table.size.x=288
		y+=info.rows.size()*28+4
	for line in info.get("lines",[]):
		var l=UiKit.label(body,str(line),Vector2(16,y),Vector2(288,24),14,UiKit.MUTED);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.size.y=maxf(24,wrapped_height(l,288,14));y+=l.size.y+2
	body.custom_minimum_size.y=y
	for i in range(actions.size()-1,-1,-1):
		var action=actions[i];bottom-=48
		var b=UiKit.button(content,str(action.text),Vector2(16,bottom),Vector2(288,44),func():perform(str(action.id)),action.get("primary",false) and action.get("enabled",true))
		b.name="Action_"+str(action.id);b.disabled=not action.get("enabled",true);b.add_theme_font_size_override("font_size",16);UiKit.muted_locked_button(b)
		bottom-=4
	if notice!="":UiKit.label(content,notice,Vector2(16,detail_box.size.y-44),Vector2(288,28),15,Color("8fe895")).name="Notice"
	UiKit.reveal(content,0,Vector2(18,0),.22)
## «Было → станет» as a table (T-254): name · before · → · after, the numbers in aligned columns.
static func rows_table(rows:Array,font_size:int)->GridContainer:
	var grid=GridContainer.new();grid.columns=4;grid.mouse_filter=Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",4)
	for spec in [[UiKit.INK,HORIZONTAL_ALIGNMENT_LEFT],[UiKit.MUTED,HORIZONTAL_ALIGNMENT_RIGHT],[UiKit.MUTED,HORIZONTAL_ALIGNMENT_CENTER],[UiKit.ORANGE,HORIZONTAL_ALIGNMENT_LEFT]]:
		var cell=Label.new();grid.add_child(cell);cell.add_theme_font_override("font",UiKit.field_font());cell.add_theme_font_size_override("font_size",font_size)
		cell.add_theme_color_override("font_color",spec[0]);cell.horizontal_alignment=spec[1];cell.mouse_filter=Control.MOUSE_FILTER_IGNORE
	grid.get_child(0).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	CARD_SCRIPT.fill_rows(grid,rows,UiKit.INK)
	return grid
## Height of a wrapped label at its width (measured from the font: get_line_count() is 1 before layout).
static func wrapped_height(label:Label,width:float,font_size:int)->float:
	label.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING;label.max_lines_visible=-1
	var font=label.get_theme_font("font");var text=Texts.render(label.text)
	return ceilf(font.get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,width-4,font_size).y)+6
func perform(action:String):
	var before=Game.credits;var origin=ResourceStrip.reward_origin(get_viewport())
	var message=str(provider.act(tab,selected,action))
	# Alloy paid out here (roadmap rewards) flies into the resource strip (T-207).
	if Game.credits>before:ResourceStrip.fly_reward("alloy",origin,Game.credits-before)
	if message=="":return
	Game.sound("upgrade",self);notice=message;changed.emit();build()
## Tab icons come from the line set (Straight) whenever it has one, so tabs share size and weight;
## full-colour artwork stays a fallback, trimmed to its visible pixels.
const TAB_LINE_ICONS={"repair":"build","heart":"medkit","health":"add"}
static func tab_icon(id:String)->Texture2D:
	var line=TAB_LINE_ICONS.get(id,id)
	if ResourceLoader.exists("res://assets/icons/interface_straight/"+line+".svg"):return UiKit.interface_icon(line)
	return UiKit.trimmed(UiKit.icon_texture(id))
## Exact-colour rounded bar (UiKit.style maps light colours to theme surfaces, which turned the green fill dark).
static func bar_style(color:Color,radius:int)->StyleBoxFlat:
	var b=StyleBoxFlat.new();b.bg_color=color;b.set_corner_radius_all(radius);return b
## Hub stations (author, 0.8.x): medium cards that carry the gist, the main «было → станет» row and their own
## action; a small «i» opens the full card in a popup. No detail panel. The roadmap keeps its path, screens
## without a station id (test blueprint shop) keep cards + detail.
func card_mode()->bool:
	return station_kind in ["fighter","arsenal","hq","garage","wardrobe"] and not (provider.has_method("path_layout") and provider.path_layout())
const CARD_MIN_W=240.0
const CARD_GAP=12.0
func info_cards(area:Rect2):
	var scroll=ScrollContainer.new();scroll.name="Cards";panel.add_child(scroll);scroll.position=area.position;scroll.size=area.size
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var inner=area.size.x-14  # room for the scroll bar
	var items=provider.items(tab)
	var grouped=items.any(func(item):return item.has("group"))
	# Responsive grid (author): 2–4 columns from the width (cards at least CARD_MIN_W), never more columns than the
	# largest group has cards, and the cards stretch to fill the row — no empty strip on the right.
	var biggest={}
	for item in items:biggest[item.get("group","")]=int(biggest.get(item.get("group",""),0))+1
	var cols=maxi(2,mini(clampi(int((inner+CARD_GAP)/(CARD_MIN_W+CARD_GAP)),2,4),biggest.values().max() if not biggest.is_empty() else 2))
	var column=VBoxContainer.new();column.name="Items";scroll.add_child(column);column.add_theme_constant_override("separation",8);column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var current_group=null;grid=null
	for item in items:
		if grouped and item.get("group")!=current_group:
			current_group=item.get("group")
			var header=UiKit.label(column,str(current_group),Vector2.ZERO,Vector2(inner,24),15,UiKit.MUTED);header.custom_minimum_size=Vector2(inner,24)
			grid=null
		if grid==null:
			grid=GridContainer.new();column.add_child(grid);grid.columns=cols
			grid.add_theme_constant_override("h_separation",int(CARD_GAP));grid.add_theme_constant_override("v_separation",int(CARD_GAP))
		info_card(item).custom_minimum_size.x=floorf((inner-(cols-1)*CARD_GAP)/cols)  # equal columns
	if animate_cards:
		for child in column.get_children():
			if child is GridContainer:UiKit.reveal_list(child)
		animate_cards=false
	if scroll_memory.get(tab,0)>0:
		var keep=int(scroll_memory[tab])
		get_tree().process_frame.connect(func():if is_instance_valid(scroll):scroll.scroll_vertical=keep,CONNECT_ONE_SHOT)
	# Result of the last action: top right, beside the close button (the detail panel that showed it is gone).
	if notice!="":
		var line=UiKit.label(panel,notice,Vector2(560,26),Vector2(474,28),16,Color("8fe895"));line.name="Notice";line.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	if info_id!="":show_info()
const CARD_SCENE=preload("res://scenes/ui/components/station_card.tscn")
const CARD_SCRIPT=preload("res://scripts/ui/components/station_card.gd")
const STATUS_TIPS={"locked":"Нужен чертёж или предыдущий шаг","soon":"Появится в следующих обновлениях","buy":"Хватает ресурсов — можно купить","short":"Не хватает ресурсов","owned":"Уже есть","upgrade":"Можно улучшить сейчас","upgrade_short":"На улучшение пока не хватает","active":"Используется сейчас","max":"Прокачано до предела","new":"Открыто недавно","done":"Цель достигнута","goal":"Ближайшая цель этого направления","later":"Откроется после следующей цели"}
## One card from the editable scene (scenes/ui/components/station_card.tscn); the screen only supplies data.
func info_card(item:Dictionary)->Control:
	var id=str(item.id);var info:Dictionary=provider.detail(tab,id)
	var kind=status(item);var spec:Array=STATUS[kind]
	var card=CARD_SCENE.instantiate();grid.add_child(card)
	var fresh=station_kind not in ["","roadmap"] and kind not in ["locked","soon","done","goal","later"] and preload("res://scripts/ui/station_notices.gd").item_new(station_kind,tab+":"+id,kind)
	var main=CARD_SCRIPT.main_action(info.get("actions",[]))
	card.setup(item,info,{"kind":kind,"label":spec[0],"chip":spec[1],"bg":spec[2],"border":spec[3],"tooltip":Texts.localized(STATUS_TIPS.get(kind,"")),
		"new_label":STATUS.new[0] if fresh else "","new_chip":STATUS.new[1],"short":not main.is_empty() and not main.get("enabled",true) and lacks_funds(str(main.get("text","")))})
	card.action_pressed.connect(func(action):act_on(id,action))
	card.info_pressed.connect(func():open_info(id))
	return card
func action_button(parent:Control,action:Dictionary,id:String,pos:Vector2,dims:Vector2)->Button:
	var enabled=action.get("enabled",true);var aid=str(action.id)
	var b=UiKit.button(parent,str(action.text),pos,dims,func():act_on(id,aid),action.get("primary",false) and enabled)
	b.name="Action_"+aid;b.disabled=not enabled;UiKit.muted_locked_button(b);b.clip_text=true
	# Not enough alloy / documents: the price in the disabled button turns red.
	if not enabled and lacks_funds(str(action.text)):b.add_theme_color_override("font_disabled_color",Color(STATUS.short[1],.9))
	return b
func act_on(id:String,action:String):
	selected=id
	if station_kind!="":preload("res://scripts/ui/station_notices.gd").mark_item_seen(station_kind,tab,id)
	perform(action)
func open_info(id:String):
	selected=id
	if station_kind!="":preload("res://scripts/ui/station_notices.gd").mark_item_seen(station_kind,tab,id)
	info_id=id;notice="";show_info()
func close_info():
	info_id=""
	if is_instance_valid(info_popup):info_popup.queue_free()
	build()  # the «Новое» chip of the viewed card goes out
## The full card: big picture, title, status, the whole description, every «было → станет» row and line, every action.
func show_info():
	if is_instance_valid(info_popup):info_popup.queue_free()
	var id=info_id
	var current=provider.items(tab).filter(func(i):return str(i.id)==id)
	if current.is_empty():info_id="";return
	var item:Dictionary=current[0];var kind=status(item);var info:Dictionary=provider.detail(tab,id)
	var o=Control.new();o.name="InfoPopup";add_child(o);o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);o.add_to_group("selection_scope");o.z_index=60
	info_popup=o
	var dim=ColorRect.new();o.add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,0,0,.45);dim.mouse_filter=Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e):if e is InputEventMouseButton and e.pressed:close_info())
	const W=640.0
	var box=UiKit.glass(o,Vector2.ZERO,Vector2(W,200));box.name="Info"
	var close=UiKit.button(box,"",Vector2(W-68,16),Vector2(52,44),close_info);close.icon=UiKit.interface_icon("close");close.expand_icon=true;close.add_theme_constant_override("icon_max_width",20);close.name="InfoClose"
	var picture=UiKit.icon(box,str(info.get("icon",item.get("icon",id))),Vector2(24,24),Vector2(120,120))
	if info.has("texture"):picture.texture=info.texture
	elif item.has("texture"):picture.texture=item.texture
	UiKit.locked_preview(picture,kind in ["locked","soon"])
	var heading=UiKit.label(box,str(info.get("title",item.title)),Vector2(164,26),Vector2(W-164-84,64),24);UiKit.accent(heading);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;heading.name="InfoTitle"
	heading.size.y=clampf(wrapped_height(heading,W-164-84,24),34,66)
	var chip_y=heading.position.y+heading.size.y+6
	status_chip(box,kind,Vector2(164,chip_y))
	UiKit.label(box,str(item.get("caption","")),Vector2(164,chip_y+26),Vector2(W-164-24,22),15,UiKit.MUTED)
	var y=maxf(160.0,chip_y+60)
	var body=Control.new();var by=0.0;var tw=W-48-12
	if str(info.get("text",""))!="":
		var text=UiKit.label(body,str(info.text),Vector2(0,by),Vector2(tw,40),17,UiKit.INK);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.name="InfoText"
		text.size.y=wrapped_height(text,tw,17);by+=text.size.y+12
	if not info.get("rows",[]).is_empty():
		var table=rows_table(info.rows,16);body.add_child(table);table.name="InfoRows";table.position=Vector2(0,by);table.size.x=tw
		by+=info.rows.size()*30+4
	for line in info.get("lines",[]):
		if str(line)=="":continue
		var l=UiKit.label(body,str(line),Vector2(0,by),Vector2(tw,24),15,UiKit.MUTED);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.size.y=maxf(24,wrapped_height(l,tw,15));by+=l.size.y+4
	body.custom_minimum_size=Vector2(tw,by)
	var scroll=ScrollContainer.new();scroll.name="InfoScroll";box.add_child(scroll);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position=Vector2(24,y);scroll.size=Vector2(W-48,minf(by,320));scroll.add_child(body)
	y+=scroll.size.y+16
	for action in info.get("actions",[]):
		var b=action_button(box,action,id,Vector2(24,y),Vector2(W-48,48));b.add_theme_font_size_override("font_size",17);y+=56
	if notice!="":
		UiKit.label(box,notice,Vector2(24,y),Vector2(W-48,26),16,Color("8fe895")).name="InfoNotice";y+=32
	box.size.y=y+12
	var k=panel.scale.x if is_instance_valid(panel) else 1.0
	box.scale=Vector2(k,k);box.position=(get_viewport_rect().size-box.size*k)*.5
