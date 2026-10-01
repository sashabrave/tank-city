class_name UiKit
extends RefCounted
const INK = Color("f1eedb")
const MUTED = Color("a6aa9f")
## Interface accent; InterfaceTheme keeps it in sync with the ui_accent setting.
static var ORANGE = Color("ff981f")
const CREAM = Color("303833")
## Tablet rhythm (8 px grid): page title 20 at (24,20); 16 below it the content starts; sections 16,
## body 15, captions 13. Outer padding of the content panel is 24.
const PAGE_TITLE_SIZE=20
const SECTION_SIZE=16
const PAGE_PADDING=24.0
const PAGE_CONTENT_TOP=64.0
const TAB_CONTENT_GAP=16.0

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

## Frosted glass panel (design system): blurred, tinted view of what is behind, soft top sheen,
## thin light border. "Стекло интерфейса" in settings falls back to a plain translucent panel.
static func glass(parent: Node,pos: Vector2,dimensions: Vector2,color=Color("242d27")) -> Panel:
	var widget=Panel.new();parent.add_child(widget)
	widget.position=pos;widget.size=dimensions
	var s=style(Color(color,1.0),18,Color(1,1,1,.16))
	s.set_corner_radius_all(18);s.border_color=Color(1,1,1,.16)
	widget.add_theme_stylebox_override("panel",s)
	if Settings.values.get("ui_glass",true):
		var material=ShaderMaterial.new();material.shader=preload("res://shaders/ui/glass.gdshader")
		widget.material=material
		widget.resized.connect(func():material.set_shader_parameter("panel_height",maxf(widget.size.y,1.0)))
		material.set_shader_parameter("panel_height",maxf(dimensions.y,1.0))
	else:s.bg_color=Color(color,.94)
	return widget

## Notification markers (design system). One meaning per colour, the same in 2D and in the world:
## news — something new not yet seen; ready — an action is affordable now; goal — where to go next.
const NOTICE={"news":Color("ff6b57"),"ready":Color("8fe895"),"goal":Color("f1cf55")}
## Badge on a control: a dot (or a pill with a count) at the top-right corner, or at the trailing edge of a list row.
static func badge(parent:Control,kind:="news",count:=0,place:="corner")->Panel:
	var old=parent.get_node_or_null("Badge")
	if old:old.get_parent().remove_child(old);old.queue_free()
	var dot=Panel.new();dot.name="Badge";parent.add_child(dot);dot.mouse_filter=Control.MOUSE_FILTER_IGNORE;dot.z_index=1
	var s=StyleBoxFlat.new();s.bg_color=NOTICE.get(kind,NOTICE.news);s.set_corner_radius_all(10);s.set_border_width_all(2);s.border_color=Color("1b211d")
	dot.add_theme_stylebox_override("panel",s)
	dot.size=Vector2(12,12)
	if count>0:
		dot.size=Vector2(maxf(20,12+8*str(count).length()),20)
		var text=Label.new();dot.add_child(text);text.text=str(count);text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		text.add_theme_font_override("font",field_font());text.add_theme_font_size_override("font_size",12);text.add_theme_color_override("font_color",Color("1b211d"))
	var place_badge=func():
		if not is_instance_valid(dot):return
		dot.position=Vector2(parent.size.x-dot.size.x-6,6) if place=="corner" else Vector2(parent.size.x-dot.size.x-14,(parent.size.y-dot.size.y)*.5)
	place_badge.call();parent.resized.connect(place_badge)
	return dot

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
	widget.texture=trimmed(icon_texture(id))
	parent.add_child(widget);return widget

## Icons come from several sets with very different transparent margins (a pistol filled a third of its
## frame, a tank filled all of it). Cropping to the visible pixels plus a small even margin gives every
## icon the same visual size in slots, tiles and cards. Cached per file; atlases are left as they are.
static var trim_cache:Dictionary={}
static func trimmed(texture:Texture2D)->Texture2D:
	if texture==null or texture is AtlasTexture or texture.resource_path=="" or texture.resource_path.ends_with(".svg"):return texture
	var key=texture.resource_path
	if trim_cache.has(key):return trim_cache[key]
	var image=texture.get_image()
	if image==null or image.is_compressed():trim_cache[key]=texture;return texture
	var used=image.get_used_rect()
	if used.size.x<=0 or used.size.y<=0:trim_cache[key]=texture;return texture
	var side=maxf(used.size.x,used.size.y);var pad=side*.06
	var region=Rect2(Vector2(used.position)-Vector2.ONE*pad,Vector2(used.size)+Vector2.ONE*pad*2).intersection(Rect2(Vector2.ZERO,Vector2(image.get_size())))
	# Barely any margin: keep the original file, nothing to gain.
	if region.size.x*region.size.y>image.get_width()*image.get_height()*.85:trim_cache[key]=texture;return texture
	var atlas=AtlasTexture.new();atlas.atlas=texture;atlas.region=region;atlas.set_meta("trim_source",key)
	trim_cache[key]=atlas;return atlas

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
## Horizontal tabs filling a block: equal widths, 8 px gaps, the active one filled like settings tabs.
## tabs: [[key,title], …]; select(key) is called on press.
static func tab_row(parent:Control,pos:Vector2,width:float,tabs:Array,active:String,select:Callable,height:=40.0)->Array:
	var gap=8.0;var each=(width-gap*(tabs.size()-1))/maxf(1,tabs.size());var result=[]
	for i in range(tabs.size()):
		var key=str(tabs[i][0])
		var b=button(parent,str(tabs[i][1]),pos+Vector2(i*(each+gap),0),Vector2(each,height),func():select.call(key))
		b.name="Tab_"+key;b.add_theme_font_size_override("font_size",14);b.clip_text=true;b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		for state in ["normal","hover","pressed","disabled","focus"]:
			var tight=b.get_theme_stylebox(state).duplicate();tight.content_margin_left=6;tight.content_margin_right=6;b.add_theme_stylebox_override(state,tight)
		b.custom_minimum_size=Vector2(0,height);b.size=Vector2(each,height)
		if key==active:
			for state in ["normal","hover","focus"]:b.add_theme_stylebox_override(state,style(Color("584a2c"),6,ORANGE))
		result.append(b)
	return result

## Unique artwork (cozy_ui_2026): explicit keys "upgrades/<id>", "stats/<id>", "abilities/<id>",
## "headquarters/<id>", "garage/<vehicle>_<branch>". Looked up before any alias folding; a missing file
## falls back to the old lookup by the bare id, so semantic ids never have to change for graphics.
const ART_GROUPS=["upgrades","stats","abilities","headquarters","garage"]
static var icon_cache:Dictionary={}
## Memoised: several call sites refresh icons every frame; disk lookups happen once per id and set.
static func icon_texture(id:String)->Texture2D:
	var key=Illustrations.current()+"|"+id
	if not icon_cache.has(key):icon_cache[key]=icon_lookup(id)
	return icon_cache[key]
static func icon_lookup(id:String)->Texture2D:
	if "/" in id:
		if id.get_slice("/",0) in ART_GROUPS:
			var art=Illustrations.texture("res://assets/icons/"+id+".png")
			if art:return art
		id=id.get_slice("/",1)
	if id in ["debug","lock","repeat","inventory","fighter","quests","notifications","music","settings","guide","base","about"]:return interface_icon(id)
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
	# Design system: the old value is grey, the new one green and bold.
	var regex=RegEx.new();regex.compile("([0-9]+(?:[.,][0-9]+)?(?:%| с| /с)?)(\\s*→\\s*)([0-9]+(?:[.,][0-9]+)?(?:%| с| /с)?)")
	Texts.set_text(rich,regex.sub(text,"[color=#8d9589]$1[/color][color=#6f7a6c]$2[/color][b][color=#8fe895]$3[/color][/b]",true));label.hide()
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
