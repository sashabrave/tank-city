extends CanvasLayer
var feed:VBoxContainer
var pending:Array=[]
var elapsed=0.0
var dirty=false
func _ready():
	layer=8;process_mode=Node.PROCESS_MODE_ALWAYS
	feed=VBoxContainer.new();add_child(feed);feed.size=Vector2(235,0);feed.add_theme_constant_override("separation",7);feed.mouse_filter=Control.MOUSE_FILTER_IGNORE
func post(text:String,sender:String="Оперштаб",kind:String="technical"):
	if text.strip_edges()=="":return
	var now=Time.get_unix_time_from_system()
	if not Game.notification_history.is_empty():
		var last=Game.notification_history.back()
		if last.text==text and now-float(last.time)<4:return
	var item={"text":text,"sender":sender,"time":now,"read":kind=="technical","category":kind}
	Game.notification_history.append(item)
	if Game.notification_history.size()>150:Game.notification_history.pop_front()
	if kind=="important":pending.append(item)
	if pending.size()>2:pending.pop_front()
	dirty=true
func category(item:Dictionary)->String:
	return item.get("category","important" if item.sender=="Командование" or "задани" in str(item.text).to_lower() or "приказ" in str(item.text).to_lower() or "телеграм" in str(item.text).to_lower() else "technical")
func mark_all(kind:String=""):
	for item in Game.notification_history:
		if kind=="" or category(item)==kind:item.read=true
	Game.save_progress()
func unread()->int:return Game.notification_history.filter(func(e):return not e.read and category(e)=="important").size()
func _process(delta):
	elapsed+=delta
	if dirty and elapsed>1:Game.save_progress();dirty=false;elapsed=0
	var hud=get_tree().get_first_node_in_group("battle_message_anchor")
	var allowed=not get_tree().paused
	var limit=2
	feed.position=Vector2(get_viewport().get_visible_rect().size.x-263,150)
	if is_instance_valid(hud) and hud.root.is_visible_in_tree():
		allowed=allowed and hud.arena.phase in ["combat","countdown"]
		feed.position=hud.left_info.global_position+Vector2(0,hud.left_info.size.y+12)
		if hud.dpad.global_position.y-feed.position.y<165:limit=1
	for context in get_tree().get_nodes_in_group("notification_context"):
		if context.is_visible_in_tree():
			if "phase" in context and context.phase in ["intro","workshop"]:allowed=false
			if "modal" in context and is_instance_valid(context.modal):allowed=false
	feed.visible=allowed
	while feed.get_child_count()>limit:
		var extra=feed.get_child(0);feed.remove_child(extra);extra.queue_free()
	if not allowed:return
	if not pending.is_empty() and feed.get_child_count()>=limit:
		var oldest=feed.get_child(0);feed.remove_child(oldest);oldest.queue_free()
	for panel in feed.get_children():
		var life=float(panel.get_meta("life"))-delta;panel.set_meta("life",life)
		panel.modulate.a=minf(1,life/.35)
		if life<=0:feed.remove_child(panel);panel.queue_free()
	if feed.get_child_count()<limit and not pending.is_empty():show_item(pending.pop_front())
func show_item(item:Dictionary):
	var panel=PanelContainer.new();feed.add_child(panel);panel.custom_minimum_size=Vector2(235,0);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style=UiKit.style(Color("293a32"),7,Color("647769"))
	style.content_margin_left=0;style.content_margin_right=0;style.content_margin_top=0;style.content_margin_bottom=0
	panel.add_theme_stylebox_override("panel",style);panel.set_meta("life",5.0)
	var margin=MarginContainer.new();panel.add_child(margin);margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,8)
	var column=VBoxContainer.new();margin.add_child(column);column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var caption=Label.new();column.add_child(caption);Texts.set_text(caption,"▰ "+item.sender+" / Канал");caption.clip_text=true;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.add_theme_font_size_override("font_size",10);caption.add_theme_color_override("font_color",Color("a2b9a8"))
	var body=Label.new();column.add_child(body);Texts.set_text(body,item.text);body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.custom_minimum_size.x=219;body.max_lines_visible=2;body.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.add_theme_font_size_override("font_size",13);body.add_theme_color_override("font_color",Color("e7eddf"))
	if UiKit.motion_enabled():UiKit.reveal(panel,0,Vector2(0,-30),.3)
	else:panel.modulate.a=1.0
