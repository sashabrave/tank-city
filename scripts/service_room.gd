extends "res://scripts/playground.gd"
## Upgrade room between fields (mechanic, instructor, HQ depot, captured command post) as a playground on the run's
## Arena (one field engine, guides/02_development/07_one_world.md): the room's dressing, its main spot, the common
## RoomLayout spots, the parked vehicle and the exit gate. The hero, shooting, abilities and the drop floor are the
## arena's. Open with arena.begin_service(index, room) (main.show_service / show_node_service).
var branch="vehicle"
var vehicle="buggy"
## RoomLayout nodes: {crate, machine, fortune, layout}.
var spots:Dictionary={}
var locker:Node3D
var vendor:Node3D
## Price to take the mechanic's parked vehicle into the next field (T-011).
const VEHICLE_PRICES={"buggy":60,"apc":110,"tank":180}
const PARKED=Vector3(2.2,0,-1.2)
var interact_button:Button
var continue_button:Button
var claimed=false
var offers: Array=[]
## Aid kits on the floor (Game.camp_level of them): the arena's own «heart» pickups.
var medkits: Array=[]
var dressing
var vehicle_prompt
## The mechanic's parked vehicle can still be bought (on foot, nothing bought yet).
var vehicle_for_sale:=false
## Yellow arrow over the station until the upgrade is taken, then green over the exit (T-226).
var guide:Node3D
## The instructor's stands as real practice targets on the field (scripts/systems/service_field.gd spawn_target).
var targets:Array=[]
## The rooms are their route stops seen up close (author, 3 Oct), like the merchant: the stop's parts, bigger and
## more detailed, in daylight on a sand floor. Without the model file the old hangar dressing stays.
const ROOM_MODELS={"vehicle":"res://assets/models/route/mechanic_room.glb","ability":"res://assets/models/route/training_room.glb","headquarters":"res://assets/models/route/workshop_room.glb","legend":"res://assets/models/route/command_post_point.glb"}
## «Захваченный КП» is a walk-in room too (author, 4 Oct 2026): the route point model up close, the legendary
## rules at its main spot (scripts/legend_stop.gd as the window), the exit opens after the choice.
const LEGEND_MODEL_SCALE:=1.45
var street=false
## The HQ depot on the route is this room with branch "headquarters" (T-215): walk to the HQ, then the cards.
## Without HQ technologies it still refuels: base repair, a reroll or a token box (moved from depot_stop.gd).
const DEPOT_SUPPLIES=[{"id":"repair","title":"Ремонт штаба","detail":"Прочность базы +1 до конца забега","icon":"repair"},{"id":"refuel","title":"Заправка","detail":"Перебросы карточек +1","icon":"reroll"},{"id":"tokens","title":"Ящик жетонов","detail":"Жетоны +4 для торговца","icon":"token"}]
## Stands of the training yard (training_room.glb): practice targets stand on them.
const TARGET_STANDS=[Vector3(2.3,0,-1.2),Vector3(3.85,0,-2.85)]
var supplies=false
## The main spot (station) and the parked vehicle's bay take their floor cells; in the training yard the near
## stand is a practice target (an actor, solid by itself) instead of a blocked cell.
func blocked_floor()->Array:return [Vector2i(0,-1)] if branch=="ability" else [Vector2i(0,-1),Vector2i(2,-1)]
func exit_open()->bool:return claimed
func _ready():
	vehicle=current_vehicle()
	street=ResourceLoader.exists(ROOM_MODELS[branch])
	var positions=[]
	for x in range(-4,5):
		for z in range(-4 if street else -3,5):positions.append(Vector3(x,0,z))
	Visuals.tiled_floor(self,positions,Color("98917f") if street else Color("7d8784"))
	if street:Visuals.box(self,Vector3(0,-.4,0),Vector3(9.3,.6,9.3),Color("7d7462"))
	else:Visuals.box(self,Vector3(0,-.4,.5),Vector3(9.3,.6,8.3),Color("4e5856"))
	dressing=preload("res://scripts/service_dressing.gd").new();dressing.branch=branch;dressing.vehicle=vehicle;dressing.street=street;add_child(dressing)
	# Cozy surroundings (2026-10-03): the biome of the last field close around the room, fair weather, and fixed
	# decorative lights — a festoon over the far edge and two masts at the front corners.
	if street:
		preload("res://scripts/location_ambience.gd").room(self,arena,index,4.9)
		preload("res://scripts/room_lights.gd").build(self,-4.5)
	if street:
		var stop:Node3D=load(ROOM_MODELS[branch]).instantiate();stop.name="StopModel";add_child(stop)
		if branch=="legend":stop.scale=Vector3.ONE*LEGEND_MODEL_SCALE;stop.position=Vector3(0,0,-2.0)
		preload("res://scripts/route_miniatures.gd").library_surfaces(stop)
	if branch=="vehicle":
		if not street:Visuals.model("workbench",self,Vector3(0,0,-1))
		Visuals.model(vehicle,self,Vector3(2.2,.16,-1.2))
		# T-011: when the soldier is on foot, the parked vehicle can be taken into the next field for alloy.
		# T-284: the same vehicle already yours — a sign «Уже есть» over it; a different one — «Купить и заменить».
		vehicle_for_sale=owned_vehicle()!=vehicle
		if not vehicle_for_sale:Visuals.label3d(self,"Уже есть",PARKED+Vector3(0,1.6,0),Color("bdf0b0"),30)
	elif branch=="headquarters":
		# Street room: the HQ stands on the ramp under the canopy, its nose just behind the main spot.
		Visuals.model("base",self,Vector3(0,.18,-2.6) if street else Vector3(0,0,-1))
	elif not street:
		Visuals.box(self,Vector3(0,.35,-1),Vector3(1.4,.7,1.4),Color("717d79"))
		var statue=Visuals.model("soldier",self,Vector3(0,.7,-1));statue.scale=Vector3.ONE*1.5;Visuals.tint_model(statue,Color("738982"))
	# No standing signs over the station, the vehicle or the machines (T-226): the prompt on approach says what
	# it is and what it costs; a yellow arrow shows where the upgrade is taken, then a green one the exit.
	continue_button=build_ui({"vehicle":"Полевой механик","ability":"Подготовка бойца","headquarters":"Депо штаба","legend":"Захваченный КП"}[branch],{"vehicle":"Модификация транспорта","ability":"Модификация способности","headquarters":"Модуль штаба или припасы на вылазку","legend":"Легендарное правило — только здесь"}[branch],"В следующий бой →" if Campaign.endless else "На карту →",func():leave())
	continue_button.disabled=true
	var size=get_viewport().get_visible_rect().size
	interact_button=UiKit.button(root,"Улучшение [E]",Vector2(size.x-330,size.y-170),Vector2(290,60),interact);interact_button.hide()
	preload("res://scripts/interaction_prompt.gd").attach(self,self,{"vehicle":"Механик · улучшение машины","ability":"Инструктор · улучшение способности","headquarters":"Штаб · модуль или припасы","legend":"Сейф КП · легендарное правило"}[branch],Vector3(0,0,-1),1.8,func():return not claimed)
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Выход на карту",Vector3(dressing.EXIT_CELL.x,0,dressing.EXIT_CELL.y),1.3,func():return claimed)
	if vehicle_for_sale:
		var vehicle_name=GarageCatalog.VEHICLES.get(vehicle,{}).get("name",vehicle)
		vehicle_prompt=preload("res://scripts/interaction_prompt.gd").attach(self,self,Texts.render(buy_word())+" %s · %d ◈" % [Texts.render(vehicle_name),VEHICLE_PRICES.get(vehicle,80)],PARKED,1.6,func():return vehicle_for_sale)
	guide=preload("res://scripts/room_guide_arrow.gd").attach(self)
	pick_ability()
	offers=arena.reward.service_offers(branch) if branch!="legend" else []
	supplies=branch=="headquarters" and offers.is_empty()
	if supplies:offers=DEPOT_SUPPLIES.duplicate(true)
	# Common room layout (RoomLayout): weapon crate, a vending machine and the «Фортуна» spot in the same places
	# in every upgrade room and at the merchant.
	spots=RoomLayout.furnish(self,arena,index,false)
	locker=spots.crate;vendor=spots.machine
## The hero is on the field: aid kits lie as the field's own «heart» pickups, the instructor's stands take hits.
func field_ready():
	for i in range(Game.camp_level):
		medkits.append(arena.reward.place_supply(Vector3([-2.4,-.8,.8,2.4][i],0,2),"heart"))
	if branch=="ability":
		for at in TARGET_STANDS:targets.append(arena.service.spawn_target(at))
## The mechanic works on the player's vehicle: the one driven now, the one waiting for the next room, or the starting one.
func current_vehicle()->String:
	var kind=arena.hero_kind()
	if kind in GarageCatalog.VEHICLES:return kind
	var start=Game.garage.starting_vehicle()
	return start if start in GarageCatalog.VEHICLES else "buggy"
func _process(delta):
	super(delta)
	update_guide()
	if is_instance_valid(avatar):interact_button.disabled=claimed or avatar.position.distance_to(Vector3(0,0,-1))>1.8
func update_guide():
	if not is_instance_valid(guide):return
	if claimed:guide.point(Vector3(dressing.EXIT_CELL.x+.25,0,dressing.EXIT_CELL.y),3.7,"ready")  # over the «Выход» sign
	else:guide.point(Vector3(0,0,-1),3.3 if branch=="headquarters" else 2.6,"goal")
func at_exit()->bool:return claimed and is_instance_valid(avatar) and avatar.position.distance_to(Vector3(dressing.EXIT_CELL.x,0,dressing.EXIT_CELL.y))<1.3
## Off to the map (or the next battle): the same completion signal as ever, once.
func leave():
	if not claimed:return
	set_process(false);completed.emit(index)
func interact():
	if preload("res://scripts/ui/drop_prompt.gd").engaged(self):return
	if window_open() or not is_instance_valid(avatar):return
	# The room spots (weapon crate, vending machine, fortune) work before and after the choice.
	var spot=RoomLayout.near(spots,avatar)
	if spot:
		Game.reset_input()
		var done=func():Game.reset_input();modal=null
		if spot.has_method("use"):spot.use(root,done)
		else:spot.open(root,done)
		if "modal" in spot and is_instance_valid(spot.modal):modal=spot.modal
		return
	# The parked vehicle can be bought before and after the upgrade choice (T-119).
	if near_vehicle():open_vehicle_offer();return
	# Leave only from the exit zone (T-083): a stray E elsewhere does nothing.
	if claimed:
		if at_exit():leave()
		return
	if avatar.position.distance_to(Vector3(0,0,-1))>1.8:return
	Game.reset_input()
	if branch=="ability":
		var salute=Visuals.box(avatar,Vector3(.27,.85,-.1),Vector3(.12,.38,.12),Color("a4ad85"));salute.rotation.z=-.8
		create_tween().tween_interval(.8).finished.connect(salute.queue_free)
	# No class ability yet (T-186): a short word from the instructor and alloy instead of upgrade cards.
	if branch=="ability" and Game.class_loadout().is_empty():early_reward();return
	if branch=="legend":open_legend();return
	modal=preload("res://scenes/ui/service_rewards.tscn").instantiate();root.add_child(modal);modal.add_to_group("selection_scope")
	var panel=modal.get_node("Panel")
	Texts.set_text(panel.get_node("Heading"),"Депо · Штаб" if branch=="headquarters" else "Модификация · "+({"buggy":"Багги","apc":"БТР","tank":"Танк"}[vehicle] if branch=="vehicle" else arena.abilities.NAMES.get(arena.abilities.selected,"Способность")))
	panel.get_node("CloseButton").pressed.connect(close_cards)
	if offers.is_empty():UiKit.label(panel,"Сначала открой и возьми способность в хабе",Vector2(25,155),Vector2(870,50),22)
	for i in range(3):
		if i>=offers.size():panel.get_node("Card"+str(i+1)).hide();continue
		if branch=="headquarters":
			var card=arena.headquarters.card(offers[i]) if not supplies else {"category":"Депо","title":offers[i].title,"detail":offers[i].detail,"icon":offers[i].icon,"heading":"","color":Color(LootCatalog.RARITY_COLORS[0]),"disabled":false,"button":"Выбрать"}
			preload("res://scripts/ui/choice_card.gd").configure(panel.get_node("Card"+str(i+1)),card,func():claim(i));continue
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
		var icon={"rate":"garage/%s_gun" % vehicle,"overhaul":"pickups/vehicle_repair"}.get(offer.id,offer.id)
		if branch=="ability":icon="abilities/"+str(arena.abilities.selected)  # the card shows whose parameter it is (T-283)
		var view={"category":"Транспорт" if branch=="vehicle" else "Способность","title":title,"detail":description,"icon":icon,"heading":LootCatalog.RARITY_NAMES[offer.tier],"color":Color(LootCatalog.RARITY_COLORS[offer.tier])}
		preload("res://scripts/ui/choice_card.gd").configure(panel.get_node("Card"+str(i+1)),view,func():claim(i))
	var reroll=panel.get_node("RerollButton");Texts.set_text(reroll,"Переброс · осталось %d" % arena.rerolls_left);reroll.pressed.connect(reroll_cards)
	reroll.disabled=arena.rerolls_left<=0 or supplies
	reroll.position.x=25;reroll.size.x=540
	UiKit.button(panel,"Отказаться",Vector2(590,reroll.position.y),Vector2(320,44),ask_skip)
## One ability per visit (T-282, author): the instructor works on a random one of the hero's abilities (Q or gadget);
## no tabs to switch — a reroll may land on another one.
func pick_ability():
	if branch!="ability" or arena.abilities.slots.is_empty():return
	var slots=arena.abilities.slots
	arena.abilities.select(slots[arena.run.combat_rng.randi_range(0,slots.size()-1)])
func reroll_cards():
	if claimed or arena.rerolls_left<=0 or supplies:return
	arena.rerolls_left-=1
	pick_ability()
	offers=arena.reward.service_offers(branch)
	close_cards();interact()
func claim(i: int):
	if claimed or i<0 or i>=offers.size():return
	if supplies:
		match str(offers[i].id):
			"repair":arena.headquarters.basic_hp+=1
			"refuel":arena.rerolls_left+=1
			"tokens":arena.run.tokens+=4
	else:arena.reward.apply_service_reward(branch,vehicle,index,offers[i])
	Game.sound("upgrade",self);close_cards();open_exit()
## The choice is made (taken, skipped or the early reward): the gate turns green and its cell opens on the field.
func open_exit():
	claimed=true;continue_button.disabled=false;interact_button.disabled=true;dressing.set_open(true)
	if arena.peaceful():arena.service.unblock(dressing.EXIT_CELL)
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
		close_cards();open_exit(),true);ok.name="Ok"
	ok.focus_mode=Control.FOCUS_ALL
	(func():if is_instance_valid(ok) and ok.is_inside_tree():ok.grab_focus()).call_deferred()
	if UiKit.motion_enabled():
		# The prize drops in with a bounce, the coin spins once.
		prize.position.y=60;prize.modulate.a=0
		var t=prize.create_tween().set_parallel();t.tween_property(prize,"position:y",136.0,.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(.15);t.tween_property(prize,"modulate:a",1.0,.2).set_delay(.15)
		coin.pivot_offset=coin.size*.5;t.tween_property(coin,"scale",Vector2(-1,1),.18).set_delay(.6);t.chain().tween_property(coin,"scale",Vector2.ONE,.18)
func close_cards():close_window()

## «Отказаться» asks first (T-217): the card can only be taken here, so leaving empty-handed is a choice.
func ask_skip():
	if claimed or not is_instance_valid(modal):return
	if modal.has_node("SkipConfirm"):return
	preload("res://scripts/ui/skip_confirm.gd").open(modal,skip_choice)
func skip_choice():
	if claimed:return
	close_cards();open_exit()

## The vehicle the hero takes into the next field: the one driven before the room or one already bought here; "" on foot.
func owned_vehicle()->String:return arena.service.vehicle_kind()
func buy_word()->String:return "Купить и заменить" if owned_vehicle()!="" else "Купить"
## The captured post's safe: three legendary cards (or none); either way the post closes and the exit opens.
func open_legend():
	var post=preload("res://scripts/legend_stop.gd").new();post.arena=arena;post.index=index;root.add_child(post);modal=post
	post.done.connect(func():
		modal=null;open_exit();Game.reset_input())
func near_vehicle()->bool:return branch=="vehicle" and vehicle_for_sale and is_instance_valid(avatar) and avatar.position.distance_to(PARKED)<1.6
## Purchase window (T-119): the vehicle, what it gives, the price; «Купить» or «Отмена»; then a clear
## «Техника доставлена» with where it waits.
func open_vehicle_offer():
	var price=int(VEHICLE_PRICES.get(vehicle,80));var info=GarageCatalog.VEHICLES.get(vehicle,{})
	Game.reset_input()
	modal=Control.new();modal.name="VehicleOffer";root.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_to_group("selection_scope")
	var shade=ColorRect.new();modal.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.5)
	var size=Vector2(560,300);var panel=UiKit.glass(modal,((root.get_viewport_rect().size-size)*.5).round(),size)
	var close=func():close_window()
	UiKit.icon(panel,vehicle,Vector2(24,24),Vector2(150,110))
	UiKit.label(panel,str(info.get("name",vehicle)),Vector2(190,24),Vector2(346,34),24)
	var owned=owned_vehicle();var replace_note=(Texts.render(" Заменит твою машину: %s.") % Texts.render(str(GarageCatalog.VEHICLES.get(owned,{}).get("name",owned)))) if owned!="" else ""
	var text=UiKit.label(panel,Texts.render("Техника ждёт на старте следующего поля: садишься в неё сразу. Броня и урон — как у твоей машины в гараже.")+replace_note,Vector2(190,62),Vector2(346,80),14,UiKit.MUTED);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var cost=UiKit.label(panel,"%d ◈" % price,Vector2(24,150),Vector2(150,30),22,UiKit.ORANGE if Game.credits>=price else Color("ff8a7a"));cost.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if Game.credits<price:UiKit.label(panel,Texts.render("Не хватает %d ◈") % (price-Game.credits),Vector2(190,150),Vector2(346,30),15,Color("ff8a7a"))
	UiKit.button(panel,"Отмена",Vector2(24,size.y-70),Vector2(250,48),close)
	var buy=UiKit.button(panel,Texts.render(buy_word())+" · %d ◈" % price,Vector2(size.x-274,size.y-70),Vector2(250,48),func():
		if Game.credits<price:return
		Game.credits-=price;Game.save_progress();arena.pending_vehicle=vehicle;Game.sound("weapon_equip",self)
		vehicle_for_sale=false
		for child in panel.get_children():child.queue_free()
		UiKit.icon(panel,vehicle,Vector2(24,24),Vector2(150,110))
		UiKit.label(panel,"Техника доставлена",Vector2(190,28),Vector2(346,34),24,Color("bdf0b0"))
		var done=UiKit.label(panel,"%s ждёт тебя на старте следующего поля." % str(info.get("name",vehicle)),Vector2(190,68),Vector2(346,60),15,UiKit.INK);done.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var ok=UiKit.button(panel,"Отлично",Vector2(size.x-274,size.y-70),Vector2(250,48),close,true);ok.grab_focus(),true)
	buy.disabled=Game.credits<price;buy.grab_focus()
