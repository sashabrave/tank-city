extends Button
var entry:Dictionary
signal read_requested
func _ready():
	text="";size_flags_horizontal=Control.SIZE_EXPAND_FILL;mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style=UiKit.style(Color("343d34") if state=="hover" else Color("30382f"),8,UiKit.ORANGE if state=="focus" else Color("647060"))
		style.set_content_margin_all(0);add_theme_stylebox_override(state,style)
	var margin=MarginContainer.new();add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for side in ["left","right"]:margin.add_theme_constant_override("margin_"+side,18)
	for side in ["top","bottom"]:margin.add_theme_constant_override("margin_"+side,14)
	var column=VBoxContainer.new();margin.add_child(column);column.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_theme_constant_override("separation",8)
	var font=UiKit.field_font()
	var date=Time.get_datetime_dict_from_unix_time(int(entry.time))
	var caption=Label.new();column.add_child(caption);Texts.set_text(caption,("●  " if not entry.read else "")+entry.sender+" · %02d:%02d" % [date.hour,date.minute]);caption.add_theme_font_override("font",font);caption.add_theme_font_size_override("font_size",12);caption.add_theme_color_override("font_color",UiKit.MUTED);caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var body=Label.new();column.add_child(body);Texts.set_text(body,entry.text);body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_theme_font_override("font",font);body.add_theme_font_size_override("font_size",15);body.add_theme_color_override("font_color",UiKit.INK);body.add_theme_constant_override("line_spacing",4);body.mouse_filter=Control.MOUSE_FILTER_IGNORE
	column.minimum_size_changed.connect(func():custom_minimum_size.y=column.get_combined_minimum_size().y+28)
	custom_minimum_size.y=96
	pressed.connect(func():read_requested.emit())
