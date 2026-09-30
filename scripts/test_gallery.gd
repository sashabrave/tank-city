extends "res://scripts/arena.gd"
## Read-only model gallery. Reuses real actors/board builders, but never runs battle/rewards.
signal hub_requested
var exhibits:Array=[]
var sections:Dictionary={}
var section_name=""
var section_z=0
var section_count=0
var camera_target=Vector3.ZERO
var camera_offset=Vector3.ZERO
var chosen=0
var attacks_enabled=true
var demo_shots:Array=[]
var exhibit_menu:OptionButton
var section_menu:OptionButton
var dragging=false
var spin_items:Array=[]
var follow_player=true
var respawns:Array=[]
var attack_count=0
var respawn_count=0

func _ready():
	auto_pause_enabled=false;phase="combat";grid_size=400;run_seed=731;combat_rng.seed=731
	for id in LOOT.WEAPONS:weapon_mods[id]={"damage":0.0,"interval":1.0,"intercept":0.0}
	abilities=load("res://scripts/run_ability.gd").new();abilities.arena=self;abilities.selected="barrier";abilities.setup()
	camera=Visuals.setup_world(self,9.5,Vector3.ZERO);camera_offset=camera.position
	build_exhibits()
	# A mesh-wide tint supersedes per-surface recolors; remove those hidden overrides.
	for mesh in find_children("*","MeshInstance3D",true,false):
		if mesh.material_override and mesh.mesh:
			for surface in range(mesh.mesh.get_surface_count()):mesh.set_surface_override_material(surface,null)
	weapon=Game.selected_weapon;player=spawn_actor("soldier",Vector2i(0,3),true);player.invulnerable=INF;player.facing=Vector2i.UP;player.model.rotation.y=0
	build_gallery_ui();focus_exhibit(0)

func world_pos(cell:Vector2i)->Vector3:return Vector3(cell.x,0,cell.y)
func inside(cell:Vector2i)->bool:return cell.x>=-5 and cell.x<=30 and cell.y>=-5 and cell.y<section_z+ceili(section_count/4.0)*9+10
func grid_pos(pos:Vector3)->Vector2i:return Vector2i(roundi(pos.x),roundi(pos.z))
func floating_number(pos:Vector3,value:float):
	if is_instance_valid(player):super.floating_number(pos,value)
func toast(_text:String):pass

func section(title:String):
	if not exhibits.is_empty():section_z+=ceili(section_count/4.0)*9+5
	section_name=title;section_count=0;sections[title]=exhibits.size()

func stand(title:String,detail:String="")->Vector2i:
	var cell=Vector2i((section_count%4)*8,section_z+int(section_count/4.0)*9)
	section_count+=1
	var pos=world_pos(cell)
	Visuals.box(self,pos+Vector3(0,-.22,1),Vector3(6.5,.35,7.5),Color("a6b29f"))
	var tiles=[]
	for x in range(-3,4):
		for z in range(-2,5):tiles.append(pos+Vector3(x,-.03,z))
	Visuals.tiled_floor(self,tiles,Color("929b90"))
	var label=Visuals.label3d(self,title,pos+Vector3(0,.15,4.15),Color("f7f2da"),32);label.pixel_size=.009
	if detail!="":Visuals.label3d(self,detail,pos+Vector3(0,.1,4.9),Color("e5eddf"),21).pixel_size=.006
	exhibits.append({"title":title,"section":section_name,"cell":cell,"actor":null,"attack_in":2.0+fmod(exhibits.size()*1.37,4.0)})
	return cell

func actor_exhibit(kind:String,title:String,rank_value:int=1,allied_value:bool=false,boss_stage:int=0,twins:bool=false):
	var cell=stand(title,"Атака вперёд · неподвижная цель" if not allied_value else "Союзная техника")
	room_index=boss_stage;twin_boss=twins
	var actor=spawn_actor(kind,cell,false,allied_value,rank_value)
	actor.position=world_pos(cell);actor.set_physics_process(false);actor.facing=Vector2i.DOWN;actor.model.rotation.y=actor.angle_for(actor.facing)
	actor.health_label.position.y=4 if kind=="boss" else actor.health_label.position.y
	exhibits.back().actor=actor
	room_index=0;twin_boss=false
	return actor

func build_exhibits():
	section("Пехота и дроны")
	var names={"soldier":"Солдат","grenadier":"Гренадёр","shield":"Щитоносец","sniper":"Снайпер","drone":"Дрон-камикадзе","flyer":"Летающий стрелок"}
	for kind in names:
		for rank_value in [1,2]:actor_exhibit(kind,names[kind]+" · ранг "+str(rank_value),rank_value)
	section("Техника и командиры")
	for kind in ["buggy","apc","mortar","tank"]:
		for rank_value in [1,2]:actor_exhibit(kind,{"buggy":"Багги","apc":"БТР","mortar":"Артиллерия","tank":"Танк"}[kind]+" · ранг "+str(rank_value),rank_value)
	var elite=actor_exhibit("soldier","Минибосс · солдат ★",2);elite.elite=true;elite.max_hp*=2.5;elite.hp=elite.max_hp;elite.refresh_health();Visuals.tint_model(elite.model,Color("9d453e"));Visuals.label3d(elite,"★",Vector3(0,2,0),Color("ffd164"),36)
	section("Боссы")
	actor_exhibit("boss","Генерал I · 4×4",1,false,6)
	actor_exhibit("boss","Генерал I · вариант 2×2",1,false,6,true)
	actor_exhibit("boss","Генерал II · 4×4",1,false,15)
	actor_exhibit("boss","Генерал II · вариант 2×2",1,false,15,true)
	var giga=actor_exhibit("boss","Гигабосс · силовое поле",1,false,16)
	if is_instance_valid(giga.force_field):giga.force_field.show()
	section("Блоки и разрушение")
	add_wall(stand("Бетон · непробиваемый"),-1)
	for stage in range(3):
		var c=stand(["Кирпич · целый","Кирпич · трещины","Кирпич · сильное разрушение"][stage]);add_wall(c,6)
		if stage>0:damage_wall(c,stage*2)
	add_trench(stand("Окоп · пули проходят"))
	Visuals.model("net",self,world_pos(stand("Маскировочная сетка")))
	for stage in range(3):
		var c=stand("Преграда · состояние "+str(stage+1));add_barrier(c,12)
		if stage>0:damage_wall(c,stage*4)
	room_index=7;add_wall(stand("Мешки цемента · зона 2"),6);room_index=0
	var armored=stand("Армированный кирпич");room_index=7;board.add_reinforced_wall(armored,12);room_index=0
	var reinforced=stand("Укреплённая ограда базы");add_wall(reinforced,9);Visuals.box(walls[reinforced].node,Vector3(0,1.07,0),Vector3(.98,.08,.98),Color("668794"))
	add_barrel(stand("Взрывоопасная бочка"));add_rubble(stand("Обломки · проходимые"))
	section("Бонусы и трофеи")
	for id in LOOT.BONUSES:
		var node=Node3D.new();add_child(node);node.position=world_pos(stand(LOOT.BONUSES[id].name,LOOT.BONUSES[id].effect));spin_items.append(LOOT.visual(node,id))
	var chest_cell=stand("Военный сундук","Награда за командира");drop_recipe(chest_cell,{})
	for id in ["recipe","alloy","core"]:icon_exhibit(id,{"recipe":"Чертёж","alloy":"Сплав","core":"Секретные документы"}[id])
	section("Герой и оружие")
	for id in LOOT.WEAPONS:
		var cell=stand(LOOT.WEAPONS[id].name,"Оружие на модели героя");weapon=id
		var hero=spawn_actor("soldier",cell,true);hero.set_physics_process(false);hero.model.rotation.y=PI
	weapon="pistol"
	for id in Game.CLASSES:
		var cell=stand("Класс · "+Game.CLASSES[id].name,Game.CLASSES[id].desc);Visuals.model("soldier",self,world_pos(cell))
	section("Союзники и доставка")
	for kind in ["buggy","apc","tank","mortar","flyer"]:actor_exhibit(kind,{"buggy":"Свой багги","apc":"Свой БТР","tank":"Свой танк","mortar":"Турель базы","flyer":"Дрон-помощник"}[kind],1,true)
	for kind in ["buggy","apc","tank"]:
		var c=stand("Подбитая техника · "+kind);var wreck=make_wreck(kind,c,Vector2i.DOWN,true);wreck.set_physics_process(false);wreck.timer=2.5;wreck.boardable=true;wreck.refresh_label()
	var delivery=make_wreck("tank",stand("Парашют · доставка танка"),Vector2i.DOWN,false);delivery.set_physics_process(false);delivery.start_delivery(4);delivery.position.y=.7
	section("Способности")
	for id in ["gas","mine","airstrike"]:
		var cell=stand(AbilityCatalog.DATA[id].name);var effect=load("res://scripts/ability_effect.gd").new();effect.arena=self;effect.kind=id;effect.position=world_pos(cell);add_child(effect);effect.set_physics_process(false)
		if id=="airstrike":
			effect.visual.position=Vector3(0,1.5,0);spin_items.append(effect.visual.get_node("Rotor"))
	var cloak=Visuals.model("soldier",self,world_pos(stand("Маскировка")))
	for mesh in cloak.find_children("*","GeometryInstance3D",true,false):mesh.transparency=.65
	for id in ["barrier","grenade","laser","ally_drone","comrade"]:icon_exhibit(id,AbilityCatalog.DATA[id].name)
	section("Хаб и окружение")
	for id in ["base","gate","workbench","crate","turret","tile"]:Visuals.model(id,self,world_pos(stand({"base":"База","gate":"Арка · В бой!","workbench":"Верстак","crate":"Ящик","turret":"Модель стационарной турели","tile":"Клетка поля"}[id])))
	for id in ["bench_character","bench_weapons","bench_bonuses","parking"]:Visuals.model(id,self,world_pos(stand({"bench_character":"Прокачка базы","bench_weapons":"Оружейный верстак","bench_bonuses":"Верстак бонусов","parking":"Стоянка · бетон"}[id])))
	var statue=world_pos(stand("Статуя генерала"));Visuals.box(self,statue+Vector3(0,.35,0),Vector3(1.4,.7,1.4),Color("717d79"));var model=Visuals.model("soldier",self,statue+Vector3.UP*.7);model.scale=Vector3.ONE*1.5;Visuals.tint_model(model,Color("738982"))
	var capsule=Visuals.box(self,world_pos(stand("Капсула персонажей"))+Vector3.UP*.65,Vector3(.8,1.3,.8),Color("91b3b0"));Visuals.model("soldier",capsule,Vector3(0,-.3,0)).scale=Vector3.ONE*.6
	var locked_cell=stand("Закрытая ячейка верстака");Visuals.box(self,world_pos(locked_cell),Vector3(1.5,.08,1.5),Color("829080"));Visuals.label3d(self,"🔒",world_pos(locked_cell)+Vector3.UP,Color("f2e3bd"),42)
	var gen=world_pos(stand("Генератор силового поля"));Visuals.box(self,gen+Vector3.UP*.6,Vector3(.8,1.2,.8),Color("689baf"));Visuals.ring(self,Color("91dcf4"),.65).position=gen+Vector3.UP*.05
	var flag_pos=world_pos(stand("Флаг · награда поля боя"));Visuals.box(self,flag_pos+Vector3.UP,Vector3(.06,2,.06),Color("eee9d8"));Visuals.box(self,flag_pos+Vector3(.35,1.7,0),Vector3(.7,.45,.07),Color("7cb56b"))

	var dummy=world_pos(stand("Манекен тира"));Visuals.box(self,dummy+Vector3(0,.65,0),Vector3(.14,1.3,.14),Color("77634b"));Visuals.box(self,dummy+Vector3(0,.9,0),Vector3(.58,.75,.3),Color("be9a62"));Visuals.box(self,dummy+Vector3(0,.9,.17),Vector3(.25,.25,.04),Color("994837"))
	section("Декорации локаций")
	for biome in LocationStyle.TYPES:
		var biome_cell=stand(LocationStyle.NAMES[biome]);var shape=Node3D.new();add_child(shape);shape.position=world_pos(biome_cell)
		var builder=load("res://scripts/location_ambience.gd").new();builder.biome=biome;builder.miniature=true;builder.make_shape(shape,combat_rng);builder.free()

func icon_exhibit(id:String,title:String):
	var pos=world_pos(stand(title));var sprite=Sprite3D.new();sprite.texture=UiKit.icon_texture(id);sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size=1.4/maxf(1,sprite.texture.get_width());add_child(sprite);sprite.position=pos+Vector3.UP

func build_gallery_ui():
	var canvas=CanvasLayer.new();add_child(canvas)
	var root=preload("res://scenes/ui/gallery_screen.tscn").instantiate();canvas.add_child(root)
	section_menu=root.get_node("SectionMenu");section_menu.clear()
	for title in sections:section_menu.add_item(title)
	section_menu.item_selected.connect(func(i):focus_exhibit(sections[sections.keys()[i]]))
	exhibit_menu=root.get_node("ExhibitMenu");exhibit_menu.clear()
	for item in exhibits:exhibit_menu.add_item(item.title)
	exhibit_menu.item_selected.connect(focus_exhibit)
	root.get_node("PreviousButton").pressed.connect(func():focus_exhibit(posmod(chosen-1,exhibits.size())))
	root.get_node("NextButton").pressed.connect(func():focus_exhibit((chosen+1)%exhibits.size()))
	root.get_node("ZoomInButton").pressed.connect(func():zoom(-1.5));root.get_node("ZoomOutButton").pressed.connect(func():zoom(1.5))
	var toggle=root.get_node("AttacksButton")
	toggle.pressed.connect(func():attacks_enabled=not attacks_enabled;Texts.set_text(toggle,"Атаки: вкл." if attacks_enabled else "Атаки: выкл."))
	root.get_node("HubButton").pressed.connect(func():hub_requested.emit())
	root.get_node("FollowButton").pressed.connect(func():follow_player=true)
	var weapons=root.get_node("WeaponMenu");weapons.clear()
	for id in LOOT.WEAPONS:weapons.add_item(LOOT.WEAPONS[id].name)
	weapons.select(LOOT.WEAPONS.keys().find(weapon))
	weapons.item_selected.connect(func(i):weapon=LOOT.WEAPONS.keys()[i];player.apply_weapon())

func focus_exhibit(index:int):
	chosen=clampi(index,0,exhibits.size()-1);camera_target=world_pos(exhibits[chosen].cell)+Vector3(0,0,1)
	if is_instance_valid(player):
		player.cell=exhibits[chosen].cell+Vector2i(0,3);player.destination=player.cell;player.position=world_pos(player.cell);player.moving=false;player.facing=Vector2i.UP;player.model.rotation.y=0;player.turn_left=0
	follow_player=false
	exhibit_menu.select(chosen);section_menu.select(sections.keys().find(exhibits[chosen].section));update_camera()
func zoom(amount:float):camera.size=clampf(camera.size+amount,5,26)
func update_camera():
	camera.position=camera_target+camera_offset;camera.look_at(camera_target)
	camera.position+=camera.basis.y*1.0
func _unhandled_input(event):
	if event.is_action_pressed("pause"):hub_requested.emit();get_viewport().set_input_as_handled();return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom(-1)
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom(1)
	if event is InputEventMouseMotion and dragging and event.button_mask&MOUSE_BUTTON_MASK_LEFT:follow_player=false;pan(event.relative)
	if event is InputEventScreenDrag:follow_player=false;pan(event.relative)
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_PLUS,KEY_EQUAL,KEY_KP_ADD]:zoom(-1)
		if event.keycode in [KEY_MINUS,KEY_KP_SUBTRACT]:zoom(1)
func pan(relative:Vector2):
	var right=camera.global_basis.x;var down=Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
	camera_target-=(right*relative.x+down*relative.y)*camera.size/get_viewport().get_visible_rect().size.y;update_camera()
func _physics_process(delta):
	elapsed+=delta
	if Game.direction()!=Vector2i.ZERO:follow_player=true
	if follow_player and is_instance_valid(player):
		camera_target=camera_target.lerp(player.position+Vector3(0,0,-1.5),minf(1,delta*5));update_camera()
	for item in respawns.duplicate():
		item.left-=delta
		Texts.set_text(item.label,"↻ %.1f с" % maxf(0,item.left))
		if item.left<=0:
			var actor=item.actor;actor.dead=false;actor.hp=actor.max_hp;actor.show();actor.refresh_health();item.label.queue_free();respawns.erase(item);respawn_count+=1
	for item in exhibits:
		var actor=item.actor
		if not is_instance_valid(actor) or actor.dead or actor.allied:continue
		if actor.position.distance_to(camera_target)>camera.size*1.1:continue
		item.attack_in-=delta
		if attacks_enabled and item.attack_in<=0:
			item.attack_in=4.5+fmod(exhibits.find(item)*.73,2.5);demonstrate_attack(actor)
	for shot in demo_shots.duplicate():
		if not is_instance_valid(shot):demo_shots.erase(shot);continue
		if shot.spent:demo_shots.erase(shot)
	for item in spin_items:item.rotation.y+=delta*.3

func demonstrate_attack(actor):
	attack_count+=1
	if actor.kind=="drone":
		burst(actor.position+Vector3(0,.3,2),Color("efb556"),.6);return
	if actor.kind in ["grenadier","mortar"]:
		var ball=Visuals.box(self,actor.position+Vector3.UP*.6,Vector3(.22,.22,.22),Color("e8b259"));var start=ball.position
		var tween=create_tween();tween.tween_method(func(t):ball.position=start+Vector3(0,sin(t*PI)*2,t*3),0.0,1.0,1.0)
		tween.tween_callback(func():burst(start+Vector3(0,0,3),Color("e8b259"),.8);ball.queue_free());return
	if actor.kind=="sniper":
		var line=Visuals.box(self,actor.position+Vector3(0,.6,1.8),Vector3(.035,.025,3.6),Color("e55a46"));var tween=create_tween()
		for i in range(3):tween.tween_property(line,"visible",false,.12);tween.tween_property(line,"visible",true,.12)
		tween.tween_callback(func():line.queue_free();demo_bullet(actor,18));return
	if actor.kind=="boss":
		for x in [-.7,0,.7]:demo_bullet(actor,5,Vector3(x,0,0))
	else:demo_bullet(actor,6.75 if actor.kind=="flyer" else 7.5)

func demo_bullet(actor,speed_value:float,offset:Vector3=Vector3.ZERO):
	if not is_instance_valid(actor) or actor.dead:return
	var bullet=load("res://scripts/projectile.gd").new();bullet.arena=self;bullet.owner_actor=actor;bullet.flyer_round=actor.kind=="flyer";bullet.sniper_round=actor.kind=="sniper"
	bullet.position=actor.position+offset+Vector3(0,1.35 if actor.kind=="flyer" else .6,.8);bullet.travel_direction=Vector3.BACK;bullet.speed=speed_value;bullet.lifetime=3.0/speed_value
	add_child(bullet);projectiles.append(bullet);demo_shots.append(bullet)

func actor_destroyed(actor):
	# Keep the same actor and its exhibit binding. No kill rewards or profile writes.
	actor.hide()
	var label=Visuals.label3d(self,"↻ 2.0 с",actor.position+Vector3.UP,Color("f6d494"),30)
	respawns.append({"actor":actor,"left":2.0,"label":label})

func bullet_hit(bullet)->bool:
	if not inside(grid_pos(bullet.position)):return true
	for other in projectiles.duplicate():
		if not is_instance_valid(other) or other==bullet or other.spent or other.friendly==bullet.friendly:continue
		if flat_distance(bullet.position,other.position)<.20:
			combat.resolve_interception(bullet,other)
			if bullet.spent:return true
	if walls.has(grid_pos(bullet.position)):return true
	for actor in actors:
		if not is_instance_valid(actor) or actor.dead or actor==bullet.owner_actor or actor in bullet.hit_actors:continue
		if (actor.player_owned or actor.allied)==bullet.friendly:continue
		var radius=1.8 if actor.footprint==4 else .85 if actor.footprint==2 else .42
		if flat_distance(bullet.position,actor.position)<radius:
			bullet.hit_actors.append(actor)
			if bullet.rocket_radius>0:
				burst(bullet.position,Color("e8b957"),bullet.rocket_radius)
				for target in actors.duplicate():
					if is_instance_valid(target) and not target.dead and not target.player_owned and not target.allied and flat_distance(bullet.position,target.position)<=bullet.rocket_radius:target.take_damage(bullet.damage)
				return true
			actor.take_damage(bullet.damage)
			if not bullet.piercing:return true
	return false
