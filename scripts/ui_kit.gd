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
	settle_layer(widget,color)
	return widget

## Turn an existing panel (scene or code) into frosted glass, the same look as glass() (T-042).
static func glassify(widget:Panel,color=Color("242d27")):
	var s=style(Color(color,1.0),18,Color(1,1,1,.16));s.set_corner_radius_all(18);s.border_color=Color(1,1,1,.16)
	widget.add_theme_stylebox_override("panel",s)
	if Settings.values.get("ui_glass",true):
		var material=ShaderMaterial.new();material.shader=preload("res://shaders/ui/glass.gdshader");widget.material=material
		widget.resized.connect(func():material.set_shader_parameter("panel_height",maxf(widget.size.y,1.0)))
		material.set_shader_parameter("panel_height",maxf(widget.size.y,1.0))
	else:s.bg_color=Color(color,.94)
	settle_layer(widget,color)

## Window layers (T-238): only the first window is glass. A window opened over another one (the «i» card over a
## station, a list over the tablet) is drawn solid and dark over a strong dim: glass reads the screen once per
## canvas layer, so a second pane on the same layer showed the hub through the window under it.
const STACK_DIM:=.62
const STACKED_COLOR:=Color("1f2622")
static func settle_layer(widget:Panel,color:Color):
	widget.add_to_group("ui_glass")
	widget.set_meta("glass_order",Time.get_ticks_usec())
	# Positions and sizes are final only after layout: decide on the first draw.
	widget.draw.connect(func():
		if widget.get_meta("glass_layer_set",false):return
		widget.set_meta("glass_layer_set",true)
		if stacked(widget):make_stacked(widget,color)
	,CONNECT_ONE_SHOT)
## Another glass window drawn earlier covers most of this panel (or holds it): this one is a second layer.
static func stacked(widget:Panel)->bool:
	if not widget.is_inside_tree():return false
	var mine:=widget.get_global_rect()
	if mine.get_area()<=1.0:return false
	for other in widget.get_tree().get_nodes_in_group("ui_glass"):
		if other==widget or not is_instance_valid(other) or not other.is_visible_in_tree() or leaving(other):continue
		if widget.is_ancestor_of(other) or float(other.get_meta("glass_order",0))>=float(widget.get_meta("glass_order",0)):continue
		if other.is_ancestor_of(widget) or mine.intersection(other.get_global_rect()).get_area()>=mine.get_area()*.5:return true
	return false
## A window being rebuilt or closed (it or a parent is queued for deletion) is not under anything any more.
static func leaving(node:Node)->bool:
	while node!=null:
		if node.is_queued_for_deletion():return true
		node=node.get_parent()
	return false
static func make_stacked(widget:Panel,color:Color):
	widget.set_meta("glass_stacked",true);widget.material=null
	var s=widget.get_theme_stylebox("panel")
	if s is StyleBoxFlat:
		s=s.duplicate();s.bg_color=STACKED_COLOR.lerp(Color(color,1.0),.25);s.border_color=Color(1,1,1,.12)
		s.shadow_color=Color(0,0,0,.45);s.shadow_size=18;widget.add_theme_stylebox_override("panel",s)
	# The window's own dim (the nearest full-screen ColorRect drawn before it) gets darker, so the window under it recedes.
	var node:Node=widget
	for i in range(3):
		var parent=node.get_parent()
		if parent==null:return
		var siblings=parent.get_children().slice(0,node.get_index());siblings.reverse()
		for sibling in siblings:
			if sibling is ColorRect and sibling.size.x>=widget.size.x:
				sibling.color.a=maxf(sibling.color.a,STACK_DIM);return
		if parent is ColorRect:parent.color.a=maxf(parent.color.a,STACK_DIM);return
		node=parent
## Notification markers (design system). One meaning per colour, the same in 2D and in the world:
## news — something new not yet seen; ready — an action is affordable now; goal — where to go next.
const NOTICE={"news":Color("ff6b57"),"ready":Color("8fe895"),"goal":Color("f1cf55")}
## Badge on a control: a dot (or a pill with a count) at the top-right corner, or at the trailing edge of a list row.
static func badge(parent:Control,kind:="news",count:=0,place:="corner")->Panel:
	var old=parent.get_node_or_null("Badge")
	if old:old.get_parent().remove_child(old);old.queue_free()
	var dot=Panel.new();dot.name="Badge";parent.add_child(dot);dot.mouse_filter=Control.MOUSE_FILTER_IGNORE;dot.z_index=1
	# Plain dot, no outline (T-087).
	var s=StyleBoxFlat.new();s.bg_color=NOTICE.get(kind,NOTICE.news);s.set_corner_radius_all(10);s.anti_aliasing=true
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
	var inline=preload("res://scripts/ui/currency_icons.gd").new();widget.add_child(inline);inline.fit(widget)
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
	var inline=preload("res://scripts/ui/currency_icons.gd").new();widget.add_child(inline);inline.fit(widget)
	if text=="Выбрать":widget.add_to_group("reward_choice")
	return widget

## Button text that does not fit (T-198): the font size stays, the text runs to the right edge (minus `reserve`
## for a notice dot) and fades out there; the full name is the hint. Text that fits is left as it is.
static func fade_text(button:Button,source:String,reserve:=0.0):
	var old=button.get_node_or_null("FadeText")
	if old:button.remove_child(old);old.queue_free()
	Texts.set_text(button,source)
	var box:StyleBox=button.get_theme_stylebox("normal")
	var start=box.get_margin(SIDE_LEFT)
	if button.icon:start+=float(button.get_theme_constant("icon_max_width") if button.expand_icon else button.icon.get_width())+button.get_theme_constant("h_separation")
	var room=button.size.x-start-box.get_margin(SIDE_RIGHT)-reserve
	var font=button.get_theme_font("font");var fs=button.get_theme_font_size("font_size")
	if room<=0 or font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x<=room:return
	var full=button.text;button.text="";button.tooltip_text=full
	var label=Label.new();label.name="FadeText";button.add_child(label);label.text=full;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",fs);label.add_theme_color_override("font_color",button.get_theme_color("font_color"))
	label.position=Vector2(start,0);label.size=Vector2(room,button.size.y);label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.clip_text=true
	var material=ShaderMaterial.new();material.shader=preload("res://shaders/ui/fade_edge.gdshader");label.material=material
	material.set_shader_parameter("width",room);material.set_shader_parameter("fade",minf(32.0,room*.3))
## Icon right beside the text, the pair centred in the button (T-240): Godot keeps a left icon at the edge.
static func icon_beside_text(button:Button):
	var place=func():
		if not is_instance_valid(button) or button.icon==null:return
		var font=button.get_theme_font("font");var fs=button.get_theme_font_size("font_size")
		var icon_w=float(button.get_theme_constant("icon_max_width")) if button.expand_icon else float(button.icon.get_width())
		var total=icon_w+button.get_theme_constant("h_separation")+font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
		var left=maxf(8.0,floorf((button.size.x-total)*.5))
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
		for state in ["normal","hover","pressed","focus","disabled","hover_pressed"]:
			if not button.has_theme_stylebox(state):continue
			var box:StyleBox=button.get_theme_stylebox(state).duplicate();box.content_margin_left=left;box.content_margin_right=8
			button.add_theme_stylebox_override(state,box)
	place.call();button.resized.connect(place)
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
	if trim_cache.has(key):
		var cached:Texture2D=trim_cache[key]
		return cached
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
## Content navigation has object art; small actions (close, arrows, pause…) remain line glyphs.
const CONTENT_ICONS=["inventory","fighter","quests","notifications","guide","base","build","merchant","slot_machine","playlist","folder"]
const CONTENT_SYMBOLS={"medkit":"medkit","blueprint":"blueprint","token":"token","vehicle":"jeep","rare":"clover_casing","legendary":"trophy"}
static func is_drawn_icon(texture:Texture2D)->bool:
	if texture is AtlasTexture:texture=texture.atlas
	return texture!=null and texture.resource_path.ends_with(".png")
static func interface_icon(id:String)->Texture2D:
	if id in CONTENT_ICONS:return trimmed(load("res://assets/ui/content_icons/"+id+".png"))
	if CONTENT_SYMBOLS.has(id):return trimmed(load(IconKit.ROOT+CONTENT_SYMBOLS[id]+".png"))
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
	mark_h_tabs(result,tabs.map(func(t):return str(t[0])).find(active))
	return result
## Horizontal tab rows answer Q / E out of battle (T-178): every row registers its buttons in order.
static func mark_h_tabs(buttons:Array,active:int):
	var row=str(Time.get_ticks_usec())+str(randi())
	for i in range(buttons.size()):
		buttons[i].add_to_group("h_tab");buttons[i].set_meta("h_row",row);buttons[i].set_meta("h_index",i);buttons[i].set_meta("h_active",i==active)
## Q / E: press the next / previous tab of the first visible horizontal row under `root`. True if one moved.
static func cycle_h_tabs(root:Node,step:int)->bool:
	var rows:Dictionary={}
	for b in root.get_tree().get_nodes_in_group("h_tab"):
		if b is Button and b.is_visible_in_tree() and root.is_ancestor_of(b) and not b.is_queued_for_deletion():
			var key=str(b.get_meta("h_row"))
			if not rows.has(key):rows[key]=[]
			rows[key].append(b)
	if rows.is_empty():return false
	var row:Array=rows.values()[0];row.sort_custom(func(a,b):return int(a.get_meta("h_index"))<int(b.get_meta("h_index")))
	var at=0
	for b in row:
		if b.get_meta("h_active",false):at=int(b.get_meta("h_index"))
	var next=row[posmod(at+step,row.size())]
	if next.disabled:return false
	next.pressed.emit();return true
## Q / E keys as a tab step (-1, +1, 0): out of battle only, never while typing.
static func tab_step(event:InputEvent)->int:
	if not (event is InputEventKey or event is InputEventAction) or not event.pressed or event.is_echo():return 0
	var focus=Engine.get_main_loop().root.gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:return 0
	if event.is_action_pressed("class_ability"):return -1
	if event.is_action_pressed("interact"):return 1
	return 0

## Unique artwork (cozy_ui_2026): explicit keys "upgrades/<id>", "stats/<id>", "abilities/<id>",
## "headquarters/<id>", "garage/<vehicle>_<branch>". Looked up before any alias folding; a missing file
## falls back to the old lookup by the bare id, so semantic ids never have to change for graphics.
const ART_GROUPS=["upgrades","stats","abilities","headquarters","garage","pickups","weapons"]
static var icon_cache:Dictionary={}
## Memoised: several call sites refresh icons every frame; disk lookups happen once per id and set.
static func icon_texture(id:String)->Texture2D:
	if id==LootCatalog.PAWS:id="upgrade/damage"  # bare paws: the «Сила» glove
	var key=Illustrations.current()+"|"+id
	if not icon_cache.has(key):
		# Drawn symbols (data/icon_kit.json) first; everything else goes through the old lookup.
		var texture=IconKit.symbol(id) if IconKit.has(id) else icon_lookup(id)
		icon_cache[key]=texture
	return icon_cache[key]
static func icon_lookup(id:String)->Texture2D:
	if id in CONTENT_ICONS:return interface_icon(id)
	# Legendary rules keep their own golden pictures; a bare id (encyclopedia) finds them too.
	if id.begins_with("legend_"):id="upgrades/"+id
	# Station upgrade art (T-056): drawn GPT icons for the hub stations' general rows.
	if id.begins_with("upgrade/") and ResourceLoader.exists("res://assets/ui/upgrade_icons/"+id.get_slice("/",1)+".png"):return load("res://assets/ui/upgrade_icons/"+id.get_slice("/",1)+".png")
	if id.begins_with("building/") and ResourceLoader.exists("res://assets/ui/buildings/"+id.get_slice("/",1)+".png"):return load("res://assets/ui/buildings/"+id.get_slice("/",1)+".png")
	if "/" in id:
		if id.get_slice("/",0) in ART_GROUPS:
			var art=Illustrations.texture("res://assets/icons/"+id+".png")
			if art:return art
		id=id.get_slice("/",1)
	# Weapons and field bonuses have family art in the illustration set (icon families v1); other sets fall back.
	if id in Game.LOOT.WEAPONS or id in LootCatalog.BONUSES:
		var family_art=Illustrations.texture("res://assets/icons/"+("weapons/" if id in Game.LOOT.WEAPONS else "pickups/")+id+".png")
		if family_art:return family_art
	if id in ["debug","lock","repeat","refresh","inventory","fighter","quests","notifications","music","settings","guide","base","about"]:return interface_icon(id)
	var sections=["inventory","fighter","quests","notifications","music","settings","guide","base","workshop"]
	if id in sections:
		var atlas=AtlasTexture.new();atlas.atlas=load("res://assets/icons/field_v1/sections.png")
		var cell=atlas.atlas.get_size()/3.0;var index=sections.find(id)
		atlas.region=Rect2(Vector2(index%3,index/3)*cell,cell);return atlas
	if id=="dynamite":
		# Family art lives in the GPT set only; other sets show the mine.
		var dynamite=Illustrations.texture("res://assets/icons/abilities/dynamite.png")
		if dynamite:return dynamite
		id="mine"
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
	rich.add_theme_font_override("normal_font",field_font());rich.add_theme_font_override("bold_font",bold_font())
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

## Typography (design system): Inter SemiBold for all interface text, Inter Bold for emphasis inside
## rich text, Rubik 720 in capitals for headings (about 10–15% of the text: hub call to action, page and
## screen titles, modal titles, card names, phase announcements, run results). Minimal punctuation: no
## full stop after labels, buttons and single-sentence hints.
const FONT_BASE=preload("res://assets/ui/fonts/inter_semibold.tres")
const FONT_REGULAR=preload("res://assets/ui/fonts/inter_regular.tres")
const FONT_BOLD=preload("res://assets/ui/fonts/inter_bold.tres")
const FONT_ACCENT=preload("res://assets/ui/fonts/accent.tres")
static func field_font()->Font:return FONT_BASE
static func bold_font()->Font:return FONT_BOLD
static func accent_font()->Font:return FONT_ACCENT
## Switches a label or button to the heading face. Headings are set in capitals by Texts (after
## translation and sentence case), so re-rendered and translated text stays in capitals too.
static func accent(control:Control,font_size:=0)->Control:
	control.add_theme_font_override("font",FONT_ACCENT)
	control.set_meta("accent_caps",true)
	if control.has_meta("text_source") and not control is RichTextLabel:Texts.set_text(control,str(control.get_meta("text_source")))
	if control is RichTextLabel:control.add_theme_font_override("normal_font",FONT_ACCENT)
	if font_size>0:control.add_theme_font_size_override("normal_font_size" if control is RichTextLabel else "font_size",font_size)
	return control

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
