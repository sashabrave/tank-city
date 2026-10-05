extends Control
var hud
var delay=0.0
var signature=""
var content:VBoxContainer
func _ready():
	mouse_filter=Control.MOUSE_FILTER_PASS
	content=VBoxContainer.new();add_child(content);content.add_theme_constant_override("separation",8)
func fit_panel():
	var roster=hud.right_info.get_node("EnemyRoster")
	var width=hud.right_info.size.x-32
	content.size.x=width
	content.size.y=content.get_combined_minimum_size().y
	position=hud.right_info.position+Vector2(16,roster.position.y+roster.content_height()+18)
	size=Vector2(width,content.size.y)
	# Hidden (a choice screen is open): autowrapped labels measure at zero width and grow tall,
	# so the panel keeps only the roster height.
	var tracked=size.y if visible else -10.0
	hud.right_info.size.y=position.y-hud.right_info.position.y+tracked+16
	hud.pause_button.position.y=hud.right_info.position.y+hud.right_info.size.y+16
func _process(delta):
	visible=hud.arena.phase in ["combat","countdown"] and not is_instance_valid(hud.modal) and not hud.hub_layout
	fit_panel()
	delay-=delta
	if delay>0:return
	delay=.15
	var p=Game.progression;var quests=p.quests("tracked")
	var state=str(quests)+str(p.counters)+str(p.tracker_collapsed)
	if state==signature:return
	signature=state
	for child in content.get_children():content.remove_child(child);child.queue_free()
	var toggle=UiKit.button(content,("▸ " if p.tracker_collapsed else "▾ ")+"Задачи · %d" % quests.size(),Vector2.ZERO,Vector2(0,28),func():p.tracker_collapsed=not p.tracker_collapsed;Game.save_soon();signature="";delay=0)
	toggle.custom_minimum_size=Vector2(0,28)
	toggle.add_theme_font_size_override("font_size",12)
	for name in ["normal","hover","pressed","focus"]:
		var style=toggle.get_theme_stylebox(name).duplicate();style.content_margin_top=3;style.content_margin_bottom=3;toggle.add_theme_stylebox_override(name,style)
	if not p.tracker_collapsed:
		# Each tracked task is its own row: name on the left, counter on the right, a thin line between (T-078).
		for i in range(quests.size()):
			var q=quests[i]
			if i>0:
				var line=ColorRect.new();content.add_child(line);line.custom_minimum_size=Vector2(0,1);line.color=Color(1,1,1,.08);line.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var row=HBoxContainer.new();content.add_child(row);row.add_theme_constant_override("separation",8);row.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var label=Label.new();row.add_child(label);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			Texts.set_text(label,q.text)
			label.add_theme_font_size_override("font_size",12);label.add_theme_color_override("font_color",Color("f1eedb"))
			label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			var done=p.count(q)>=q.goal
			var counter=Label.new();row.add_child(counter);counter.text="%d / %d" % [mini(p.count(q),q.goal),q.goal];counter.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
			counter.tooltip_text=Texts.render(preload("res://scripts/progression/quest_catalog.gd").counter_name(q.event))
			counter.add_theme_font_size_override("font_size",12);counter.add_theme_color_override("font_color",UiKit.ORANGE if done else UiKit.MUTED)
	fit_panel()
