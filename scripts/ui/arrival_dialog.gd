extends Control
signal closed
## Hub greeting: short lines from the unlucky soldier who keeps blowing up. Tips about real mechanics are
## mixed with one-sentence stories (scripts/ui/hub_lines.gd). «Ещё» shows up to MORE further lines, then
## the soldier sends you to battle and only «Продолжить» is left.
const Lines=preload("res://scripts/ui/hub_lines.gd")
const MORE=3
static var last_lines:Dictionary={}
var reason="wake"
var panel:Panel
var portrait:TextureRect
var speaker:Label
var words:HFlowContainer
var answers:Array=[]
var animation:Tween
var dismissed=false
var more_left=MORE
var shown=0
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
	add_to_group("selection_scope");z_index=90
	var shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.22)
	panel=UiKit.glass(self,Vector2.ZERO,Vector2.ZERO)
	portrait=TextureRect.new();panel.add_child(portrait);portrait.texture=preload("res://scripts/ui/class_gallery.gd").texture(Game.selected_class);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	speaker=UiKit.label(panel,"Боец",Vector2.ZERO,Vector2.ZERO,20,UiKit.MUTED)
	words=HFlowContainer.new();panel.add_child(words);words.add_theme_constant_override("h_separation",9);words.add_theme_constant_override("v_separation",8);words.mouse_filter=Control.MOUSE_FILTER_IGNORE
	show_line(next_line())
	for caption in ["Ещё","Продолжить"]:
		var button=UiKit.button(panel,caption,Vector2.ZERO,Vector2.ZERO,more if caption=="Ещё" else dismiss,caption=="Продолжить");button.focus_mode=Control.FOCUS_ALL;answers.append(button)
	resized.connect(layout);layout()
	answers[-1].grab_focus()
## Stories season the tips: every second line is a story, never the same line twice in a row.
func next_line()->String:
	var pool=Lines.STORIES if shown%2==1 else Lines.TIPS
	var key="story" if pool==Lines.STORIES else "tip"
	var available=pool.filter(func(line):return line!=last_lines.get(key,"") and line not in last_lines.get("session",[]))
	if available.is_empty():available=pool.duplicate()
	var line=available.pick_random();last_lines[key]=line
	var session:Array=last_lines.get("session",[]);session.append(line);last_lines["session"]=session.slice(-12)
	shown+=1;return line
func show_line(line:String):
	if animation:animation.kill()
	for child in words.get_children():words.remove_child(child);child.queue_free()
	# Translate the whole sentence before splitting so words retain their natural case.
	for word in Texts.render(line).split(" ",false):
		var slot=Control.new();words.add_child(slot)
		var key=word.find("[[")
		if key>=0 and word.find("]]",key)>key:slot.add_child(key_cap(word.substr(key+2,word.find("]]",key)-key-2)))
		var label=Label.new();slot.add_child(label);label.set_meta("text_editor",true);label.add_theme_font_override("font",UiKit.field_font());label.add_theme_color_override("font_color",UiKit.INK)
		label.text=word.substr(0,key)+word.substr(word.find("]]",key)+2) if key>=0 else word
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if is_inside_tree():layout()
	animation=create_tween().set_parallel(true)
	for i in range(words.get_child_count()):
		var item=words.get_child(i);item.modulate.a=0
		animation.tween_property(item,"modulate:a",1.0,.12).set_delay(i*.045)
## A key from the line, drawn like the key hints in battle. Unbound or unknown actions print the token.
func key_cap(token:String)->Panel:
	var text=token
	if Settings.keys.has(token):
		text=InputScheme.glyph(token)
		if text=="":text=OS.get_keycode_string(Settings.keys[token])
	var cap=Panel.new();cap.name="Key";cap.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style=UiKit.style(Color("29372f"),7,Color("d4ddce"));style.set_border_width_all(2);cap.add_theme_stylebox_override("panel",style)
	var label=Label.new();label.name="Glyph";cap.add_child(label);label.text=text;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color",Color("f2f1df"));label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return cap
func more():
	if more_left<=0:return
	more_left-=1
	show_line(next_line() if more_left>0 else Lines.ENOUGH)
	if more_left==0:
		answers[0].hide();answers[-1].grab_focus();layout()
func layout():
	const PAD=24.0
	var width=minf(1000,size.x-32);var height=minf(300,size.y-32)
	panel.size=Vector2(width,height);panel.position=(size-panel.size)*Vector2(.5,.72)
	var side=clampf(minf(width*.26,height-PAD*2),96,height-PAD*2)
	portrait.position=Vector2(PAD,PAD);portrait.size=Vector2(side,side)
	var body_x=PAD+side+PAD;var body_width=width-body_x-PAD
	speaker.position=Vector2(body_x,PAD-2);speaker.size=Vector2(body_width,26)
	var button_height=50.0
	words.position=Vector2(body_x,PAD+36);words.size=Vector2(body_width,height-PAD*2-36-button_height-14)
	var font_size=26 if width>=750 else 20
	for slot in words.get_children():
		var label:Label=slot.get_child(-1);label.add_theme_font_size_override("font_size",font_size)
		var cap:Panel=slot.get_node_or_null("Key");var x=0.0
		var line_height=label.get_minimum_size().y
		if cap:
			var glyph:Label=cap.get_node("Glyph");glyph.add_theme_font_size_override("font_size",int(font_size*.7))
			var cap_side=line_height*.92;cap.size=Vector2(maxf(cap_side,glyph.get_minimum_size().x+16),cap_side);cap.position=Vector2(0,(line_height-cap_side)*.5);glyph.size=cap.size
			x=cap.size.x+(4 if label.text!="" and not label.text[0] in ".,:;!?" else 0)
		label.position=Vector2(x,0);label.size=label.get_minimum_size()
		slot.custom_minimum_size=Vector2(x+(label.size.x if label.text!="" else 0),line_height)
	var visible_answers=answers.filter(func(b):return b.visible)
	for i in range(visible_answers.size()):
		var share=(body_width-12*(visible_answers.size()-1))/visible_answers.size()
		visible_answers[i].position=Vector2(body_x+i*(share+12),height-PAD-button_height);visible_answers[i].size=Vector2(share,button_height)
func _unhandled_key_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_1 and answers[0].visible:get_viewport().set_input_as_handled();more()
		elif event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_ESCAPE,KEY_2]:get_viewport().set_input_as_handled();dismiss()
func dismiss():
	if dismissed:return
	dismissed=true
	if animation:animation.kill()
	Game.reset_input();closed.emit();queue_free()
