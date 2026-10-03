extends RefCounted
## Shared reward styling; geometry remains editable in the choice scenes.
static func create(parent:Node,pos:Vector2,dimensions:Vector2,data:Dictionary,choose:Callable,layout="upgrade")->Panel:
	var card=load("res://scenes/ui/choice_"+layout+".tscn").instantiate()
	parent.add_child(card);card.position=pos;card.size=dimensions
	configure(card,data,choose)
	return card
static func configure(card:Panel,data:Dictionary,choose:Callable):
	card.set_meta("reward_tier",LootCatalog.RARITY_COLORS.find(data.color.to_html(false)))
	var style=card.get_theme_stylebox("panel").duplicate()
	style.bg_color=Color("232c29").lerp(data.color,.10);style.border_color=data.color.darkened(.25);card.add_theme_stylebox_override("panel",style)
	if int(data.get("tier",0))>=2:style.shadow_color=Color(data.color,.16 if int(data.tier)==2 else .26);style.shadow_size=10 if int(data.tier)==2 else 16
	card.set_meta("idle_border",style)
	var active=style.duplicate()
	active.set_border_width_all(3);active.border_color=data.color
	active.shadow_color=Color(data.color,.18);active.shadow_size=8
	card.set_meta("selected_border",active)
	var category=data.get("category","")
	if category=="":category="Способность" if data.icon in AbilityCatalog.DATA else "Транспорт" if data.icon in ["vehicle","apc","tank","buggy"] else "Бонус" if data.icon in Game.LOOT.BONUSES else "Усиление"
	card.get_node("Rarity").text=category+"\n"+data.heading
	card.get_node("Rarity").add_theme_font_size_override("font_size",12)
	card.get_node("Rarity").add_theme_color_override("font_color",data.color)
	var stripe=ColorRect.new();stripe.name="CategoryStripe";card.add_child(stripe)
	stripe.mouse_filter=Control.MOUSE_FILTER_IGNORE;stripe.position=Vector2(0,16);stripe.size=Vector2(9,48);stripe.color=data.color
	var silhouette=TextureRect.new();silhouette.name="CategoryIcon";card.add_child(silhouette)
	var symbol={"Огневая мощь":"weapon","Живучесть":"hero","Спецпатроны":"bonus","Разведка":"ability","Тыл":"hq","Герой":"hero","Штаб":"hq","Оружие":"weapon","Способность":"ability","Транспорт":"vehicle","Чертёж":"blueprint","Бонус":"bonus","Тактика":"hero"}.get(category,"trophy")
	# Drawn category symbol (data/icon_kit.json «category/…»); the line silhouette tinted by rarity is the fallback.
	var drawn=IconKit.symbol("category/"+symbol)
	silhouette.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;silhouette.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	silhouette.texture=drawn if drawn else load("res://assets/ui/reward_categories/"+symbol+".svg")
	silhouette.position=Vector2(18,18) if drawn else Vector2(20,20);silhouette.size=Vector2(40,40) if drawn else Vector2(36,36)
	if not drawn:silhouette.modulate=data.color
	silhouette.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var frame=Panel.new();frame.name="IconFrame";card.add_child(frame);card.move_child(frame,0)
	frame.position=Vector2(208,12);frame.size=Vector2(62,62);frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var frame_style=UiKit.style(Color("232c29").lerp(data.color,.19),12,data.color.darkened(.12))
	frame_style.set_border_width_all(2);frame.add_theme_stylebox_override("panel",frame_style)
	card.get_node("Title").text=data.title
	var old=card.get_node_or_null("NumericDescription")
	if old:old.get_parent().remove_child(old);old.queue_free()
	card.get_node("Description").show()
	if data.icon in ["pressure","intercept","weapon_intercept"] and not "{{pressure.description}}" in data.detail:
		data=data.duplicate();data.detail+="\n{{pressure.description}}"
	card.get_node("Description").text=data.detail
	if "→" in data.detail:UiKit.numeric_description(card.get_node("Description"),data.detail)
	card.get_node("Icon").texture=UiKit.trimmed(UiKit.icon_texture(data.get("art_key",data.icon)))  # art_key: picture only; data.icon stays semantic
	var button=card.get_node("ChooseButton")
	Texts.set_text(button,data.get("button","Выбрать"));button.disabled=data.get("disabled",false)
	button.mouse_entered.connect(func():
		if not button.disabled:button.grab_focus())
	button.add_to_group("reward_choice");button.pressed.connect(choose)
	if data.has("family"):minimal(card,data)
## Run upgrade cards, mobile style: the whole card is the button; rarity reads from the border, glow and
## 1-4 corner pips (no word); the family is a small chip; big icon, title and the old→new line in the middle.
const FAMILY_COLORS={"fire":Color("e8784a"),"survival":Color("7cc27a"),"ammo":Color("e0b44f"),"recon":Color("5fc7c0"),"logistics":Color("c4a878")}
static func minimal(card:Panel,data:Dictionary):
	for key in ["Rarity","CategoryStripe","CategoryIcon","IconFrame"]:
		var node=card.get_node_or_null(key)
		if node:node.hide()
	var width=card.size.x if card.size.x>0 else 280.0
	var icon:TextureRect=card.get_node("Icon");icon.position=Vector2(width*.5-56,46);icon.size=Vector2(112,112)
	var chip=Panel.new();chip.name="FamilyChip";card.add_child(chip);chip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var family_color:Color=FAMILY_COLORS.get(data.family,UiKit.MUTED)
	chip.add_theme_stylebox_override("panel",UiKit.style(Color(family_color,.16),10,Color(family_color,.5)))
	var chip_text=UiKit.label(chip,data.category,Vector2(22,2),Vector2(160,20),12,family_color.lightened(.2))
	var dot=Panel.new();chip.add_child(dot);dot.position=Vector2(9,8);dot.size=Vector2(7,7);dot.add_theme_stylebox_override("panel",UiKit.style(family_color,4,family_color))
	chip.position=Vector2(14,14);chip.size=Vector2(chip_text.get_theme_font("font").get_string_size(Texts.render(data.category),HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+32,24)
	# One drawn symbol, no frame around it: rarity reads from the card border and its tinted background.
	var tier=clampi(int(data.get("tier",0)),0,3)
	var full=UiKit.icon_texture(data.get("art_key",data.icon))
	if full:icon.texture=UiKit.trimmed(full)
	icon.position=Vector2(width*.5-62,50);icon.size=Vector2(124,124)
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	rarity_glow(card,data.color,tier)
	var owned=mini(3,int(data.get("stacks",0)))
	if owned>0:
		var chevrons=TextureRect.new();chevrons.name="PowerChevrons";icon.add_child(chevrons);chevrons.mouse_filter=Control.MOUSE_FILTER_IGNORE
		chevrons.texture=load("res://assets/ui/icon_frames/power_%d.png" % owned);chevrons.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;chevrons.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chevrons.position=Vector2(0,18);chevrons.size=icon.size
		chevrons.tooltip_text=Texts.render("Уже взято: %d") % owned
	var title:Label=card.get_node("Title");title.position=Vector2(16,196);title.size=Vector2(width-32,34);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	for key in ["Description","NumericDescription"]:
		var body=card.get_node_or_null(key)
		if body:body.position=Vector2(18,240);body.size=Vector2(width-36,card.size.y-254)
		if body is Label:body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var rich=card.get_node_or_null("NumericDescription")
	if rich is RichTextLabel:rich.text="[center]"+rich.text+"[/center]"
	if not data.get("rows",[]).is_empty():table(card,data,width,family_color)
	balance(card)
	var button:Button=card.get_node("ChooseButton");button.position=Vector2.ZERO;button.size=card.size;Texts.set_text(button,"")
	var clear=StyleBoxEmpty.new()
	for key in ["normal","hover","pressed","focus","disabled"]:button.add_theme_stylebox_override(key,clear)
	card.move_child(button,card.get_child_count()-1)

## Card background tinted towards the rarity: soft gradient, light pool behind the icon, a rare random glint
## (shaders/ui/rarity_card.gdshader). Sits inside the border; the glint stops with «Анимации интерфейса» off.
static func rarity_glow(card:Panel,color:Color,tier:int):
	var style:StyleBox=card.get_theme_stylebox("panel")
	var border=style.border_width_top if style is StyleBoxFlat else 2
	var corner=style.corner_radius_top_left if style is StyleBoxFlat else 14
	var glow=ColorRect.new();glow.name="RarityGlow";glow.mouse_filter=Control.MOUSE_FILTER_IGNORE
	card.add_child(glow);card.move_child(glow,0)
	var width=card.size.x if card.size.x>0 else 280.0
	glow.position=Vector2.ONE*border;glow.size=Vector2(width,card.size.y)-Vector2.ONE*border*2
	var material=ShaderMaterial.new();material.shader=preload("res://shaders/ui/rarity_card.gdshader")
	material.set_shader_parameter("tint",color.lightened(.1))
	material.set_shader_parameter("strength",[.12,.18,.22,.26][tier])
	material.set_shader_parameter("rect_size",glow.size)
	material.set_shader_parameter("radius",maxf(0.0,corner-border))
	material.set_shader_parameter("seed",randf()*10.0)
	material.set_shader_parameter("motion",1.0 if UiKit.motion_enabled() else 0.0)
	glow.material=material

## Change view, centred on an 8 px rhythm: the change in large type, below it the parameter with the old
## value struck through and the resulting one, then one short sentence. The long description is the tooltip.
static func table(card:Panel,data:Dictionary,width:float,accent:Color):
	for key in ["Description","NumericDescription"]:
		var body=card.get_node_or_null(key)
		if body:body.hide()
	var y=240.0
	# Two or more rows (ammo items with several rolled values) get a tighter rhythm so the note still fits.
	var dense=data.rows.size()>=2;var step=(44.0 if data.has("swap") else 50.0) if dense else 80.0
	for row in data.rows:
		var value=UiKit.label(card,str(row[0]),Vector2(16,y),Vector2(width-32,28 if dense else 36),21 if dense else 28,accent.lightened(.25));value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;value.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;value.name="RowValue"
		var compare=RichTextLabel.new();compare.name="RowParam";card.add_child(compare);compare.position=Vector2(16,y+(27 if dense else 42));compare.size=Vector2(width-32,24)
		compare.bbcode_enabled=true;compare.scroll_active=false;compare.fit_content=true;compare.mouse_filter=Control.MOUSE_FILTER_IGNORE;compare.autowrap_mode=TextServer.AUTOWRAP_OFF
		compare.add_theme_font_override("normal_font",UiKit.field_font());compare.add_theme_font_override("bold_font",UiKit.bold_font());compare.add_theme_font_size_override("normal_font_size",15);compare.add_theme_font_size_override("bold_font_size",15)
		compare.add_theme_color_override("default_color",UiKit.MUTED)
		var name=Texts.render(str(row[1]));name=name.left(1).to_upper()+name.substr(1)
		var text="[center]%s" % name
		if row.size()>=4:text+="   [color=#8d9589][s]%s[/s][/color]  →  [b][color=#f1eedb]%s[/color][/b]" % [Texts.render(str(row[2])),Texts.render(str(row[3]))]
		compare.text=text+"[/center]"
		y+=step
	# Ammo cards (T-127): a strip «old ammo → new ammo» with their icons instead of words.
	if data.has("swap"):
		swap_strip(card,data.swap,y,width);y+=40
		if data.swap.has("rest"):data=data.duplicate();data.short=data.swap.rest
		else:return
	var short=str(data.get("short","")).trim_suffix(".")
	if short!="":
		var note=UiKit.label(card,short,Vector2(22,y),Vector2(width-44,maxf(44,card.size.y-y-16)),14,UiKit.MUTED);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;note.vertical_alignment=VERTICAL_ALIGNMENT_TOP;note.name="ShortNote"
		note.add_theme_constant_override("line_spacing",2)
	card.tooltip_text=Texts.render(str(data.get("detail","")))
## «old → new» strip: small framed icons of both ammo and an arrow; «Зарядит» shows an empty slot on the left.
static func swap_strip(card:Panel,swap:Dictionary,y:float,width:float):
	var strip=HBoxContainer.new();strip.name="SwapStrip";card.add_child(strip);strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	strip.add_theme_constant_override("separation",8);strip.alignment=BoxContainer.ALIGNMENT_CENTER;strip.position=Vector2(12,y);strip.size=Vector2(width-24,32)
	for part in [swap.get("from",{}),{"arrow":true},swap.get("to",{})]:
		if part.get("arrow",false):
			var arrow=Label.new();strip.add_child(arrow);arrow.text="→";arrow.add_theme_font_size_override("font_size",18);arrow.add_theme_color_override("font_color",UiKit.ORANGE);continue
		var box=Panel.new();strip.add_child(box);box.custom_minimum_size=Vector2(30,30);box.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var color=Color(str(part.get("color","6f7a70")))
		box.add_theme_stylebox_override("panel",UiKit.style(Color(color,.18),7,Color(color,.8)))
		var tex=part.get("texture") as Texture2D
		if tex:
			var art=TextureRect.new();box.add_child(art);art.texture=tex;art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.position=Vector2(3,3);art.size=Vector2(24,24);art.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var name=Label.new();strip.add_child(name);name.text=Texts.render(str(part.get("name","—")));name.add_theme_font_size_override("font_size",12);name.add_theme_color_override("font_color",color.lightened(.3))
		# Both names share what is left after the two icons and the arrow; long ones end with «…».
		name.clip_text=true;name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;name.custom_minimum_size.x=floorf((width-24-2*30-30-4*8)*.5)
## Vertical balance: the block from the icon to the last line sits in the middle of the space under the chip.
static func balance(card:Panel):
	var parts:Array=[card.get_node("Icon"),card.get_node("Title")]
	for child in card.get_children():
		if str(child.name).begins_with("RowValue") or str(child.name).begins_with("RowParam") or child.name in ["ShortNote","Description","NumericDescription"]:
			if child.visible:parts.append(child)
	var top=INF;var bottom=0.0
	for part in parts:
		var height=part.size.y
		if part is Label and part.autowrap_mode!=TextServer.AUTOWRAP_OFF:
			height=part.get_theme_font("font").get_multiline_string_size(part.text,HORIZONTAL_ALIGNMENT_LEFT,part.size.x,part.get_theme_font_size("font_size")).y
		elif part is RichTextLabel and not part.fit_content:height=part.get_content_height()
		top=minf(top,part.position.y);bottom=maxf(bottom,part.position.y+height)
	var area_top=44.0;var area_bottom=card.size.y-20.0
	var shift=floorf(((area_bottom-area_top)-(bottom-top))*.5+area_top-top)
	# Cards in one row share the smallest shift, so titles and values stay on common lines.
	card.set_meta("balance_shift",maxf(0.0,shift));card.set_meta("balance_parts",parts)
	var row=card.get_parent()
	if row and not row.has_meta("balance_pending"):row.set_meta("balance_pending",true);align_row.call_deferred(row)
static func align_row(row:Node):
	if not is_instance_valid(row):return
	row.remove_meta("balance_pending")
	var cards=row.get_children().filter(func(c):return c.has_meta("balance_shift"))
	if cards.is_empty():return
	var shift=cards.map(func(c):return float(c.get_meta("balance_shift"))).min()
	for card in cards:
		for part in card.get_meta("balance_parts"):
			if is_instance_valid(part):part.position.y+=shift
		card.remove_meta("balance_shift");card.remove_meta("balance_parts")
