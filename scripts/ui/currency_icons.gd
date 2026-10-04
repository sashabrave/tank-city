extends Node
var last=""
var last_size=Vector2.ZERO
var icons:Array=[]
var previous_markers:Array=[]
## Inter capital height relative to the font size.
const CAP_HEIGHT=.727
## Auto-fit never goes below this size: smaller text is not readable on a phone.
const MIN_SIZE=11
## What the label looked like when it was last handled: most frames nothing changed, and then nothing is done
## (perf, 2026-10-03: 45–97 of these ran a font-fit key build and theme lookups every frame, hidden ones too).
var seen_text:="";var seen_size:=Vector2(-1,-1)
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	# A theme or language switch can change the fit without changing the text: look again then.
	Settings.changed.connect(func():seen_size=Vector2(-1,-1))
func _process(_delta):
	var widget=get_parent()
	if not widget.is_visible_in_tree():return
	if widget.text==seen_text and widget.size==seen_size:return
	seen_text=widget.text;seen_size=widget.size
	if fit(widget):last=""
	# Icons are placed from the box size too: a resized label (menu animation, container) re-places them.
	if widget.size!=last_size:last_size=widget.size;last=""
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
		elif widget.horizontal_alignment==HORIZONTAL_ALIGNMENT_RIGHT:x+=widget.size.x-font.get_string_size(full_line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		var block_height=font.get_height(size)*raw.split("\n").size()
		var offset=(widget.size.y-block_height)*.5 if widget is Button or widget.vertical_alignment==VERTICAL_ALIGNMENT_CENTER else widget.size.y-block_height if widget.vertical_alignment==VERTICAL_ALIGNMENT_BOTTOM else 0.0
		# Optical centre: the middle of the capital letters and digits, not of the whole line box (which
		# includes the descender and pushed icons down next to numbers).
		var side=roundf(size*1.05);var line_gap=font.get_height(size)+widget.get_theme_constant("line_spacing")
		var cap_middle=font.get_ascent(size)-size*CAP_HEIGHT*.5
		var y=roundf(offset+prefix.count("\n")*line_gap+cap_middle-side*.5)
		var icon=UiKit.icon(widget,"lock" if markers[i][1]=="🔒" else "alloy" if markers[i][1] in ["◈","◇","сплава"] else "documents",Vector2(x+(size-side)*.5,y),Vector2(side,side));icons.append(icon)
	last=raw

## Fit (design system): a line that does not fit its box shrinks by up to 20%, then gets an ellipsis.
## Wrapped labels with a fixed height shrink until their lines fit. Base size follows any later override.
## Opt out with set_meta("no_fit",true).
var fit_key=""
var fit_base=-1
var fit_applied=-1
func fit(widget:Control)->bool:
	if widget.has_meta("no_fit") or widget.size.x<4 or widget.text=="":return false
	var current=widget.get_theme_font_size("font_size")
	var key=widget.text+"|"+str(widget.size)+"|"+str(current)
	if key==fit_key:return false
	if current!=fit_applied:fit_base=current
	var font:Font=widget.get_theme_font("font");var width=widget.size.x;var height=widget.size.y
	var box=widget.get_theme_stylebox("normal")
	if box:width-=box.get_margin(SIDE_LEFT)+box.get_margin(SIDE_RIGHT);height-=box.get_margin(SIDE_TOP)+box.get_margin(SIDE_BOTTOM)
	if widget is Button and widget.icon:width-=widget.icon.get_width()*minf(1.0,height/maxf(1.0,widget.icon.get_height()))+widget.get_theme_constant("h_separation")
	var smallest=maxi(ceili(fit_base*.8),mini(fit_base,MIN_SIZE));var chosen=fit_base;var fits=true
	if widget is Label and widget.autowrap_mode!=TextServer.AUTOWRAP_OFF:
		if widget.get_parent() is Container or widget.max_lines_visible>=0:fit_key=key;return false
		# Measured with the font directly: Label reshapes lazily, so its own line count lags behind a size change.
		var flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
		var spacing=widget.get_theme_constant("line_spacing")
		chosen=fit_base
		while true:
			var block=font.get_multiline_string_size(widget.text,HORIZONTAL_ALIGNMENT_LEFT,width,chosen,-1,flags)
			var lines=maxi(1,roundi(block.y/font.get_height(chosen)))
			fits=block.y+(lines-1)*spacing<=height+2
			if fits or chosen<=smallest:break
			chosen-=1
	else:
		var widest=0.0
		for line in widget.text.split("\n"):widest=maxf(widest,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,fit_base).x)
		if widest>width+.5:chosen=maxi(smallest,floori(fit_base*width/widest));fits=chosen>smallest or widest*chosen/fit_base<=width+.5
	if chosen!=current:widget.add_theme_font_size_override("font_size",chosen)
	fit_applied=chosen
	if not fits:widget.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	fit_key=widget.text+"|"+str(widget.size)+"|"+str(chosen)
	return chosen!=current
