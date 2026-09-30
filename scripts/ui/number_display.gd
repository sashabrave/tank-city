extends Node
var expression=RegEx.new()
func _ready():
	expression.compile("(?<![\\d.])(-?\\d+)[.,](\\d+)(?![\\d.])")
	RenderingServer.frame_pre_draw.connect(refresh)
	get_tree().node_added.connect(func(node):
		if node is Label or node is Button or node is Label3D or node is RichTextLabel:node.add_to_group("number_display")
		if node is Control:node.add_to_group("localized_hints"))
func clean(value:String)->String:
	var matches=expression.search_all(value);matches.reverse()
	for match_value in matches:
		var fraction=match_value.get_string(2).rstrip("0")
		var replacement=match_value.get_string(1)+("."+fraction if not fraction.is_empty() else "")
		value=value.substr(0,match_value.get_start())+replacement+value.substr(match_value.get_end())
	return value
func refresh():
	for node in get_tree().get_nodes_in_group("localized_hints"):
		if node.is_visible_in_tree():Texts.update_hints(node)
	for node in get_tree().get_nodes_in_group("number_display"):
		if not node.is_visible_in_tree():continue
		var ancestor=node;var editing=false
		while ancestor!=null:
			if ancestor.has_meta("text_editor"):editing=true;break
			ancestor=ancestor.get_parent()
		if editing:continue
		Texts.update_widget(node)
