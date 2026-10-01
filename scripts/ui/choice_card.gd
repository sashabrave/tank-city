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
	silhouette.texture=load("res://assets/ui/reward_categories/"+symbol+".svg")
	silhouette.position=Vector2(20,20);silhouette.size=Vector2(36,36);silhouette.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;silhouette.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	silhouette.modulate=data.color;silhouette.mouse_filter=Control.MOUSE_FILTER_IGNORE
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
const FAMILY_COLORS={"fire":Color("e8784a"),"survival":Color("7cc27a"),"ammo":Color("e0b44f"),"recon":Color("5fc7c0"),"logistics":Color("b7a8e6")}
static func minimal(card:Panel,data:Dictionary):
	for key in ["Rarity","CategoryStripe","CategoryIcon","IconFrame"]:
		var node=card.get_node_or_null(key)
		if node:node.hide()
	var width=card.size.x if card.size.x>0 else 280.0
	var icon:TextureRect=card.get_node("Icon");icon.position=Vector2(width*.5-46,44);icon.size=Vector2(92,92)
	var chip=Panel.new();chip.name="FamilyChip";card.add_child(chip);chip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var family_color:Color=FAMILY_COLORS.get(data.family,UiKit.MUTED)
	chip.add_theme_stylebox_override("panel",UiKit.style(Color(family_color,.16),10,Color(family_color,.5)))
	var chip_text=UiKit.label(chip,data.category,Vector2(22,2),Vector2(160,20),12,family_color.lightened(.2))
	var dot=Panel.new();chip.add_child(dot);dot.position=Vector2(9,8);dot.size=Vector2(7,7);dot.add_theme_stylebox_override("panel",UiKit.style(family_color,4,family_color))
	chip.position=Vector2(14,14);chip.size=Vector2(chip_text.get_theme_font("font").get_string_size(Texts.render(data.category),HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+32,24)
	var pips=preload("res://scripts/ui/pip_strip.gd").new();card.add_child(pips)
	var tier=int(data.get("tier",0));pips.set_state(tier+1,tier+1,-1);pips.modulate=data.color.lightened(.35);pips.position=Vector2(width-pips.size.x-16,23)
	var title:Label=card.get_node("Title");title.position=Vector2(16,146);title.size=Vector2(width-32,34);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for key in ["Description","NumericDescription"]:
		var body=card.get_node_or_null(key)
		if body:body.position=Vector2(18,186);body.size=Vector2(width-36,card.size.y-200)
		if body is Label:body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var rich=card.get_node_or_null("NumericDescription")
	if rich is RichTextLabel:rich.text="[center]"+rich.text+"[/center]"
	var button:Button=card.get_node("ChooseButton");button.position=Vector2.ZERO;button.size=card.size;Texts.set_text(button,"")
	var clear=StyleBoxEmpty.new()
	for key in ["normal","hover","pressed","focus","disabled"]:button.add_theme_stylebox_override(key,clear)
	card.move_child(button,card.get_child_count()-1)
