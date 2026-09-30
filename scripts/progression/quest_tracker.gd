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
	position=hud.right_info.position+Vector2(16,roster.position.y+roster.content_height()+10)
	size=Vector2(width,content.size.y)
	hud.right_info.size.y=position.y-hud.right_info.position.y+size.y+16
	hud.pause_button.position.y=hud.right_info.position.y+hud.right_info.size.y+16
func _process(delta):
	visible=hud.arena.phase in ["combat","countdown"] and not is_instance_valid(hud.modal)
	fit_panel()
	delay-=delta
	if delay>0:return
	delay=.15
	var p=Game.progression;var quests=p.quests("tracked")
	var state=str(quests)+str(p.counters)+str(p.tracker_collapsed)
	if state==signature:return
	signature=state
	for child in content.get_children():content.remove_child(child);child.queue_free()
	var toggle=UiKit.button(content,("▸ " if p.tracker_collapsed else "▾ ")+"Задачи · %d" % quests.size(),Vector2.ZERO,Vector2(0,28),func():p.tracker_collapsed=not p.tracker_collapsed;Game.save_progress();signature="";delay=0)
	toggle.custom_minimum_size=Vector2(0,28)
	toggle.add_theme_font_size_override("font_size",12)
	for name in ["normal","hover","pressed","focus"]:
		var style=toggle.get_theme_stylebox(name).duplicate();style.content_margin_top=3;style.content_margin_bottom=3;toggle.add_theme_stylebox_override(name,style)
	if not p.tracker_collapsed:
		for q in quests:
			var label=Label.new();content.add_child(label)
			Texts.set_text(label,q.text+"\n%s: %d / %d" % [preload("res://scripts/progression/quest_catalog.gd").counter_name(q.event),p.count(q),q.goal])
			label.add_theme_font_size_override("font_size",12)
			label.add_theme_color_override("font_color",Color("f1eedb"))
			label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	fit_panel()
