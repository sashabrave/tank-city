extends "res://scripts/playground.gd"
## Merchant stop as a playground on the run's Arena (one field engine, guides/02_development/07_one_world.md): spend
## run tokens on cards, healing, rerolls or a blueprint at the counter. The room follows the common RoomLayout:
## weapon crate on the left, a vending machine at the front left, the slot machine on the «Фортуна» spot
## (scripts/slot_machine.gd). Stock comes from the run's combat RNG. The hero, shooting, abilities and the drop
## floor are the arena's. Open with main.enter_playground("merchant", index) → arena.begin_playground (show_service).
const CARD_PRICES=[3,5,8,12]
var locker:Node3D
var vendor:Node3D
## RoomLayout nodes: {crate, machine, fortune, layout}.
var spots:Dictionary={}
var interact_button:Button
var stock:Array=[]
var status_text=""
var shop_revealed=false
var guide:Node3D
const COUNTER=RoomLayout.MAIN
## The truck and its counter take the back of the floor: the hero walks z = 0…4.
func floor_back()->int:return 0
func exit_open()->bool:return true
func _ready():
	var positions=[]
	for x in range(-4,5):
		for z in range(-3,5):positions.append(Vector3(x,0,z))
	Visuals.tiled_floor(self,positions,Color("98917f"))
	Visuals.box(self,Vector3(0,-.4,.5),Vector3(9.3,.6,8.3),Color("7d7462"))
	build_stall()
	# Cozy surroundings and fixed decorative lights, the same as the upgrade rooms (2026-10-03).
	preload("res://scripts/location_ambience.gd").room(self,arena,index,4.9)
	preload("res://scripts/room_lights.gd").build(self,-3.55)
	build_ui("Торговец","Жетоны с врагов меняются здесь на усиления","Дальше →",func():leave())
	var size=get_viewport().get_visible_rect().size
	interact_button=UiKit.button(root,"Торговать [E]",Vector2(size.x-330,size.y-170),Vector2(290,60),interact);interact_button.hide()
	# No sign over the truck (T-226): the prompt says what is sold; a yellow arrow points at the counter until the
	# shop has been opened once (the merchant has no exit gate — «Дальше» leads on).
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Торговец · карточки и припасы за жетоны",COUNTER,1.8,func():return true)
	# An exit gate like in every upgrade room (T-285): always open here, E at the gate leads on to the map.
	exit_parts=preload("res://scripts/service_dressing.gd").build_gate(self,EXIT_CELL);preload("res://scripts/service_dressing.gd").paint_gate(exit_parts,true)
	for chevron in exit_parts.arrows:chevron.modulate.a=.6
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Выход на карту",Vector3(EXIT_CELL.x,0,EXIT_CELL.y),1.3,func():return true)
	guide=preload("res://scripts/room_guide_arrow.gd").attach(self)
	stock=roll_stock()
	spots=RoomLayout.furnish(self,arena,index,true)
	locker=spots.crate;vendor=spots.machine
## The merchant room is the route stop seen up close (author, 3 Oct): the same military shop truck, bigger and more
## detailed, its open side is the counter; jerrycans, a barrel, a table and a pine fill the edges. Boxes stay as a
## fallback when the model file is missing.
const ROOM_TRUCK:="res://assets/models/route/merchant_room_truck.glb"
func build_stall():
	if ResourceLoader.exists(ROOM_TRUCK):
		var truck:Node3D=load(ROOM_TRUCK).instantiate();truck.name="ShopTruck";add_child(truck)
		truck.position=Vector3(0,0,-2.6);truck.scale=Vector3.ONE*1.3
		preload("res://scripts/route_miniatures.gd").library_surfaces(truck)
		var olive=Color("59603f");var wood=Color("8a6a48")
		# folding table with goods at the back left, jerrycans and a barrel on the right edge, a pine in the corner
		Visuals.box(self,Vector3(-2.3,.75,-1.3),Vector3(1.3,.08,.6),wood,"wood")
		for x in [-2.8,-1.8]:Visuals.box(self,Vector3(x,.37,-1.3),Vector3(.08,.74,.5),wood.darkened(.3),"wood")
		Visuals.box(self,Vector3(-2.5,.92,-1.3),Vector3(.45,.26,.3),olive,"paint")
		for i in range(2):Visuals.box(self,Vector3(3.6,.3,-.2+i*.45),Vector3(.38,.6,.22),olive,"paint")
		var barrel=MeshInstance3D.new();var shape=CylinderMesh.new();shape.top_radius=.38;shape.bottom_radius=.38;shape.height=.9;barrel.mesh=shape;add_child(barrel)
		barrel.position=Vector3(3.5,.45,-1.9);barrel.material_override=Visuals.surface_material(Color("5d6266"),"steel")
		return
	var wood=Color("8a6a48");var cloth=Color("c9793f")
	Visuals.box(self,COUNTER+Vector3(0,.45,0),Vector3(2.6,.9,.9),wood)
	for x in [-1.25,1.25]:Visuals.box(self,COUNTER+Vector3(x,1.25,-.35),Vector3(.12,2.5,.12),wood.darkened(.3))
	for i in range(5):Visuals.box(self,COUNTER+Vector3(-1.1+i*.55,2.45,-.1),Vector3(.55,.08,1.1),cloth if i%2==0 else Color("e8dcc0"))
	for p in [Vector3(-2,0,-1.5),Vector3(3.7,0,-1.3)]:Visuals.box(self,p+Vector3(0,.3,0),Vector3(.6,.6,.6),Color("9c8156"))
	Visuals.box(self,Vector3(-2.3,.6,.4),Vector3(.8,1.2,.6),Color("5b6770"))
	Visuals.box(self,Vector3(-2.3,1.0,.71),Vector3(.55,.3,.02),Color("e5b34f"))
## Stock entries: {kind, id, tier, price, sold}. Cards use UpgradeRegistry; the blueprint appears in 40% of visits.
func roll_stock()->Array:
	var rng=arena.run.combat_rng;var result=[]
	for offer in RunUpgrades.roll_offers(arena,2):
		var tier=clampi(int(offer.tier),0,CARD_PRICES.size()-1)
		result.append({"kind":"card","id":offer.id,"tier":tier,"price":CARD_PRICES[tier],"sold":false})
	result.append({"kind":"heal","price":3,"sold":false})
	# The vehicle the hero brought from the last field waits outside (service_field.carried) and can be repaired.
	if carried_vehicle()!="":
		result.append({"kind":"repair","price":3,"sold":false})
	result.append({"kind":"reroll","price":2,"sold":false})
	if rng.randf()<.4:
		var recipe=EncounterRules.recipe(1,rng,arena.run.pending_recipes,Campaign.progress_index(index))
		if not recipe.is_empty():result.append({"kind":"blueprint","recipe":recipe,"price":10,"sold":false})
	return result

var exit_parts:Dictionary={}
## The hero's own vehicle from the last field ("" when he came on foot).
func carried_vehicle()->String:
	var kind=str(arena.service.carried.get("kind",""))
	return kind if kind in GarageCatalog.VEHICLES else ""
func at_exit()->bool:return is_instance_valid(avatar) and avatar.position.distance_to(Vector3(EXIT_CELL.x,0,EXIT_CELL.y))<1.3
## On to the map: the same completion signal as ever, once.
func leave():
	set_process(false);completed.emit(index)
func _process(delta):
	super(delta)
	if is_instance_valid(guide):
		if shop_revealed:guide.point(Vector3(EXIT_CELL.x+.25,0,EXIT_CELL.y),3.7,"ready")
		else:guide.point(COUNTER,3.2,"goal")
	if is_instance_valid(avatar):interact_button.disabled=avatar.position.distance_to(COUNTER)>2.2 and RoomLayout.near(spots,avatar)==null
func interact():
	if preload("res://scripts/ui/drop_prompt.gd").engaged(self):return
	if window_open() or not is_instance_valid(avatar):return
	# The common room spots: weapon crate, vending machine, fortune (RoomLayout).
	var spot=RoomLayout.near(spots,avatar)
	if spot:use_spot(spot);return
	if at_exit():leave();return
	if avatar.position.distance_to(COUNTER)>2.2:return
	Game.reset_input()
	open_shop()
## Opens a RoomLayout spot with the controls released, and gives them back when it closes.
func use_spot(spot:Node3D):
	Game.reset_input()
	var done=func():Game.reset_input();modal=null
	if spot.has_method("use"):spot.use(root,done)
	else:spot.open(root,done)
	if "modal" in spot and is_instance_valid(spot.modal):modal=spot.modal
## Shop window (T-264): the offers are big cards in the style of the upgrade choice between waves
## (scripts/ui/choice_card.gd, scene choice_upgrade.tscn) — picture, rarity plate, title, short effect — with a
## buy button and the price in tokens at the bottom of each card. «Перебросить» spends the same run rerolls as the
## upgrade cards and rolls the unsold card offers again. Cards that do not fit the width scroll sideways.
const CARD_MIN_W:=200.0
const CARD_MAX_W:=280.0
const CARD_GAP:=14.0
const BUY_ROW:=72.0
## The reroll button and its hint under the cards.
const REROLL_ROW:=84.0
## Index of the card whose button had keyboard focus: a purchase rebuilds the window and keeps the place.
var focus_index:=-1
var reveal_cards:=false
func open_shop():
	CardNavigation.release_required=true
	modal=Control.new();modal.name="MerchantShop";root.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_to_group("selection_scope")
	var shade=ColorRect.new();modal.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(.10,.16,.12,.62)
	var size=get_viewport().get_visible_rect().size;var width=minf(1400,size.x-24)
	# Cards: as many as fit at 200–280 px; more scroll sideways (a finger drags the row on a phone).
	var n=stock.size();var row_area=width-60
	var card_w=clampf(floorf((row_area-CARD_GAP*(n-1))/maxf(1,n)),CARD_MIN_W,CARD_MAX_W)
	var row_w=card_w*n+CARD_GAP*(n-1);var scrolls=row_w>row_area
	var card_h=clampf(minf(740,size.y-24)-100-REROLL_ROW-(14.0 if scrolls else 0.0),300.0,480.0)
	# The window hugs the cards and the reroll row under them.
	var height=100+card_h+(14.0 if scrolls else 0.0)+REROLL_ROW
	var panel=UiKit.glass(modal,((size-Vector2(width,height))*.5).round(),Vector2(width,height));panel.name="Panel"
	UiKit.accent(UiKit.label(panel,"Торговец",Vector2(30,18),Vector2(width-360,44),30))
	UiKit.icon(panel,"token",Vector2(width-286,24),Vector2(30,30))
	var count=UiKit.label(panel,"Жетоны: %d" % arena.run.tokens,Vector2(width-250,20),Vector2(170,38),22);count.name="Wallet"
	var close=UiKit.button(panel,"",Vector2(width-66,16),Vector2(48,44),close_shop);close.name="Close";close.icon=UiKit.interface_icon("close");close.expand_icon=true;close.add_theme_constant_override("icon_max_width",18)
	var status=UiKit.label(panel,status_text if status_text!="" else "Жетоны с врагов меняются здесь на усиления",Vector2(30,62),Vector2(width-60,28),17,UiKit.MUTED);status.name="Status"
	var scroll=ScrollContainer.new();scroll.name="StockScroll";panel.add_child(scroll)
	scroll.size=Vector2(minf(row_area,row_w),card_h+(14.0 if scrolls else 0.0));scroll.position=Vector2(30+(row_area-scroll.size.x)*.5,100)
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var list=HBoxContainer.new();list.name="Stock";scroll.add_child(list);list.add_theme_constant_override("separation",int(CARD_GAP))
	for i in range(n):offer_card(list,i,card_w,card_h)
	# The first card that can be bought takes the keyboard selection (not the close cross).
	for i in range(n):
		var buy=list.get_node("Offer%d/Buy%d" % [i,i])
		if not buy.disabled:buy.set_meta("default_choice",true);break
	# Reroll: the same counter as the upgrade cards between waves (arena.run.rerolls_left).
	var bottom=height-REROLL_ROW+12
	var reroll=UiKit.button(panel,"Перебросить карточки (%d)" % arena.run.rerolls_left,Vector2(30,bottom),Vector2(minf(400,width*.5-40),54),reroll_offers)
	reroll.name="Reroll";reroll.disabled=not can_reroll();reroll.icon=UiKit.trimmed(UiKit.icon_texture("reroll"));reroll.expand_icon=true;reroll.add_theme_constant_override("icon_max_width",26)
	UiKit.muted_locked_button(reroll)
	var hint=UiKit.label(panel,"Перебросы общие с карточками после волны" if arena.run.rerolls_left>0 else "Перебросы закончились — их продаёт торговец",Vector2(reroll.position.x+reroll.size.x+18,bottom),Vector2(width-reroll.size.x-90,54),16,UiKit.MUTED)
	hint.name="RerollHint";hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if not shop_revealed or reveal_cards:shop_revealed=true;reveal_cards=false;UiKit.reveal_list(list)
	var focus=list.get_node_or_null("Offer%d/Buy%d" % [focus_index,focus_index]) if focus_index>=0 else null
	if focus and not focus.disabled:CardNavigation.choose(focus)
## One offer as a run-upgrade card (choice_card.minimal): picture, rarity plate, family chip, title, values; the
## buy button with the price sits in the card's bottom strip and says why it is locked.
func offer_card(list:HBoxContainer,i:int,width:float,height:float)->Panel:
	var entry=stock[i];var view=card_view(entry)
	var card:Panel=load("res://scenes/ui/choice_upgrade.tscn").instantiate();card.name="Offer%d" % i;list.add_child(card)
	card.custom_minimum_size=Vector2(width,height);card.size=Vector2(width,height-BUY_ROW+12)
	preload("res://scripts/ui/choice_card.gd").configure(card,view,func():pass)
	# The whole-card button of the wave screen gives way to the buy button: one button per card for E/arrows.
	var choose=card.get_node("ChooseButton");card.remove_child(choose);choose.queue_free()
	card.size=Vector2(width,height)
	var glow=card.get_node_or_null("RarityGlow")
	if glow:
		glow.size=card.size-glow.position*2
		if glow.material:glow.material.set_shader_parameter("rect_size",glow.size)
	var reason=locked_reason(entry)
	var label=reason if reason!="" else ("Сыграть · %d" if entry.kind=="slot" else "Купить · %d") % entry.price
	var priced=reason=="" or reason.begins_with("Не хватает")
	var buy=UiKit.button(card,"" if priced else label,Vector2(14,height-BUY_ROW+4),Vector2(width-28,54),func():focus_index=i;purchase(i),reason=="")
	buy.name="Buy%d" % i;buy.disabled=reason!="";buy.add_theme_font_size_override("font_size",19)
	UiKit.muted_locked_button(buy)
	# Price with the token right after the number, centred: «Купить · 3 ◎» / «Не хватает 2 ◎».
	if priced:
		var line=HBoxContainer.new();line.name="Price";buy.add_child(line);line.mouse_filter=Control.MOUSE_FILTER_IGNORE
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);line.alignment=BoxContainer.ALIGNMENT_CENTER;line.add_theme_constant_override("separation",8)
		var text=Label.new();line.add_child(text);text.mouse_filter=Control.MOUSE_FILTER_IGNORE;text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		text.add_theme_font_override("font",UiKit.field_font());text.add_theme_font_size_override("font_size",19)
		text.add_theme_color_override("font_color",Color("20271f") if reason=="" else Color(.65,.69,.61,.65));Texts.set_text(text,label)
		var coin=UiKit.icon(line,"token",Vector2.ZERO,Vector2(24,24));coin.custom_minimum_size=Vector2(24,24)
		if reason!="":coin.modulate=Color(1,1,1,.35)
	if entry.sold:card.modulate=Color(1,1,1,.55)
	return card
## Why the buy button is locked, in its own words; empty when the offer can be bought.
func locked_reason(entry:Dictionary)->String:
	if entry.sold:return "Продано"
	if not available(entry):
		match entry.kind:
			"heal":return "Здоровье полное"
			"repair":return "Броня цела"
		return "Рюкзак полон"
	if arena.run.tokens<entry.price:return "Не хватает %d" % (entry.price-arena.run.tokens)
	return ""
## Card data for choice_card.configure: run cards are the same cards as between waves; supplies get a grey plate.
func card_view(entry:Dictionary)->Dictionary:
	if entry.kind=="card":return RunUpgrades.card(arena,{"id":entry.id,"tier":entry.tier})
	var view=describe(entry)
	var chip={"heal":"Лечение","repair":"Техника","reroll":"Перебросы","blueprint":"Рюкзак","slot":"Удача"}.get(entry.kind,"Припасы")
	var tier=2 if entry.kind=="blueprint" else 0
	return {"category":chip,"family":"supply","title":view.title,"detail":view.detail,"icon":view.icon,"heading":"Чертёж" if entry.kind=="blueprint" else "Припасы","color":Color(LootCatalog.RARITY_COLORS[tier]),"tier":tier,"rows":[],"stacks":0}
func can_reroll()->bool:
	return arena.run.rerolls_left>0 and stock.any(func(e):return e.kind=="card" and not e.sold)
## «Перебросить»: one run reroll rolls the unsold card offers again on the run's combat RNG (the same roll as the
## stock); prices keep the rarity rule. Cards already on the counter are not offered again when the pool allows.
func reroll_offers()->bool:
	if not can_reroll():return false
	var open=[];var shown=[]
	for i in range(stock.size()):
		if stock[i].kind!="card":continue
		shown.append(stock[i].id)
		if not stock[i].sold:open.append(i)
	var fresh=RunUpgrades.roll_offers(arena,open.size()+shown.size()).filter(func(o):return o.id not in shown)
	if fresh.size()<open.size():fresh=RunUpgrades.roll_offers(arena,open.size())
	if fresh.is_empty():return false
	arena.run.rerolls_left-=1
	for k in range(mini(open.size(),fresh.size())):
		var tier=clampi(int(fresh[k].tier),0,CARD_PRICES.size()-1)
		stock[open[k]]={"kind":"card","id":fresh[k].id,"tier":tier,"price":CARD_PRICES[tier],"sold":false}
	status_text="Карточки переброшены";Game.sound("reroll",self)
	if is_instance_valid(modal):focus_index=-1;reveal_cards=true;close_shop(false);open_shop()
	return true
func describe(entry:Dictionary)->Dictionary:
	match entry.kind:
		"card":
			var view=RunUpgrades.card(arena,{"id":entry.id,"tier":entry.tier})
			return {"icon":UpgradeRegistry.get_def(entry.id).icon,"title":view.heading+" · "+view.title,"detail":view.detail,"tint":Color(LootCatalog.RARITY_COLORS[entry.tier]).darkened(.35)}
		"heal":return {"icon":"medkit","title":"Полевая аптечка","detail":UiKit.change_text("HP",arena.run.soldier_hp,arena.run.soldier_max_hp)}
		"repair":return {"icon":"vehicle","title":"Ремонт машины","detail":"Восстанавливает броню техники полностью"}
		"reroll":return {"icon":"reroll","title":"Переброс","detail":"+1 переброс карт на этот забег"}
		"blueprint":return {"icon":preload("res://scripts/ui/item_info.gd").blueprint_key(entry.recipe),"title":"Чертёж · "+Game.recipe_name(entry.recipe),"detail":"Попадёт в рюкзак — его нужно донести до хаба"}
		"slot":return {"icon":"slot_machine","title":"Игровой автомат","detail":"Ставка %d: жетоны, сплав, боеприпасы, лечение или карта — иногда эпическая" % entry.price}
	return {"icon":"token","title":entry.kind,"detail":""}
func available(entry:Dictionary)->bool:
	match entry.kind:
		"heal":return arena.run.soldier_hp<arena.run.soldier_max_hp
		"repair":return carried_vehicle()!="" and float(arena.service.carried.get("hp",0.0))<arena.service.vehicle_full_armor()
		"blueprint":return not Backpack.full(arena.run)
		# An ammo card pushes the loaded ammo into the backpack (audit 2026-10-03): it needs a free cell here.
		"card":return not (str(entry.get("id","")) in Ammo.TYPES and Backpack.full(arena.run))
	return true
func purchase(i:int)->bool:
	if i<0 or i>=stock.size():return false
	var entry=stock[i]
	if entry.sold or arena.run.tokens<entry.price or not available(entry):return false
	arena.run.tokens-=entry.price
	match entry.kind:
		"card":RunUpgrades.apply(arena,entry.id,entry.tier);status_text="Куплено: "+UpgradeRegistry.get_def(entry.id).title
		"heal":heal_full();status_text="Боец вылечен"
		"repair":arena.service.carried.hp=arena.service.vehicle_full_armor();status_text="Машина отремонтирована"
		"reroll":arena.run.rerolls_left+=1;status_text="Переброс добавлен"
		"blueprint":arena.run.pending_recipes.append(entry.recipe);status_text="Чертёж в рюкзаке"
		"slot":status_text=spots.fortune.play() if is_instance_valid(spots.get("fortune")) and spots.fortune.has_method("play") else ""
	if entry.kind!="slot":entry.sold=true
	Game.progression.event("slot_play" if entry.kind=="slot" else "merchant_buy")
	Game.sound("upgrade" if entry.kind=="card" else "pickup",self)
	if is_instance_valid(modal):close_shop(false);open_shop()
	return true
## E at the machine: pay, decide the outcome, show the reels. The prize is already granted; the window only reveals it.
## Pulls the fortune slot machine (kept for tests and old callers); false without tokens.
func pull_lever()->bool:
	var machine=spots.get("fortune")
	if not is_instance_valid(machine) or not machine.has_method("pull"):return false
	Game.reset_input()
	var line=machine.pull(root,func():modal=null;Game.reset_input())
	if line=="":status_text="Автомату нужно %d жетона" % machine.PRICE;return false
	status_text=line;modal=machine.modal
	return true
func heal_full():
	arena.run.soldier_hp=arena.run.soldier_max_hp
	if is_instance_valid(arena.room.player) and arena.room.player.kind=="soldier":arena.room.player.hp=arena.run.soldier_hp;arena.room.player.refresh_health()
func close_shop(restore_controls:bool=true):
	if is_instance_valid(modal):modal.get_parent().remove_child(modal);modal.queue_free();modal=null
	if restore_controls:Game.reset_input()
