extends Node3D
signal completed(index: int)
signal hub_requested
var arena
var index=2
var branch="vehicle"
var vehicle="buggy"
var locker:Node3D
var vendor:Node3D
## Price to take the mechanic's parked vehicle into the next field (T-011).
const VEHICLE_PRICES={"buggy":60,"apc":110,"tank":180}
const PARKED=Vector3(2.2,0,-1.2)
var avatar: Node3D
var cell=Vector2i(0,3)
var destination=Vector3(0,0,3)
var moving=false
var root: Control
var dpad: Control
var interact_button: Button
var continue_button: Button
var modal: Control
var claimed=false
var offers: Array=[]
var medkits: Array=[]
var facing=Vector2i.UP
var dressing
var walker
var vehicle_prompt
var combat:Node3D
func _ready():
	add_to_group("notification_context")
	vehicle=current_vehicle()
	Visuals.setup_world(self,11.4,Vector3.ZERO)
	var positions=[]
	for x in range(-4,5):
		for z in range(-3,5):positions.append(Vector3(x,0,z))
	Visuals.tiled_floor(self,positions,Color("7d8784"))
	Visuals.box(self,Vector3(0,-.4,.5),Vector3(9.3,.6,8.3),Color("4e5856"))
	dressing=preload("res://scripts/service_dressing.gd").new();dressing.branch=branch;dressing.vehicle=vehicle;add_child(dressing)
	if branch=="vehicle":
		Visuals.model("workbench",self,Vector3(0,0,-1))
		Visuals.model(vehicle,self,Vector3(2.2,.16,-1.2))
		# T-011: when the soldier is on foot, the parked vehicle can be taken into the next field for alloy.
		if not (is_instance_valid(arena.player) and arena.player.kind in GarageCatalog.VEHICLES) and arena.pending_vehicle=="":
			Visuals.label3d(self,"%s · %d ◈ · E" % [GarageCatalog.VEHICLES.get(vehicle,{}).get("name",vehicle),VEHICLE_PRICES.get(vehicle,80)],Vector3(2.2,1.7,-.4),Color("ffe2a8"),24).name="TakeVehicleLabel"
		Visuals.label3d(self,"Механик · E",Vector3(0,2,-1),Color("fff0ce"),28)
	elif branch=="headquarters":
		Visuals.model("base",self,Vector3(0,0,-1))
		Visuals.label3d(self,"Штаб · E",Vector3(0,2.6,-1),Color("fff0ce"),28)
	else:
		Visuals.box(self,Vector3(0,.35,-1),Vector3(1.4,.7,1.4),Color("717d79"))
		var statue=Visuals.model("soldier",self,Vector3(0,.7,-1));statue.scale=Vector3.ONE*1.5;Visuals.tint_model(statue,Color("738982"))
		Visuals.label3d(self,"Погладить статую · E",Vector3(0,3,-1),Color("fff0ce"),28)
	for i in range(Game.camp_level):
		var kit=Node3D.new();add_child(kit);kit.position=Vector3([-2.4,-.8,.8,2.4][i],0,2)
		arena.LOOT.visual(kit,"heart");Visuals.label3d(kit,"Аптечка",Vector3(0,1.1,0),Color("f6c5bc"),25);medkits.append(kit)
	avatar=Visuals.model("soldier",self,destination,"cat",true)
	walker=preload("res://scripts/room_walker.gd").new(avatar)
	var canvas=CanvasLayer.new();add_child(canvas);root=Control.new();canvas.add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var heading_plate=UiKit.glass(root,Vector2(25,25),Vector2(590,120),Color("242d27ed"));heading_plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UiKit.accent(UiKit.label(root,{"vehicle":"Полевой механик","ability":"Подготовка бойца","headquarters":"Мастерская штаба"}[branch],Vector2(40,30),Vector2(800,60),32))
	UiKit.label(root,{"vehicle":"Модификация транспорта","ability":"Модификация способности","headquarters":"Модуль или усиление на вылазку"}[branch],Vector2(40,100),Vector2(1000,40),18)
	var size=get_viewport().get_visible_rect().size
	dpad=load("res://scripts/touch_controls.gd").new();root.add_child(dpad);dpad.apply_movement_layout()
	interact_button=UiKit.button(root,"Улучшение [E]",Vector2(size.x-330,size.y-170),Vector2(290,60),interact);interact_button.hide()
	continue_button=UiKit.button(root,"В следующий бой →" if Campaign.endless else "На карту →",Vector2(size.x-330,size.y-90),Vector2(290,60),func():completed.emit(index),true);continue_button.disabled=true
	UiKit.button(root,"Вернуться в хаб",Vector2(40,165),Vector2(250,48),func():hub_requested.emit())
	preload("res://scripts/interaction_prompt.gd").attach(self,self,{"vehicle":"Механик","ability":"Инструктор","headquarters":"Штаб"}[branch],Vector3(0,0,-1),1.8,func():return not claimed)
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Выход на карту",Vector3(dressing.EXIT_CELL.x,0,dressing.EXIT_CELL.y),1.3,func():return claimed)
	if has_node("TakeVehicleLabel"):
		var vehicle_name=GarageCatalog.VEHICLES.get(vehicle,{}).get("name",vehicle)
		vehicle_prompt=preload("res://scripts/interaction_prompt.gd").attach(self,self,Texts.render("Купить")+" %s · %d" % [Texts.render(vehicle_name),VEHICLE_PRICES.get(vehicle,80)],PARKED,1.6,func():return has_node("TakeVehicleLabel"))
	# Shooting and abilities work here like in the hub and in battle (T-158, T-185).
	combat=preload("res://scripts/room_combat.gd").attach(self,avatar,walker,stand,root)
	offers=arena.reward.service_offers(branch)
	locker=preload("res://scripts/weapon_locker.gd").place(self,arena,Vector3(-3.4,0,0.5))
	vendor=preload("res://scripts/ammo_vendor.gd").place(self,arena,Vector3(-3.4,0,2.4))
## The mechanic works on the player's vehicle: the one driven now, the one waiting for the next room, or the starting one.
func current_vehicle()->String:
	if is_instance_valid(arena.player) and arena.player.kind in GarageCatalog.VEHICLES:return arena.player.kind
	if arena.pending_vehicle in GarageCatalog.VEHICLES:return arena.pending_vehicle
	var saved=str(arena.resume_checkpoint.get("hero",{}).get("kind",""))
	if saved in GarageCatalog.VEHICLES:return saved
	var start=Game.garage.starting_vehicle()
	return start if start in GarageCatalog.VEHICLES else "buggy"
func _physics_process(delta):
	# Same as the hub: the on-screen pad only for touch play.
	if is_instance_valid(dpad):dpad.visible=InputScheme.touch()
	if not is_instance_valid(modal):collect_medkits()
	if is_instance_valid(modal):
		if Input.is_action_just_pressed("pause"):close_cards()
		return
	if Input.is_action_just_pressed("pause"):preload("res://scripts/ui/pause_tablet.gd").open(self,Callable(),func():hub_requested.emit());return
	# The kit model walks only when told (T-045): idle while standing, walk cycle while moving.
	if "preview_moving" in avatar:avatar.preview_moving=moving;avatar.preview_speed=3.4
	walker.step(delta,Game.direction(),stand);moving=walker.moving;cell=walker.cell();facing=walker.facing
	interact_button.disabled=claimed or avatar.position.distance_to(Vector3(0,0,-1))>1.8
	if Game.wants_interact():interact()
## Floor the hero may stand on: the room, minus the bench and the parked vehicle; the exit opens once claimed.
func stand(p:Vector3)->bool:
	var c=Vector2i(roundi(p.x),roundi(p.z))
	if claimed and absf(p.z-dressing.EXIT_CELL.y)<.3 and p.x>=2.75 and p.x<=dressing.EXIT_CELL.x+.01:return true
	return p.x>=-3.01 and p.x<=3.01 and p.z>=-2.01 and p.z<=4.01 and c not in [Vector2i(0,-1),Vector2i(2,-1)]
func at_exit()->bool:return claimed and avatar.position.distance_to(Vector3(dressing.EXIT_CELL.x,0,dressing.EXIT_CELL.y))<1.3
func interact():
	if is_instance_valid(modal):return
	# The ammo machine and the weapon locker work before and after the choice.
	if is_instance_valid(vendor) and vendor.near(avatar):
		Game.reset_input();dpad.clear();dpad.enabled=false
		vendor.open(root,func():Game.reset_input();dpad.clear();dpad.enabled=true;modal=null);modal=vendor.modal;return
	if is_instance_valid(locker) and locker.near(avatar):
		Game.reset_input();dpad.clear();dpad.enabled=false
		locker.open(root,func():Game.reset_input();dpad.clear();dpad.enabled=true);modal=locker.modal;return
	# The parked vehicle can be bought before and after the upgrade choice (T-119).
	if near_vehicle():open_vehicle_offer();return
	# Leave only from the exit zone (T-083): a stray E elsewhere does nothing.
	if claimed:
		if at_exit():completed.emit(index);set_physics_process(false)
		return
	if avatar.position.distance_to(Vector3(0,0,-1))>1.8:return
	Game.reset_input();dpad.clear();dpad.enabled=false
	if branch=="ability":
		var salute=Visuals.box(avatar,Vector3(.27,.85,-.1),Vector3(.12,.38,.12),Color("a4ad85"));salute.rotation.z=-.8
		create_tween().tween_interval(.8).finished.connect(salute.queue_free)
	# No class ability yet (T-186): a short word from the instructor and alloy instead of upgrade cards.
	if branch=="ability" and Game.class_loadout().is_empty():early_reward();return
	modal=preload("res://scenes/ui/service_rewards.tscn").instantiate();root.add_child(modal);modal.add_to_group("selection_scope")
	var panel=modal.get_node("Panel")
	panel.get_node("Heading").text="Модификация · "+({"buggy":"Багги","apc":"БТР","tank":"Танк"}[vehicle] if branch=="vehicle" else "Штаб" if branch=="headquarters" else arena.abilities.NAMES.get(arena.abilities.selected,"Способность"))
	panel.get_node("CloseButton").pressed.connect(close_cards)
	if offers.is_empty():UiKit.label(panel,"Сначала открой и возьми способность в хабе",Vector2(25,155),Vector2(870,50),22)
	if branch=="ability":
		for slot in range(arena.abilities.slots.size()):
			var id=arena.abilities.slots[slot]
			UiKit.button(panel,arena.abilities.NAMES[id],Vector2(25+slot*290,66),Vector2(280,32),func():arena.abilities.select(id);close_cards();interact()).add_theme_font_size_override("font_size",14)
	for i in range(3):
		if i>=offers.size():panel.get_node("Card"+str(i+1)).hide();continue
		if branch=="headquarters":
			preload("res://scripts/ui/choice_card.gd").configure(panel.get_node("Card"+str(i+1)),arena.headquarters.card(offers[i]),func():claim(i));continue
		var offer=offers[i];var n=Balance.tier_power(offer.tier)
		var title={"damage":"Урон транспорта","hp":"Броня транспорта","speed":"Передвижение","rate":"Скорострельность","overhaul":"Капремонт","power":"Прочность / урон","cooldown":"Перезарядка","utility":"Особенность"}[offer.id]
		var description=arena.abilities.description(offer.id,offer.tier) if branch=="ability" else {"damage":"+%.2f урона" % ((.15 if vehicle=="buggy" else 1.0)*n),"hp":"+%d брони" % roundi(3*n),"speed":"+%.1f %% скорости машины" % (4*n),"rate":"−%d %% к паузе между выстрелами" % roundi(4*n),"overhaul":"+%d брони и +%s урона" % [roundi(1.5*n),UiKit.number(snappedf((.08 if vehicle=="buggy" else .5)*n,.01))]}[offer.id]

		if branch=="vehicle":
			var mods=arena.vehicle_mods[vehicle];var tuning=Balance.CONFIG.enemy(vehicle)
			match offer.id:
				"damage":
					var current=tuning.damage+(Game.meta_damage()+arena.damage_bonus)*(.25 if vehicle=="buggy" else 1.0)+mods.damage
					var driver=1.1+Game.class_specialization()*.05 if Game.selected_class in ["driver","engineer"] else 1.0
					description=UiKit.change_text("Урон",current*driver,(current+(.15 if vehicle=="buggy" else 1.0)*n)*driver)
				"hp":
					var driver=1.15+Game.class_specialization()*.05 if Game.selected_class in ["driver","engineer"] else 1.0
					description=UiKit.change_text("Броня",(tuning.health+mods.hp)*driver,(tuning.health+mods.hp+mini(index,6)+roundi(3*n))*driver)
				"rate":
					var now=float(mods.get("rate",1.0))
					description=UiKit.change_text("Темп",roundf(100.0/now),roundf(100.0/maxf(.7,now-.04*n)),"%")
				"speed":description=UiKit.change_text("Скорость",minf(Balance.speed_cap(),tuning.player_speed*arena.speed_multiplier*mods.speed),minf(Balance.speed_cap(),tuning.player_speed*arena.speed_multiplier*minf(1.25,mods.speed+.04*n)))
		var view={"category":"Транспорт" if branch=="vehicle" else "Способность","title":title,"detail":description,"icon":{"rate":"garage/%s_gun" % vehicle,"overhaul":"pickups/vehicle_repair"}.get(offer.id,offer.id),"heading":LootCatalog.RARITY_NAMES[offer.tier],"color":Color(LootCatalog.RARITY_COLORS[offer.tier])}
		preload("res://scripts/ui/choice_card.gd").configure(panel.get_node("Card"+str(i+1)),view,func():claim(i))
	var reroll=panel.get_node("RerollButton");Texts.set_text(reroll,"Переброс · осталось %d" % arena.rerolls_left);reroll.pressed.connect(reroll_cards)
	reroll.disabled=arena.rerolls_left<=0
	reroll.position.x=25;reroll.size.x=540
	UiKit.button(panel,"Отказаться",Vector2(590,reroll.position.y),Vector2(320,44),skip_choice)
func reroll_cards():
	if claimed or arena.rerolls_left<=0:return
	arena.rerolls_left-=1
	offers=arena.reward.service_offers(branch)
	close_cards();interact()
func claim(i: int):
	if claimed or i<0 or i>=offers.size():return
	arena.reward.apply_service_reward(branch,vehicle,index,offers[i])
	Game.sound("upgrade",self);claimed=true;close_cards();continue_button.disabled=false;interact_button.disabled=true;dressing.set_open(true)
## Alloy instead of an ability upgrade, while the class has no ability yet.
func early_reward():
	var amount=EncounterRules.chest_alloy(arena.room_index,1)
	modal=Control.new();modal.name="EarlyReward";root.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_to_group("selection_scope")
	var shade=ColorRect.new();modal.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.45)
	var screen=root.get_viewport_rect().size;var w=minf(520,screen.x-32);var h=320.0
	var box=UiKit.glass(modal,((screen-Vector2(w,h))*.5).round(),Vector2(w,h));box.name="Box"
	UiKit.accent(UiKit.label(box,"Способности ещё рано",Vector2(28,24),Vector2(w-56,36),24))
	var text=UiKit.label(box,"Первая способность класса откроется в Казарме на %d уровне. Пока держи награду." % ClassCatalog.ABILITY_LEVELS[0],Vector2(28,70),Vector2(w-56,52),16,UiKit.MUTED);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var prize=Control.new();box.add_child(prize);prize.position=Vector2(0,136);prize.size=Vector2(w,80);prize.name="Prize"
	var number=UiKit.label(prize,"+%d" % amount,Vector2(0,10),Vector2(w*.5+20,60),44,UiKit.ORANGE);number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var coin=UiKit.icon(prize,"alloy",Vector2(w*.5+32,14),Vector2(52,52))
	var ok=UiKit.button(box,"Ок",Vector2(28,h-28-58),Vector2(w-56,58),func():
		Game.earn(amount);arena.run.earned+=amount;Game.sound("upgrade",self)
		claimed=true;close_cards();continue_button.disabled=false;interact_button.disabled=true;dressing.set_open(true),true);ok.name="Ok"
	ok.focus_mode=Control.FOCUS_ALL
	(func():if is_instance_valid(ok) and ok.is_inside_tree():ok.grab_focus()).call_deferred()
	if UiKit.motion_enabled():
		# The prize drops in with a bounce, the coin spins once.
		prize.position.y=60;prize.modulate.a=0
		var t=prize.create_tween().set_parallel();t.tween_property(prize,"position:y",136.0,.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(.15);t.tween_property(prize,"modulate:a",1.0,.2).set_delay(.15)
		coin.pivot_offset=coin.size*.5;t.tween_property(coin,"scale",Vector2(-1,1),.18).set_delay(.6);t.chain().tween_property(coin,"scale",Vector2.ONE,.18)
func close_cards():
	if is_instance_valid(modal):modal.get_parent().remove_child(modal);modal.queue_free();modal=null
	Game.reset_input();dpad.clear();dpad.enabled=true

func collect_medkits():
	if arena.soldier_hp>=arena.soldier_max_hp:return
	for kit in medkits.duplicate():
		if avatar.position.distance_to(kit.position)<.6:
			arena.soldier_hp=minf(arena.soldier_max_hp,arena.soldier_hp+Game.heal_amount()*Game.bonus_power("heart"))
			if is_instance_valid(arena.player) and arena.player.kind=="soldier":arena.player.hp=arena.soldier_hp;arena.player.refresh_health()
			medkits.erase(kit);kit.queue_free();Game.sound("pickup",self)

func skip_choice():
	if claimed:return
	claimed=true;close_cards();continue_button.disabled=false;interact_button.disabled=true;dressing.set_open(true)

func near_vehicle()->bool:return branch=="vehicle" and has_node("TakeVehicleLabel") and avatar.position.distance_to(PARKED)<1.6
## Purchase window (T-119): the vehicle, what it gives, the price; «Купить» or «Отмена»; then a clear
## «Техника доставлена» with where it waits.
func open_vehicle_offer():
	var price=int(VEHICLE_PRICES.get(vehicle,80));var info=GarageCatalog.VEHICLES.get(vehicle,{})
	Game.reset_input();dpad.clear();dpad.enabled=false
	modal=Control.new();modal.name="VehicleOffer";root.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_to_group("selection_scope")
	var shade=ColorRect.new();modal.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.5)
	var size=Vector2(560,300);var panel=UiKit.glass(modal,((root.get_viewport_rect().size-size)*.5).round(),size)
	var close=func():
		if is_instance_valid(modal):modal.queue_free()
		modal=null;Game.reset_input();dpad.clear();dpad.enabled=true
	var picture=UiKit.icon(panel,vehicle,Vector2(24,24),Vector2(150,110))
	UiKit.label(panel,str(info.get("name",vehicle)),Vector2(190,24),Vector2(346,34),24)
	var text=UiKit.label(panel,"Техника ждёт на старте следующего поля: садишься в неё сразу. Броня и урон — как у твоей машины в гараже.",Vector2(190,62),Vector2(346,80),14,UiKit.MUTED);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var cost=UiKit.label(panel,"%d ◈" % price,Vector2(24,150),Vector2(150,30),22,UiKit.ORANGE if Game.credits>=price else Color("ff8a7a"));cost.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if Game.credits<price:UiKit.label(panel,Texts.render("Не хватает %d ◈") % (price-Game.credits),Vector2(190,150),Vector2(346,30),15,Color("ff8a7a"))
	UiKit.button(panel,"Отмена",Vector2(24,size.y-70),Vector2(250,48),close)
	var buy=UiKit.button(panel,"Купить · %d ◈" % price,Vector2(size.x-274,size.y-70),Vector2(250,48),func():
		if Game.credits<price:return
		Game.credits-=price;Game.save_progress();arena.pending_vehicle=vehicle;Game.sound("weapon_equip",self)
		get_node("TakeVehicleLabel").name="BoughtVehicleLabel";get_node("BoughtVehicleLabel").queue_free()
		Visuals.label3d(self,"Доставлено · ждёт на старте поля",Vector3(2.2,1.7,-.4),Color("bdf0b0"),24)
		for child in panel.get_children():child.queue_free()
		UiKit.icon(panel,vehicle,Vector2(24,24),Vector2(150,110))
		UiKit.label(panel,"Техника доставлена",Vector2(190,28),Vector2(346,34),24,Color("bdf0b0"))
		var done=UiKit.label(panel,"%s ждёт тебя на старте следующего поля." % str(info.get("name",vehicle)),Vector2(190,68),Vector2(346,60),15,UiKit.INK);done.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var ok=UiKit.button(panel,"Отлично",Vector2(size.x-274,size.y-70),Vector2(250,48),close,true);ok.grab_focus(),true)
	buy.disabled=Game.credits<price;buy.grab_focus()
