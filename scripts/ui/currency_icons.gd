extends Node
var last=""
var icons:Array=[]
var previous_markers:Array=[]
func _ready():process_mode=Node.PROCESS_MODE_ALWAYS
func _process(_delta):
	var widget=get_parent()
	if widget.text==last:return
	for icon in icons:icon.queue_free()
	icons.clear()
	var raw:String=widget.text
	if not widget.has_meta("text_source") or raw!=widget.get_meta("text_rendered",raw):
		widget.set_meta("text_source",raw);widget.set_meta("text_revision",-1)
	var regex=RegEx.new();regex.compile("[◈◇🔒]|(?<=\\d )сплава|(?<=\\d )документов|(?<=\\d )док\\.")
	var matches=regex.search_all(raw)
	var markers:Array=[]
	for result in matches:markers.append([result.get_start(),result.get_string()])
	for i in range(markers.size()-1,-1,-1):
		var m=markers[i];raw=raw.substr(0,m[0])+"\u2003"+raw.substr(m[0]+m[1].length())
	if markers.is_empty() and raw.contains("\u2003"):markers=previous_markers.duplicate()
	previous_markers=markers.duplicate()
	var positions:Array=[]
	for i in range(raw.length()):
		if raw[i]=="\u2003":positions.append(i)
	widget.text=raw
	if widget.has_meta("text_rendered"):widget.set_meta("text_rendered",raw)
	var font=widget.get_theme_font("font");var size=widget.get_theme_font_size("font_size")
	for i in range(mini(positions.size(),markers.size())):
		var index=positions[i];var prefix=raw.substr(0,index);var line=prefix.split("\n")[-1]
		var full_line=raw.split("\n")[prefix.count("\n")]
		var x=font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		if widget is Button or widget.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER:x+=(widget.size.x-font.get_string_size(full_line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)*.5
		var block_height=font.get_height(size)*raw.split("\n").size()
		var offset=(widget.size.y-block_height)*.5 if widget is Button or widget.vertical_alignment==VERTICAL_ALIGNMENT_CENTER else widget.size.y-block_height if widget.vertical_alignment==VERTICAL_ALIGNMENT_BOTTOM else 0.0
		var y=offset+prefix.count("\n")*font.get_height(size)+(font.get_height(size)-size)*.5
		var icon=UiKit.icon(widget,"lock" if markers[i][1]=="🔒" else "alloy" if markers[i][1] in ["◈","◇","сплава"] else "documents",Vector2(x,y),Vector2(size,size));icons.append(icon)
	last=raw
