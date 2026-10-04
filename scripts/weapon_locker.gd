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
var prompt
var offers:Array=[]
## Gun shown when there are no offers (previews and tests).
var preview_gun:="rifle"
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
	if arena:offers=roll_offers()
	# One big gun on the straw (author, 3 Oct: three small ones read as litter) — the crate's first offer.
	var shown=str(offers[0].id) if not offers.is_empty() else preview_gun
	var gun=Visuals.model("weapon_"+shown,self,Vector3(0,.84,.02))
	if gun:lay_gun(gun,shown)
	# No sign over the crate (T-226): the prompt on approach names it and the cheapest price.
	if room:prompt=preload("res://scripts/interaction_prompt.gd").attach(self,room,"Ящик с оружием",Vector3.ZERO,1.4);refresh_prompt()
func near(avatar:Node3D)->bool:return avatar.global_position.distance_to(global_position)<1.4
## Lays the gun on the straw whatever axes its model uses: the longest side along the crate, the next one up, the
## flat side to the camera, leaning back a little; 0.9 of the crate's width long (handguns shorter), centred.
const GUN_LENGTH:={"pistol":.5,"smg":.7}
func lay_gun(gun:Node3D,gun_id:String):
	var local=Visuals.mesh_bounds(gun,gun.transform.affine_inverse());var size=local.size
	var axes=[0,1,2];axes.sort_custom(func(a,b):return size[a]>size[b])
	var images=[Vector3.RIGHT,Vector3.UP,Vector3.BACK];var columns=[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
	for k in range(3):columns[axes[k]]=images[k]
	var turn=Basis(columns[0],columns[1],columns[2])
	if turn.determinant()<0:columns[axes[2]]=-columns[axes[2]];turn=Basis(columns[0],columns[1],columns[2])
	gun.transform=Transform3D(Basis(Vector3.RIGHT,-.45)*turn*Basis.from_scale(Vector3.ONE*(float(GUN_LENGTH.get(gun_id,.9))/maxf(size[axes[0]],.05))),Vector3.ZERO)
	var placed=Visuals.mesh_bounds(gun,Transform3D.IDENTITY);var center=placed.get_center()
	gun.position=Vector3(-center.x,.74-placed.position.y,-center.z)

## Three offers {id, rarity, stats, price, sold} from the unlocked weapons, rolled once for this room.
func roll_offers()->Array:
	var index=int(room.get("index")) if room and "index" in room else int(arena.room_index)
	var rng=RandomNumberGenerator.new();rng.seed=hash([int(arena.run_seed),index,"weapon_crate"])
	var pool=Game.LOOT.gun_ids().filter(func(id):return id in Game.weapon_unlocks)
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
## The crate window (T-233): three offer cards in the reward-card style — rarity border, a big gun, the name —
## and the numbers as bars next to the gun in hand: the bar is the offer, the white tick is the gun in hand, green
## better, red worse. A purchase rebuilds the same window (it stays the room's modal, so world prompts stay hidden).
const CARD_GAP:=16.0
const BETTER:=Color("8fe895")
const WORSE:=Color("e0806b")
## Rows on the bars: [key of power(), label, unit].
const ROWS:=[["dps","Огневая мощь",""],["shot","Урон",""],["rate","Темп"," /с"],["range","Дальность",""]]
func open(ui_root:Control,done:Callable):
	if offers.is_empty():offers=roll_offers()
	if not is_instance_valid(modal):
		modal=Control.new();modal.name="WeaponLockerMenu";ui_root.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_to_group("selection_scope")
	else:
		for child in modal.get_children():modal.remove_child(child);child.queue_free()
	var shade=ColorRect.new();modal.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.5)
	var screen=ui_root.get_viewport_rect().size
	var card_w=clampf(floorf((screen.x-32-48-CARD_GAP*2)/3.0),190.0,250.0);var card_h=372.0
	var size=Vector2(card_w*3+CARD_GAP*2+48,card_h+120);var panel=UiKit.glass(modal,((screen-size)*.5).round(),size);panel.name="Panel"
	UiKit.label(panel,"Ящик с оружием",Vector2(24,16),Vector2(size.x-370,34),24)
	var hint=UiKit.label(panel,"Ствол уходит в рюкзак — перетащи его в слот оружия",Vector2(24,52),Vector2(size.x-370,40),13,UiKit.MUTED);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var close=func():
		if is_instance_valid(modal):modal.queue_free()
		modal=null;done.call()
	var hand=hand_gun();var base=power(str(hand.id),hand.stats)
	hand_chip(panel,Vector2(size.x-66-268,14),hand)
	# Bar scale per row: the strongest of the offers and the gun in hand fills the bar.
	var values=[base]
	for offer in offers:values.append(power(str(offer.id),offer.stats))
	var top={}
	for key in base:top[key]=values.reduce(func(m,v):return maxf(m,float(v[key])),0.0)
	for i in range(offers.size()):
		var card=offer_card(panel,i,Vector2(24+i*(card_w+CARD_GAP),96),Vector2(card_w,card_h),values[i+1],base,top)
		var b=UiKit.button(card,"Куплено" if offers[i].sold else "Купить · %d ◈" % int(offers[i].price),Vector2(14,card_h-62),Vector2(card_w-28,48),func():
			var reason=buy(i)
			if reason!="" and is_instance_valid(arena):arena.toast(Texts.render(reason))
			if is_instance_valid(modal):open(ui_root,done),true)
		b.name="Buy%d" % i;b.disabled=offers[i].sold or Game.credits<int(offers[i].price)
	var x=UiKit.button(panel,"",Vector2(size.x-66,14),Vector2(44,40),close);x.icon=UiKit.interface_icon("close");x.expand_icon=true;x.add_theme_constant_override("icon_max_width",18)
	refresh_prompt()
## The gun in hand: {id, rarity, stats} (stats are the rolled bonuses of a crate gun).
func hand_gun()->Dictionary:
	var run=arena.run if is_instance_valid(arena) and "run" in arena and arena.run!=null else null
	var id=str(arena.weapon) if is_instance_valid(arena) and "weapon" in arena else Game.selected_weapon
	if not Game.LOOT.WEAPONS.has(id):id=LootCatalog.PAWS
	return {"id":id,"rarity":int(run.weapon_rarity) if run!=null else 0,"stats":run.weapon_stats.duplicate() if run!=null else {}}
## Numbers compared on the bars: damage per shot (pellets included), shots a second, their product, range.
func power(id:String,stats:Dictionary)->Dictionary:
	var ctx=arena if is_instance_valid(arena) and "run" in arena and arena.run!=null else null
	var w=CombatStats.weapon(ctx,id,{"item_stats":stats})
	var shot=float(w.damage)*int(Game.LOOT.WEAPONS[id].get("pellets",1))
	return {"dps":shot*float(w.rate),"shot":shot,"rate":float(w.rate),"range":float(w.range)}
## Top-right reference: the gun in hand, with the white tick that marks it on every bar.
func hand_chip(panel:Control,at:Vector2,hand:Dictionary):
	var chip=Panel.new();panel.add_child(chip);chip.name="InHand";chip.position=at;chip.size=Vector2(258,62);chip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel",UiKit.style(Color(1,1,1,.05),12,Color(1,1,1,.16)))
	var pic=TextureRect.new();chip.add_child(pic);pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;pic.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pic.texture=UiKit.trimmed(UiKit.icon_texture(str(hand.id)));pic.position=Vector2(10,9);pic.size=Vector2(70,44)
	var tick=ColorRect.new();chip.add_child(tick);tick.color=Color.WHITE;tick.position=Vector2(92,9);tick.size=Vector2(3,14);tick.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UiKit.label(chip,"В руках",Vector2(101,6),Vector2(130,18),12,UiKit.MUTED)
	var tier=clampi(int(hand.rarity),0,3)
	var name=UiKit.label(chip,Game.LOOT.WEAPONS[hand.id].name,Vector2(92,27),Vector2(130,26),16,Color(LootCatalog.RARITY_COLORS[tier]).lightened(.2) if tier>0 else UiKit.INK);name.clip_text=true
## One offer as a card: rarity, picture, name, a verdict from firepower and four bars.
func offer_card(panel:Control,i:int,at:Vector2,dimensions:Vector2,value:Dictionary,base:Dictionary,top:Dictionary)->Panel:
	var offer:Dictionary=offers[i];var tier=clampi(int(offer.rarity),0,3);var color=Color(LootCatalog.RARITY_COLORS[tier])
	var card=Panel.new();panel.add_child(card);card.name="Offer%d" % i;card.position=at;card.size=dimensions;card.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style=UiKit.style(Color("232c29").lerp(color,.10),14,color.darkened(.25));style.set_border_width_all(2)
	if tier>=2:style.shadow_color=Color(color,.16 if tier==2 else .26);style.shadow_size=10 if tier==2 else 16
	card.add_theme_stylebox_override("panel",style)
	var stripe=ColorRect.new();card.add_child(stripe);stripe.color=color;stripe.position=Vector2(0,15);stripe.size=Vector2(6,24);stripe.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UiKit.label(card,LootCatalog.RARITY_NAMES[tier],Vector2(18,14),Vector2(dimensions.x-32,24),14,color.lightened(.15) if tier>0 else UiKit.MUTED)
	var pic=TextureRect.new();card.add_child(pic);pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;pic.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pic.texture=UiKit.trimmed(UiKit.icon_texture(str(offer.id)));pic.position=Vector2(22,44);pic.size=Vector2(dimensions.x-44,76)
	var title=UiKit.label(card,Game.LOOT.WEAPONS[offer.id].name,Vector2(18,124),Vector2(dimensions.x-32,28),20,color.lightened(.2) if tier>0 else UiKit.INK);title.clip_text=true
	# One verdict line from firepower: stronger / weaker than the gun in hand, or the same.
	var change=percent(float(value.dps),float(base.dps))
	var verdict="▲ "+Texts.render("Сильнее на %d%%" % change) if change>0 else "▼ "+Texts.render("Слабее на %d%%" % -change) if change<0 else "= "+Texts.render("Как в руках")
	UiKit.label(card,verdict,Vector2(18,152),Vector2(dimensions.x-32,20),14,BETTER if change>0 else WORSE if change<0 else UiKit.MUTED)
	for r in range(ROWS.size()):
		stat_row(card,Vector2(18,184+r*31),dimensions.x-36,ROWS[r],float(value[ROWS[r][0]]),float(base[ROWS[r][0]]),float(top[ROWS[r][0]]))
	if offer.sold:
		for child in card.get_children():child.modulate=Color(1,1,1,.45)
	return card
## Change against the gun in hand in whole percent.
static func percent(now:float,before:float)->int:
	if before<=0.0:return 0
	return roundi((now/before-1.0)*100.0)
## One bar row: label, the offer's number and its change, then the bar with the hand's white tick.
func stat_row(card:Control,at:Vector2,width:float,spec:Array,now:float,before:float,top:float):
	var change=percent(now,before)
	UiKit.label(card,spec[1],at,Vector2(width*.55,18),12,UiKit.MUTED)
	var shown=UiKit.label(card,UiKit.number(snappedf(now,.01 if now<10 else .1))+spec[2],at,Vector2(width-58,18),13,UiKit.INK);shown.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var delta=UiKit.label(card,("+%d%%" % change) if change>0 else ("−%d%%" % -change) if change<0 else "=",at,Vector2(width,18),12,BETTER if change>0 else WORSE if change<0 else UiKit.MUTED);delta.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var track=Panel.new();card.add_child(track);track.position=at+Vector2(0,21);track.size=Vector2(width,6);track.mouse_filter=Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("panel",bar_style(Color(1,1,1,.1)))
	var fill=Panel.new();track.add_child(fill);fill.size=Vector2(maxf(4.0,width*clampf(now/maxf(top,.001),0,1)),6);fill.mouse_filter=Control.MOUSE_FILTER_IGNORE
	fill.add_theme_stylebox_override("panel",bar_style(BETTER if change>0 else WORSE if change<0 else Color("d8d2bd")))
	var tick=ColorRect.new();track.add_child(tick);tick.color=Color.WHITE;tick.size=Vector2(3,12);tick.position=Vector2(clampf(width*before/maxf(top,.001),0,width)-1.5,-3);tick.mouse_filter=Control.MOUSE_FILTER_IGNORE
## A plain rounded bar (UiKit.style turns light and green fills into dark panels).
static func bar_style(color:Color)->StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=color;s.set_corner_radius_all(3);return s
## The world prompt says what the crate is and what it costs (T-226): the cheapest gun still for sale.
func refresh_prompt():
	if prompt==null:return
	var left=offers.filter(func(o):return not o.sold)
	if left.is_empty():prompt.caption=Texts.render("Ящик с оружием · всё куплено");return
	var cheapest=left.reduce(func(m,o):return mini(m,int(o.price)),int(left[0].price))
	prompt.caption=Texts.render("Ящик с оружием · стволы от %d ◈" % cheapest)
