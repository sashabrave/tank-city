extends Node
## UI-only palette. Source colors are retained so repeated switching is reversible.
const STYLES=["panel","normal","hover","pressed","disabled","focus","read_only","normal_mirrored","hover_mirrored","pressed_mirrored"]
const COLORS=["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color","default_color","font_selected_color","font_placeholder_color","icon_normal_color","icon_hover_color","icon_pressed_color","icon_focus_color","icon_hover_pressed_color","clear_button_color","clear_button_color_pressed"]
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	Settings.changed.connect(refresh)
	get_tree().node_added.connect(on_added)
	call_deferred("refresh")
func on_added(node:Node):
	if node is Control:apply_node.call_deferred(node)
func refresh():walk(get_tree().root)
func walk(node:Node):
	if node is Control:apply_node(node)
	for child in node.get_children():walk(child)
func apply_node(node):
	if not is_instance_valid(node) or not node.is_inside_tree() or node.get_meta("keep_theme_colors",false):return
	var light=Settings.values.get("ui_theme","dark")=="light"
	if node is OptionButton and node.has_meta("setting_key"):
		node.select(node.get_meta("setting_values").find(Settings.values[node.get_meta("setting_key")]))
	if node is TextureRect and node.texture and "assets/icons/interface" in node.texture.resource_path:
		if not node.has_meta("theme_source_modulate"):node.set_meta("theme_source_modulate",node.modulate)
		node.modulate=Color("28362a") if light else node.get_meta("theme_source_modulate")
	if not node.has_meta("theme_source_styles"):
		var source={}
		if not node is ProgressBar:
			for key in STYLES:
				if node.has_theme_stylebox(key):
					var box=node.get_theme_stylebox(key)
					if box is StyleBoxFlat:source[key]=box.duplicate()
		node.set_meta("theme_source_styles",source)
		var colors={}
		for key in COLORS:
			if node.has_theme_color(key):colors[key]=node.get_theme_color(key)
			elif node is Button and key.begins_with("icon_"):colors[key]=Color.WHITE
		node.set_meta("theme_source_colors",colors)
	for key in node.get_meta("theme_source_styles"):
		var style:StyleBoxFlat=node.get_meta("theme_source_styles")[key].duplicate()
		if light:
			var c=style.bg_color
			if c.a>.05 and c.v<.55 and c.s<.65:
				style.bg_color=Color(.93,.93,.87,c.a)
				if style.border_color.s<.3:style.border_color=Color(.61,.65,.56,style.border_color.a)
		node.add_theme_stylebox_override(key,style)
	for key in node.get_meta("theme_source_colors"):
		var c:Color=node.get_meta("theme_source_colors")[key]
		if light and c.v>.5 and c.s<.5:c=Color(.20,.25,.20,c.a) if key!="font_disabled_color" else Color(.48,.52,.46,c.a)
		node.add_theme_color_override(key,c)
