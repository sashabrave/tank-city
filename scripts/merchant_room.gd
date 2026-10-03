extends Node3D
## Merchant stop: spend run tokens on cards, healing, rerolls or a blueprint at the counter. The room follows the
## common RoomLayout: weapon crate on the left, a vending machine at the front left, the slot machine on the
## «Фортуна» spot (scripts/slot_machine.gd). Stock comes from the run's combat RNG.
signal completed(index: int)
signal hub_requested
const CARD_PRICES=[3,5,8,12]
var arena
var index=2
var locker:Node3D
var vendor:Node3D
## RoomLayout nodes: {crate, machine, fortune, layout}.
var spots:Dictionary={}
var avatar:Node3D
var cell=Vector2i(0,3)
var destination=Vector3(0,0,3)
var moving=false
var walker
var facing=Vector2i.UP
var root:Control
var dpad:Control
var modal:Control
var interact_button:Button
var stock:Array=[]
var status_text=""
var shop_revealed=false
const COUNTER=RoomLayout.MAIN
func _ready():
	add_to_group("notification_context")
	Visuals.setup_world(self,11.4,Vector3.ZERO)
	var positions=[]
	for x in range(-4,5):
		for z in range(-3,5):positions.append(Vector3(x,0,z))
	Visuals.tiled_floor(self,positions,Color("98917f"))
	Visuals.box(self,Vector3(0,-.4,.5),Vector3(9.3,.6,8.3),Color("7d7462"))
	build_stall()
	var shapes_rng=RandomNumberGenerator.new();shapes_rng.seed=Game.visual_run_seed+index*31
	preload("res://scripts/service_dressing.gd").silhouettes(self,shapes_rng,Color("b7ae9c"))
	avatar=Visuals.model("soldier",self,destination,"cat",true)
	walker=preload("res://scripts/room_walker.gd").new(avatar)
	var canvas=CanvasLayer.new();add_child(canvas);root=Control.new();canvas.add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# Shooting and abilities like in the hub and in battle (T-185).
	preload("res://scripts/room_combat.gd").attach(self,avatar,walker,stand,root)
	var heading=UiKit.glass(root,Vector2(25,25),Vector2(590,120),Color("242d27ed"));heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UiKit.accent(UiKit.label(root,"Торговец",Vector2(40,30),Vector2(800,60),32))
	UiKit.label(root,"Жетоны с врагов меняются здесь на усиления",Vector2(40,100),Vector2(1000,40),18)
	var size=get_viewport().get_visible_rect().size
	dpad=load("res://scripts/touch_controls.gd").new();root.add_child(dpad);dpad.apply_movement_layout()
	interact_button=UiKit.button(root,"Торговать [E]",Vector2(size.x-330,size.y-170),Vector2(290,60),interact);interact_button.hide()
	UiKit.button(root,"Дальше →",Vector2(size.x-330,size.y-90),Vector2(290,60),func():completed.emit(index),true)
	UiKit.button(root,"Вернуться в хаб",Vector2(40,165),Vector2(250,48),func():hub_requested.emit())
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Торговец",COUNTER,1.8,func():return true)
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
		Visuals.label3d(self,"Торговец · E",COUNTER+Vector3(0,2.9,0),Color("fff0ce"),28)
		return
	var wood=Color("8a6a48");var cloth=Color("c9793f")
	Visuals.box(self,COUNTER+Vector3(0,.45,0),Vector3(2.6,.9,.9),wood)
	for x in [-1.25,1.25]:Visuals.box(self,COUNTER+Vector3(x,1.25,-.35),Vector3(.12,2.5,.12),wood.darkened(.3))
	for i in range(5):Visuals.box(self,COUNTER+Vector3(-1.1+i*.55,2.45,-.1),Vector3(.55,.08,1.1),cloth if i%2==0 else Color("e8dcc0"))
	for p in [Vector3(-2,0,-1.5),Vector3(3.7,0,-1.3)]:Visuals.box(self,p+Vector3(0,.3,0),Vector3(.6,.6,.6),Color("9c8156"))
	Visuals.box(self,Vector3(-2.3,.6,.4),Vector3(.8,1.2,.6),Color("5b6770"))
	Visuals.box(self,Vector3(-2.3,1.0,.71),Vector3(.55,.3,.02),Color("e5b34f"))
	Visuals.label3d(self,"Торговец · E",COUNTER+Vector3(0,2.9,0),Color("fff0ce"),28)
## Stock entries: {kind, id, tier, price, sold}. Cards use UpgradeRegistry; the blueprint appears in 40% of visits.
func roll_stock()->Array:
	var rng=arena.run.combat_rng;var result=[]
	for offer in RunUpgrades.roll_offers(arena,2):
		var tier=clampi(int(offer.tier),0,CARD_PRICES.size()-1)
		result.append({"kind":"card","id":offer.id,"tier":tier,"price":CARD_PRICES[tier],"sold":false})
	result.append({"kind":"heal","price":3,"sold":false})
	if arena.room.player!=null and is_instance_valid(arena.room.player) and arena.room.player.kind in GarageCatalog.VEHICLES:
		result.append({"kind":"repair","price":3,"sold":false})
	result.append({"kind":"reroll","price":2,"sold":false})
	if rng.randf()<.4:
		var recipe=EncounterRules.recipe(1,rng,arena.run.pending_recipes,Campaign.progress_index(index))
		if not recipe.is_empty():result.append({"kind":"blueprint","recipe":recipe,"price":10,"sold":false})
	return result

func stand(p:Vector3)->bool:return p.x>=-3.01 and p.x<=3.01 and p.z>=-.01 and p.z<=4.01
func _physics_process(delta):
	# Same as the hub: the on-screen pad only for touch play.
	if is_instance_valid(dpad):dpad.visible=InputScheme.touch()
	if is_instance_valid(modal):
		if Input.is_action_just_pressed("pause"):close_shop()
		return
	if Input.is_action_just_pressed("pause"):preload("res://scripts/ui/pause_tablet.gd").open(self,Callable(),func():hub_requested.emit());return
	# The kit model walks only when told (T-045): idle while standing, walk cycle while moving.
	if "preview_moving" in avatar:avatar.preview_moving=moving;avatar.preview_speed=3.4
	walker.step(delta,Game.direction(),stand)
	moving=walker.moving;cell=walker.cell();facing=walker.facing
	interact_button.disabled=avatar.position.distance_to(COUNTER)>2.2 and RoomLayout.near(spots,avatar)==null
	if Game.wants_interact():interact()
func interact():
	if is_instance_valid(modal):return
	# The common room spots: weapon crate, vending machine, fortune (RoomLayout).
	var spot=RoomLayout.near(spots,avatar)
	if spot:use_spot(spot);return
	if avatar.position.distance_to(COUNTER)>2.2:return
	Game.reset_input();dpad.clear();dpad.enabled=false
	open_shop()
## Opens a RoomLayout spot with the controls released, and gives them back when it closes.
func use_spot(spot:Node3D):
	Game.reset_input();dpad.clear();dpad.enabled=false
	var done=func():Game.reset_input();dpad.clear();dpad.enabled=true;modal=null
	if spot.has_method("use"):spot.use(root,done)
	else:spot.open(root,done)
	if "modal" in spot and is_instance_valid(spot.modal):modal=spot.modal
func open_shop():
	modal=Control.new();modal.name="MerchantShop";root.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_to_group("selection_scope")
	var shade=ColorRect.new();modal.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.5)
	var size=get_viewport().get_visible_rect().size;var width=minf(940,size.x-24);var height=minf(660,size.y-24)
	var panel=UiKit.glass(modal,(size-Vector2(width,height))*.5,Vector2(width,height))
	UiKit.accent(UiKit.label(panel,"Торговец",Vector2(25,18),Vector2(width-260,40),28))
	var wallet=UiKit.icon(panel,"token",Vector2(width-265,24),Vector2(28,28))
	var count=UiKit.label(panel,"Жетоны: %d" % arena.run.tokens,Vector2(width-230,20),Vector2(160,36),20);count.name="Wallet"
	var close=UiKit.button(panel,"",Vector2(width-62,18),Vector2(44,40),close_shop);close.icon=UiKit.interface_icon("close");close.expand_icon=true;close.add_theme_constant_override("icon_max_width",18)
	if status_text!="":UiKit.label(panel,status_text,Vector2(25,62),Vector2(width-50,30),17,UiKit.MUTED).name="Status"
	var scroll=ScrollContainer.new();panel.add_child(scroll);scroll.position=Vector2(25,100);scroll.size=Vector2(width-50,height-125);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var list=VBoxContainer.new();scroll.add_child(list);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",10);list.name="Stock"
	for i in range(stock.size()):row(list,i,width-70)
	if not shop_revealed:shop_revealed=true;UiKit.reveal_list(list)
## One stock row (T-133): big enough for a finger — 64 px picture, 60 px button; on a narrow screen the button
## goes under the text across the whole row.
func row(list:VBoxContainer,i:int,width:float):
	var entry=stock[i];var view=describe(entry)
	var narrow=width<600
	var text_w=width-96-(0.0 if narrow else 260.0)
	var card=Panel.new();list.add_child(card);card.add_theme_stylebox_override("panel",UiKit.style(Color("dce3d5"),12))
	var picture=UiKit.icon(card,view.icon,Vector2(16,18),Vector2(64,64));picture.modulate=view.get("tint",UiKit.INK)
	UiKit.label(card,view.title,Vector2(96,12),Vector2(text_w,30),21).clip_text=true
	var detail=UiKit.label(card,view.detail,Vector2(96,44),Vector2(text_w,52),16,UiKit.MUTED);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var label="Продано" if entry.sold else "Купить · %d" % entry.price
	if entry.kind=="slot":label="Сыграть · %d" % entry.price
	var at=Vector2(16,104) if narrow else Vector2(width-244,20);var size=Vector2(width-32,60) if narrow else Vector2(228,60)
	card.custom_minimum_size=Vector2(width,180 if narrow else 104)
	var buy=UiKit.button(card,label,at,size,func():purchase(i),not entry.sold and arena.run.tokens>=entry.price)
	buy.name="Buy%d" % i;buy.disabled=entry.sold or arena.run.tokens<entry.price or not available(entry);buy.add_theme_font_size_override("font_size",19)
	UiKit.muted_locked_button(buy)
func describe(entry:Dictionary)->Dictionary:
	match entry.kind:
		"card":
			var view=RunUpgrades.card(arena,{"id":entry.id,"tier":entry.tier})
			return {"icon":UpgradeRegistry.get_def(entry.id).icon,"title":view.heading+" · "+view.title,"detail":view.detail,"tint":Color(LootCatalog.RARITY_COLORS[entry.tier]).darkened(.35)}
		"heal":return {"icon":"medkit","title":"Полевая аптечка","detail":UiKit.change_text("HP",arena.run.soldier_hp,arena.run.soldier_max_hp)}
		"repair":return {"icon":"vehicle","title":"Ремонт машины","detail":"Восстанавливает броню техники полностью"}
		"reroll":return {"icon":"reroll","title":"Переброс","detail":"+1 переброс карт на этот забег"}
		"blueprint":return {"icon":"blueprint","title":"Чертёж · "+Game.recipe_name(entry.recipe),"detail":"Попадёт в рюкзак — его нужно донести до хаба"}
		"slot":return {"icon":"slot_machine","title":"Игровой автомат","detail":"Ставка %d: жетоны, сплав, боеприпасы, лечение или карта — иногда эпическая" % entry.price}
	return {"icon":"token","title":entry.kind,"detail":""}
func available(entry:Dictionary)->bool:
	match entry.kind:
		"heal":return arena.run.soldier_hp<arena.run.soldier_max_hp
		"repair":return is_instance_valid(arena.room.player) and arena.room.player.hp<arena.room.player.max_hp
		"blueprint":return not Backpack.full(arena.run)
	return true
func purchase(i:int)->bool:
	if i<0 or i>=stock.size():return false
	var entry=stock[i]
	if entry.sold or arena.run.tokens<entry.price or not available(entry):return false
	arena.run.tokens-=entry.price
	match entry.kind:
		"card":RunUpgrades.apply(arena,entry.id,entry.tier);status_text="Куплено: "+UpgradeRegistry.get_def(entry.id).title
		"heal":heal_full();status_text="Боец вылечен"
		"repair":arena.room.player.hp=arena.room.player.max_hp;arena.room.player.refresh_health();status_text="Машина отремонтирована"
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
	Game.reset_input();dpad.clear();dpad.enabled=false
	var line=machine.pull(root,func():modal=null;Game.reset_input();dpad.clear();dpad.enabled=true)
	if line=="":status_text="Автомату нужно %d жетона" % machine.PRICE;return false
	status_text=line;modal=machine.modal
	return true
func heal_full():
	arena.run.soldier_hp=arena.run.soldier_max_hp
	if is_instance_valid(arena.room.player) and arena.room.player.kind=="soldier":arena.room.player.hp=arena.run.soldier_hp;arena.room.player.refresh_health()
func close_shop(restore_controls:bool=true):
	if is_instance_valid(modal):modal.get_parent().remove_child(modal);modal.queue_free();modal=null
	if restore_controls:Game.reset_input();dpad.clear();dpad.enabled=true
