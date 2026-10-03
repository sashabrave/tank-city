extends Node3D
## Weapon crate (RoomLayout spot, author 2026-10-03) in every upgrade room and at the merchant: an open army crate
## with three random guns. Each offer has its own rarity (better the farther along the map) and rolled bonuses
## (damage, fire rate); it is bought for alloy and goes into the backpack as a weapon item (Backpack.add_weapon),
## where it can be dragged into the weapon slot. Offers are rolled once per room on their own generator.
## Price in alloy per rarity.
const PRICES:=[40,70,110,170]
## Odds per rarity near the start and deep in the map (lerped by the room's place on the route).
const ODDS_NEAR:=[.6,.28,.1,.02]
const ODDS_DEEP:=[.34,.38,.2,.08]
## Rolled bonuses per rarity: [key, label, min, max] as shares (0.1 = +10 %).
const STATS:={"damage":["Урон",[[.0,.05],[.05,.12],[.12,.2],[.2,.3]]],"fire":["Темп",[[.0,.04],[.04,.09],[.09,.15],[.15,.22]]]}
var room:Node3D
var arena
var modal:Control
var offers:Array=[]
static func place(parent:Node3D,context,at:Vector3)->Node3D:
	var locker=load("res://scripts/weapon_locker.gd").new();locker.room=parent;locker.arena=context;locker.position=at;parent.add_child(locker);return locker
func _ready():
	name="WeaponLocker"
	var olive=Color("59603f")
	# Open army crate on two skids, lid propped up behind, three guns lying on the straw.
	Visuals.box(self,Vector3(0,.12,0),Vector3(1.2,.12,.62),olive.darkened(.3),"wood")
	Visuals.box(self,Vector3(0,.45,0),Vector3(1.1,.55,.56),olive,"paint")
	Visuals.box(self,Vector3(0,.7,-.36),Vector3(1.1,.06,.5),olive.darkened(.1),"paint").rotation.x=-1.1
	Visuals.box(self,Vector3(0,.72,0),Vector3(1.0,.04,.46),Color("c8b27a"),"fabric")
	for dx in [-.5,.5]:Visuals.box(self,Vector3(dx,.45,.29),Vector3(.08,.5,.03),Color("6c777b"),"steel")
	for i in range(3):
		var gun=Visuals.model("weapon_"+["rifle","shotgun","smg"][i],self,Vector3(-.3+i*.3,.78,0));gun.rotation=Vector3(0,PI*.5,PI*.5);gun.scale=Vector3.ONE*.7
	Visuals.label3d(self,"Оружие · E",Vector3(0,1.4,0),Color("fff0ce"),24)
	if room:preload("res://scripts/interaction_prompt.gd").attach(self,room,"Оружие",Vector3.ZERO,1.4)
	if arena:offers=roll_offers()
func near(avatar:Node3D)->bool:return avatar.global_position.distance_to(global_position)<1.4

## Three offers {id, rarity, stats, price, sold} from the unlocked weapons, rolled once for this room.
func roll_offers()->Array:
	var index=int(room.get("index")) if room and "index" in room else int(arena.room_index)
	var rng=RandomNumberGenerator.new();rng.seed=hash([int(arena.run_seed),index,"weapon_crate"])
	var pool=Game.LOOT.WEAPONS.keys().filter(func(id):return id in Game.weapon_unlocks)
	if pool.is_empty():pool=[str(arena.weapon)]
	var depth=clampf(float(Campaign.progress_index(index))/maxf(1.0,Campaign.SIZES.size()-1),0.0,1.0)
	var result=[]
	for i in range(3):
		var id=str(pool[rng.randi_range(0,pool.size()-1)])
		var rarity=pick_rarity(rng,depth)
		var stats={}
		for key in STATS:
			var span:Array=STATS[key][1][rarity]
			stats[key]=snappedf(rng.randf_range(span[0],span[1]),.01)
		result.append({"id":id,"rarity":rarity,"stats":stats,"price":PRICES[rarity],"sold":false})
	return result
static func pick_rarity(rng:RandomNumberGenerator,depth:float)->int:
	var roll=rng.randf();var acc=0.0
	for r in range(4):
		acc+=lerpf(ODDS_NEAR[r],ODDS_DEEP[r],depth)
		if roll<acc:return r
	return 3
static func describe(offer:Dictionary)->String:
	var parts=[]
	for key in STATS:
		var value=float(offer.stats.get(key,0.0))
		if value>0.0:parts.append("%s +%d%%" % [Texts.render(STATS[key][0]),roundi(value*100)])
	return " · ".join(parts) if not parts.is_empty() else Texts.render("Без прибавок")

## Buys an offer into the backpack. Returns "" on success or the reason it did not happen.
func buy(i:int)->String:
	if i<0 or i>=offers.size():return "Нет такого ствола"
	var offer:Dictionary=offers[i]
	if offer.sold:return "Уже куплено"
	if Game.credits<int(offer.price):return "Не хватает сплава"
	var item={"id":offer.id,"rarity":offer.rarity,"stats":offer.stats.duplicate()}
	var added:bool=Backpack.add_weapon(arena,item)
	if not added:return "Рюкзак полон"
	Game.credits-=int(offer.price);Game.save_progress();offer.sold=true
	Game.sound("weapon_equip",room if room else self)
	return ""

func use(ui_root:Control,done:Callable):open(ui_root,done)
func open(ui_root:Control,done:Callable):
	if offers.is_empty():offers=roll_offers()
	modal=Control.new();modal.name="WeaponLockerMenu";ui_root.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_to_group("selection_scope")
	var shade=ColorRect.new();modal.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.5)
	var size=Vector2(640,130+offers.size()*92);var panel=UiKit.glass(modal,((ui_root.get_viewport_rect().size-size)*.5).round(),size)
	UiKit.label(panel,"Ящик с оружием",Vector2(24,16),Vector2(400,34),24)
	UiKit.label(panel,"Ствол уходит в рюкзак — перетащи его в слот оружия",Vector2(24,52),Vector2(590,22),14,UiKit.MUTED)
	var close=func():
		if is_instance_valid(modal):modal.queue_free()
		modal=null;done.call()
	for i in range(offers.size()):
		var offer:Dictionary=offers[i];var color=Color(LootCatalog.RARITY_COLORS[clampi(int(offer.rarity),0,3)])
		var row=Panel.new();panel.add_child(row);row.position=Vector2(24,88+i*92);row.size=Vector2(size.x-48,80);row.name="Offer%d" % i
		row.add_theme_stylebox_override("panel",UiKit.style(Color(color,.12),12,Color(color,.7)))
		var icon=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		row.add_child(icon);icon.texture=UiKit.trimmed(UiKit.icon_texture(offer.id));icon.position=Vector2(10,8);icon.size=Vector2(110,64)
		UiKit.label(row,Game.LOOT.WEAPONS[offer.id].name,Vector2(132,8),Vector2(260,28),19)
		UiKit.label(row,Texts.render(LootCatalog.RARITY_NAMES[int(offer.rarity)])+" · "+describe(offer),Vector2(132,40),Vector2(300,24),14,color.lightened(.25))
		var b=UiKit.button(row,"Куплено" if offer.sold else "%d ◈" % int(offer.price),Vector2(row.size.x-150,16),Vector2(136,48),func():
			var reason=buy(i)
			if reason!="" and is_instance_valid(arena):arena.toast(Texts.render(reason))
			if is_instance_valid(modal):modal.queue_free();modal=null;open(ui_root,done),true)
		b.name="Buy%d" % i;b.disabled=offer.sold or Game.credits<int(offer.price)
	var x=UiKit.button(panel,"",Vector2(size.x-66,14),Vector2(44,40),close);x.icon=UiKit.interface_icon("close");x.expand_icon=true;x.add_theme_constant_override("icon_max_width",18)
