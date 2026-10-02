extends Node3D
signal completed(index: int)
signal hub_requested
var arena
var index=2
var branch="vehicle"
var vehicle="buggy"
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
func _ready():
	add_to_group("notification_context")
	vehicle=current_vehicle()
	Visuals.setup_world(self,12,Vector3.ZERO)
	var positions=[]
	for x in range(-4,5):
		for z in range(-3,5):positions.append(Vector3(x,0,z))
	Visuals.tiled_floor(self,positions,Color("7d8784"))
	Visuals.box(self,Vector3(0,-.4,.5),Vector3(9.3,.6,8.3),Color("4e5856"))
	dressing=preload("res://scripts/service_dressing.gd").new();dressing.branch=branch;dressing.vehicle=vehicle;add_child(dressing)
	if branch=="vehicle":
		Visuals.model("workbench",self,Vector3(0,0,-1))
		Visuals.model(vehicle,self,Vector3(2.2,.16,-1.2))
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
	offers=arena.reward.service_offers(branch)
## The mechanic works on the player's vehicle: the one driven now, the one waiting for the next room, or the starting one.
func current_vehicle()->String:
	if is_instance_valid(arena.player) and arena.player.kind in GarageCatalog.VEHICLES:return arena.player.kind
	if arena.pending_vehicle in GarageCatalog.VEHICLES:return arena.pending_vehicle
	var saved=str(arena.resume_checkpoint.get("hero",{}).get("kind",""))
	if saved in GarageCatalog.VEHICLES:return saved
	var start=Game.garage.starting_vehicle()
	return start if start in GarageCatalog.VEHICLES else "buggy"
func _physics_process(delta):
	if not is_instance_valid(modal):collect_medkits()
	if is_instance_valid(modal):
		if Input.is_action_just_pressed("pause"):close_cards()
		return
	if Input.is_action_just_pressed("pause"):preload("res://scripts/ui/pause_tablet.gd").open(self,Callable(),func():hub_requested.emit());return
	if moving:
		avatar.position=avatar.position.move_toward(destination,3.8*delta)
		if avatar.position.distance_to(destination)<.01:moving=false
	# The kit model walks only when told (T-045): idle while standing, walk cycle while moving.
	if "preview_moving" in avatar:avatar.preview_moving=moving;avatar.preview_speed=3.4
	else:
		var dir=Game.direction()
		if dir!=Vector2i.ZERO:
			var next=cell+dir;facing=dir;avatar.rotation.y=atan2(-float(dir.x),-float(dir.y))
			var exit=next==dressing.EXIT_CELL and claimed
			if exit or (next.x>=-3 and next.x<=3 and next.y>=-2 and next.y<=4 and next not in [Vector2i(0,-1),Vector2i(2,-1)]):
				cell=next;destination=Vector3(cell.x,0,cell.y);moving=true
	if claimed and not moving and cell==dressing.EXIT_CELL:completed.emit(index);set_physics_process(false);return
	interact_button.disabled=claimed or avatar.position.distance_to(Vector3(0,0,-1))>1.8
	if Game.wants_interact():interact()
func interact():
	if claimed:
		completed.emit(index);return
	if is_instance_valid(modal) or avatar.position.distance_to(Vector3(0,0,-1))>1.8:return
	Game.reset_input();dpad.clear();dpad.enabled=false
	if branch=="ability":
		var salute=Visuals.box(avatar,Vector3(.27,.85,-.1),Vector3(.12,.38,.12),Color("a4ad85"));salute.rotation.z=-.8
		create_tween().tween_interval(.8).finished.connect(salute.queue_free)
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
		var title={"damage":"Урон транспорта","hp":"Броня транспорта","speed":"Передвижение","power":"Прочность / урон","cooldown":"Перезарядка","utility":"Особенность"}[offer.id]
		var description=arena.abilities.description(offer.id,offer.tier) if branch=="ability" else {"damage":"+%.2f урона" % ((.15 if vehicle=="buggy" else 1.0)*n),"hp":"+%d брони" % roundi(3*n),"speed":"+%.1f %% скорости машины" % (4*n)}[offer.id]

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
				"speed":description=UiKit.change_text("Скорость",minf(Balance.speed_cap(),tuning.player_speed*arena.speed_multiplier*mods.speed),minf(Balance.speed_cap(),tuning.player_speed*arena.speed_multiplier*minf(1.25,mods.speed+.04*n)))
		var view={"category":"Транспорт" if branch=="vehicle" else "Способность","title":title,"detail":description,"icon":offer.id,"heading":LootCatalog.RARITY_NAMES[offer.tier],"color":Color(LootCatalog.RARITY_COLORS[offer.tier])}
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
