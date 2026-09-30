class_name UiKit
extends RefCounted
const INK = Color("f1eedb")
const MUTED = Color("a6aa9f")
const ORANGE = Color("ff981f")
const CREAM = Color("303833")
const PAGE_TITLE_SIZE=16
const TAB_CONTENT_GAP=28.0

static func style(color: Color, radius=16, border=Color.TRANSPARENT) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=surface_color(color)
	s.set_corner_radius_all(mini(radius,12))
	s.set_border_width_all(1)
	s.border_color=Color("697166") if border==Color.TRANSPARENT else surface_border(border)
	s.content_margin_left=18;s.content_margin_right=18
	s.content_margin_top=12;s.content_margin_bottom=12
	return s

static func panel(parent: Node,pos: Vector2,dimensions: Vector2,color=Color("eef0e2")) -> Panel:
	var widget=Panel.new()
	parent.add_child(widget)
	widget.position=pos;widget.size=dimensions
	widget.add_theme_stylebox_override("panel",style(color,18,Color("a9b2a1")))
	return widget

static func label(parent: Node,text: String,pos: Vector2,dimensions: Vector2,font_size=20,color=INK) -> Label:
	var widget=Label.new()
	parent.add_child(widget)
	widget.add_theme_font_override("font",field_font())
	Texts.set_text(widget,text);widget.clip_text=true;widget.position=pos;widget.size=dimensions
	widget.add_theme_color_override("font_color",text_color(color))
	widget.add_theme_font_size_override("font_size",font_size)
	widget.mouse_filter=Control.MOUSE_FILTER_IGNORE
	widget.add_child(preload("res://scripts/ui/currency_icons.gd").new())
	return widget

static func button(parent: Node,text: String,pos: Vector2,dimensions: Vector2,callback: Callable,primary=false) -> Button:
	var widget=Button.new()
	parent.add_child(widget)
	widget.add_theme_font_override("font",field_font())
	Texts.set_text(widget,text);widget.position=pos;widget.size=dimensions
	widget.add_theme_font_size_override("font_size",20)
	widget.add_theme_color_override("font_color",Color("20271f") if primary else INK)
	widget.add_theme_color_override("font_hover_color",Color("20271f") if primary else INK)
	widget.add_theme_color_override("font_pressed_color",Color("20271f"))
	widget.add_theme_color_override("font_disabled_color",Color("8d9589"))
	widget.add_theme_stylebox_override("normal",style(ORANGE if primary else CREAM,13,Color("adb6a4")))
	widget.add_theme_stylebox_override("hover",style(Color("ffd080") if primary else Color("424b40"),13,ORANGE))
	widget.add_theme_stylebox_override("pressed",style(Color("d7852d"),13))
	widget.add_theme_stylebox_override("disabled",style(Color("272e29"),13))
	widget.focus_mode=Control.FOCUS_NONE
	widget.pressed.connect(callback)
	press_bounce(widget)
	widget.add_child(preload("res://scripts/ui/currency_icons.gd").new())
	if text=="Выбрать":widget.add_to_group("reward_choice")
	return widget

static func icon(parent: Node,id: String,pos: Vector2,dimensions: Vector2) -> TextureRect:
	var widget=TextureRect.new();widget.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;widget.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	widget.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	widget.mouse_filter=Control.MOUSE_FILTER_IGNORE;widget.position=pos;widget.size=dimensions
	widget.texture=icon_texture(id)
	parent.add_child(widget);return widget

## Interface motion (design system). All list and card entrances go through reveal(); buttons get a short press bounce.
## "Анимации интерфейса" in settings turns motion off; content is always shown in its final state.
static func motion_enabled()->bool:return Settings.values.get("ui_motion",true) and DisplayServer.get_name()!="headless"
## Slides a control in from `offset` with a fade. `index` staggers list items (35 ms each, capped).
## Works for container children too: the move starts after the container placed the node.
static func reveal(node:Control,index:int=0,offset:=Vector2(0,-22),duration:=.28):
	if not motion_enabled() or not is_instance_valid(node):return
	node.modulate.a=0.0
	await node.get_tree().process_frame
	if not is_instance_valid(node) or not node.is_inside_tree():return
	var target=node.position;node.position=target+offset
	var delay=minf(index,10)*.035
	var tween=node.create_tween().set_parallel(true)
	tween.tween_property(node,"modulate:a",1.0,duration*.8).set_delay(delay)
	tween.tween_property(node,"position",target,duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
## Reveals every Control child of a list, top to bottom.
static func reveal_list(list:Node,offset:=Vector2(0,-22)):
	var i=0
	for child in list.get_children():
		if child is Control:reveal(child,i,offset);i+=1
## Newly arrived item: drops from higher up with a stronger overshoot and a warm flash.
static func arrive(node:Control,index:int=0):
	reveal(node,index,Vector2(0,-70),.42)
	if not motion_enabled():return
	var flash=node.create_tween();flash.tween_property(node,"self_modulate",Color(1.25,1.15,.9),.18).set_delay(.3+minf(index,10)*.035);flash.tween_property(node,"self_modulate",Color.WHITE,.35)
## Slides a finished item down and out, then runs `done`.
static func leave(node:Control,done:Callable):
	if not motion_enabled() or not is_instance_valid(node):done.call();return
	var tween=node.create_tween().set_parallel(true)
	tween.tween_property(node,"position",node.position+Vector2(0,28),.22).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(node,"modulate:a",0.0,.22)
	tween.chain().tween_callback(done)
static func press_bounce(button:Button):
	button.button_down.connect(func():
		if not motion_enabled():return
		button.pivot_offset=button.size*.5
		button.create_tween().tween_property(button,"scale",Vector2.ONE*.95,.06))
	button.button_up.connect(func():
		if not motion_enabled() or not is_instance_valid(button):return
		button.create_tween().tween_property(button,"scale",Vector2.ONE,.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
static func interface_icon(id:String)->Texture2D:
	return load("res://assets/icons/interface_straight/"+id+".svg")
static func icon_texture(id:String)->Texture2D:
	if id in ["lock","repeat","inventory","fighter","quests","notifications","music","settings","guide","base","about"]:return interface_icon(id)
	var sections=["inventory","fighter","quests","notifications","music","settings","guide","base","workshop"]
	if id in sections:
		var atlas=AtlasTexture.new();atlas.atlas=load("res://assets/icons/field_v1/sections.png")
		var cell=atlas.atlas.get_size()/3.0;var index=sections.find(id)
		atlas.region=Rect2(Vector2(index%3,index/3)*cell,cell);return atlas
	if id=="field_repair":id="vehicle_repair"
	if id.begins_with("vehicle_") and id.trim_prefix("vehicle_") in GarageCatalog.VEHICLES:id=id.trim_prefix("vehicle_")
	for vehicle_kind in GarageCatalog.VEHICLES:
		if id.begins_with(vehicle_kind+"_"):id=vehicle_kind;break
	if id=="core":id="documents"
	if id in HQCatalog.DATA:id=HQCatalog.DATA[id].icon
	if ResourceLoader.exists("res://assets/icons/current/"+id+".svg"):return load("res://assets/icons/current/"+id+".svg")
	var key={"range":"sniper","healing":"heart","device_power":"damage","device_cooldown":"fire","weapon_intercept":"pressure","recovery":"shield","intercept":"pressure","weapon_damage":"damage","weapon_fire":"fire","cooldown":"fire","power":"damage","utility":"slots","hp":"health"}.get(id,id)
	var path="res://assets/icons/v1/"+key+".png"
	if not ResourceLoader.exists(path):path="res://assets/icons/v09/"+key+".png"
	# Missing artwork falls back to the Straight interface set before the generic recipe icon.
	if not ResourceLoader.exists(path) and ResourceLoader.exists("res://assets/icons/interface_straight/"+key+".svg"):return interface_icon(key)
	if not ResourceLoader.exists(path):path="res://assets/icons/v1/recipe.png"
	return load(path) if ResourceLoader.exists(path) else null

static func number(value:float)->String:
	return ("%.2f" % value).rstrip("0").rstrip(".")
static func stat_bars(parent:Node,pos:Vector2,width:float,rows:Array,row_height=30.0)->Control:
	var bars=preload("res://scripts/ui/stat_bars.gd").new();parent.add_child(bars);bars.position=pos;bars.size=Vector2(width,rows.size()*row_height);bars.row_height=row_height;bars.set_rows(rows);return bars

static func numeric_description(label:Control,text:String):
	var rich=RichTextLabel.new();rich.name="NumericDescription";label.get_parent().add_child(rich)
	rich.position=label.position;rich.size=label.size;rich.mouse_filter=Control.MOUSE_FILTER_IGNORE;rich.bbcode_enabled=true;rich.scroll_active=false
	rich.add_theme_color_override("default_color",INK);rich.add_theme_font_size_override("normal_font_size",label.get_theme_font_size("font_size"))
	var bold=SystemFont.new();bold.font_names=PackedStringArray(["Arial"]);bold.font_weight=700;rich.add_theme_font_override("bold_font",bold)
	var regex=RegEx.new();regex.compile("[0-9]+(?:[.,][0-9]+)?(?:%| с)?\\s*→\\s*[0-9]+(?:[.,][0-9]+)?(?:%| с)?")
	Texts.set_text(rich,regex.sub(text,"[b][color=#a3cd85]$0[/color][/b]",true));label.hide()
	return rich
static func change_text(title:String,before:float,after:float,suffix:String="")->String:
	return title+": "+number(before)+" → "+number(after)+suffix

static func muted_locked_button(button:Button):
	var muted=button.get_theme_stylebox("disabled").duplicate()
	if muted is StyleBoxFlat:
		muted.set_border_width_all(0)
		muted.bg_color=Color(.65,.68,.62,.12)
		muted.shadow_size=0
	button.add_theme_stylebox_override("disabled",muted)
	button.add_theme_color_override("font_disabled_color",Color(.65,.69,.61,.65))
	button.add_theme_color_override("icon_disabled_color",Color(1,1,1,.25))

static var shared_font:SystemFont
static func field_font()->SystemFont:
	if shared_font==null:
		shared_font=SystemFont.new();shared_font.font_names=PackedStringArray(["Arial","Noto Sans","DejaVu Sans"]);shared_font.font_weight=600
	return shared_font

static func surface_color(color:Color)->Color:
	# Compatibility for existing light-panel callers; semantic accents stay distinct.
	if color.a<.2:return color
	if color.r>.65 and color.g>.65 and color.b>.55:return Color("303832fc")
	if color.g>color.r and color.g>color.b:return Color("242d27fc")
	return color
static func surface_border(color:Color)->Color:
	return Color("73796b") if color.s<.3 else color
static func text_color(color:Color)->Color:
	if maxf(color.r,maxf(color.g,color.b))<.55:return MUTED if color.r>.30 else INK
	return color

# Apply only to artwork, never to the containing card or its text.
static func locked_preview(image:CanvasItem,locked:bool)->void:
	image.modulate=Color.WHITE
	if locked:
		var material=ShaderMaterial.new();material.shader=preload("res://shaders/ui/locked_preview.gdshader");image.material=material
	else:image.material=null
