extends Node3D
## Ammo vending machine (T-116) at the merchant and in every upgrade room: tokens buy a random ammo item that
## fits the weapon in hand; its rarity follows luck (the same roll as cards). The result shows how it compares
## with the loaded ammo: «Зарядить» puts it in a slot (the old one goes to the backpack), «В рюкзак» keeps it.
const PRICE=4
var room:Node3D
var arena
var modal:Control
static func place(parent:Node3D,context,at:Vector3)->Node3D:
	var vendor=load("res://scripts/ammo_vendor.gd").new();vendor.room=parent;vendor.arena=context;vendor.position=at;parent.add_child(vendor);return vendor
func _ready():
	name="AmmoVendor"
	var steel=Color("4f5a5e");var brass=Color("d9a441")
	Visuals.box(self,Vector3(0,.85,0),Vector3(.8,1.7,.6),steel)
	Visuals.box(self,Vector3(0,1.25,.31),Vector3(.62,.62,.03),Color("1d2326"))
	# Cartridges standing behind the glass, one per ammo colour.
	var colors=["ff8a3d","86daec","f1cf55","9fe6ff","ff5a4a"]
	for i in range(colors.size()):
		var round=Visuals.box(self,Vector3(-.22+i*.11,1.2,.29),Vector3(.06,.24,.06),brass);var tip=Visuals.box(self,Vector3(-.22+i*.11,1.36,.29),Vector3(.05,.08,.05),Color(colors[i]))
		tip.material_override=Visuals.material(Color(colors[i]),true)
	Visuals.box(self,Vector3(0,.55,.32),Vector3(.5,.14,.04),Color("2a3033"))
	Visuals.box(self,Vector3(0,1.75,0),Vector3(.86,.12,.66),brass)
	var glow=OmniLight3D.new();add_child(glow);glow.position=Vector3(0,1.3,.7);glow.light_color=Color("9fe6ff");glow.light_energy=.5;glow.omni_range=2.0
	Visuals.label3d(self,"Патроны · %d жетона · E" % PRICE,Vector3(0,2.1,0),Color("fff0ce"),22)
	preload("res://scripts/interaction_prompt.gd").attach(self,room,"Патронный автомат",Vector3.ZERO,1.4)
func near(avatar:Node3D)->bool:return avatar.global_position.distance_to(global_position)<1.4
## Rolls one item for the weapon in hand; empty when the run has no tokens.
func buy()->Dictionary:
	if arena.run.tokens<PRICE:return {}
	arena.run.tokens-=PRICE
	var types=Ammo.TYPES.filter(func(t):return Ammo.fits(t,str(arena.weapon)))
	var type=types[arena.run.combat_rng.randi_range(0,types.size()-1)]
	var tier=RunUpgrades.roll_tier(arena)
	Game.progression.event("slot_play")
	return Ammo.roll(type,tier,arena.run.combat_rng.randi())
func open(ui_root:Control,done:Callable):
	var close=func():
		if is_instance_valid(modal):modal.queue_free()
		modal=null;done.call()
	if arena.run.tokens<PRICE:
		Game.sound("ui_denied",room);arena.toast(Texts.render("Автомату нужно %d жетона") % PRICE);done.call();return
	Ammo.ensure(arena.run,str(arena.weapon))
	var item=buy();Game.sound("collect_token",room)
	modal=Control.new();modal.name="AmmoVendorResult";ui_root.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_to_group("selection_scope")
	var shade=ColorRect.new();modal.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.5)
	var same=arena.run.ammo_slots.filter(func(s):return s is Dictionary and s.type==item.type)
	var old:Dictionary=same[0] if not same.is_empty() else Ammo.replacing(arena.run)
	var rows=Ammo.compare_rows(item,old)
	var size=Vector2(560,250+rows.size()*30);var panel=UiKit.glass(modal,((ui_root.get_viewport_rect().size-size)*.5).round(),size)
	var color=Color(LootCatalog.RARITY_COLORS[clampi(int(item.rarity),0,3)])
	UiKit.label(panel,Texts.render(Ammo.RARITY_NAMES[int(item.rarity)]).to_lower(),Vector2(24,16),Vector2(500,22),14,color)
	UiKit.label(panel,Texts.render(Ammo.NAMES[item.type]+" патроны"),Vector2(24,38),Vector2(500,34),24,Color(Ammo.COLORS[item.type]))
	var y=84.0
	for row in rows:
		UiKit.label(panel,str(row[1]).left(1).to_upper()+str(row[1]).substr(1),Vector2(24,y),Vector2(300,26),16)
		var value=UiKit.label(panel,"%s → %s" % [row[2],row[3]],Vector2(300,y),Vector2(236,26),16,UiKit.ORANGE if str(row[0]).begins_with("↑") else Color("ff8a7a") if str(row[0]).begins_with("↓") else UiKit.INK)
		value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;y+=30
	var extra=[]
	if float(item.damage)>0:extra.append(Texts.render("урон пули")+" +%d%%" % roundi(item.damage*100))
	if item.twist:extra.append(Texts.render(Ammo.TWISTS[item.type]))
	if not extra.is_empty():UiKit.label(panel," · ".join(extra),Vector2(24,y),Vector2(512,26),14,color);y+=30
	var note=(Texts.render("Заменит")+": "+Texts.render(Ammo.NAMES[old.type])) if not old.is_empty() else Texts.render("Свободный слот")
	UiKit.label(panel,note,Vector2(24,y+4),Vector2(512,22),13,UiKit.MUTED)
	var bag_button=UiKit.button(panel,"В рюкзак",Vector2(24,size.y-66),Vector2(250,48),func():
		arena.run.ammo_bag.append(item);close.call())
	if Backpack.full(arena.run):bag_button.disabled=true;bag_button.tooltip_text=Texts.render("Рюкзак полон")
	var load_button=UiKit.button(panel,"Зарядить",Vector2(size.x-274,size.y-66),Vector2(250,48),func():
		var out=Ammo.load_item(arena.run,item)
		# Outside battle a full backpack still takes the swapped-out ammo (one over the limit until the next field).
		if not out.is_empty():arena.run.ammo_bag.append(out)
		Game.sound("weapon_equip",room);close.call(),true)
	load_button.grab_focus()
