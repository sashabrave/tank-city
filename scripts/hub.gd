extends Node3D
const LOOT=preload("res://scripts/loot_catalog.gd")
signal start_requested
signal gallery_requested
signal sandbox_requested
var arrival_reason=""
var recycling_pos=Vector3(6,0,3)
var printer_pos=Vector3(3,0,3)
var printer_model:Node3D
var avatar: Node3D
var root: Control
var station: Panel
var credits: Label
var health_button: Button
var damage_button: Button
var reset_button: Button
var luck_button: Button
var turret_button: Button
var start_button: Button
var status: Label
var title: TextureRect
var subtitle: Label
var destination=Vector3(2,0,2)
var cell=Vector2i(2,2)
var moving=false
var facing=Vector2i.DOWN
var exit_queued=false
var dpad: Control
var training_tank: Node3D
var displayed_vehicle=""
var mounted=false
var board_button: Button
var fire_pad: Control
var dummy: Node3D
var dummy_label: Label3D
var dummy_hits=0
var fire_cooldown=0.0
var turn_timer=0.0
var turn_from=0.0
var turn_to=0.0
var phase="combat"
var projectiles: Array=[]
var workshop_tab=0
var equip_slot=0
var ability_page=0
var hub_skills:Control
var training_barriers:Array=[]
var command_meshes:Array=[]
var command_faded=false
var bench_signature:Array=[]
var bench_dots:Dictionary={}
var command_model:Node3D
var training_ability_cooldown=0.0
var tab_buttons: Array=[]
var workshop_content: Control
var build_tab=0
var recipe_tab="weapon"
var build_menu: Control
var bench_visuals: Node3D
var weapon_station: Panel
var bonus_station: Panel
var bonus_content: Control
var bonus_bench_pos=Vector3(-3,0,-1)
var hint_clock=0.0
var hint_refresh=0.0
var build_arrows:Dictionary={}
var command_alert:Label3D
var command_pos=Vector3(-4,0,1)  # main screen: middle of the left edge
## Visual-only: each hub visit gets a biome, sun moment and weather like a battle room (no RNG consumed).
var run_seed=Game.visual_run_seed+int(Time.get_ticks_usec()%9973)
var room_index=int(Time.get_ticks_usec()/7)%15
func room_palette()->Dictionary:return preload("res://scripts/biome_catalog.gd").entry(run_seed,room_index)
var command_screen:ShaderMaterial
var command_beams:Node3D
var hq_bench_pos=Vector3(-2,0,3)
var weapon_bench_pos=Vector3(0,0,3)

func _ready():
	add_to_group("profile_hub")
	PerfOverlay.show_build=true;tree_exiting.connect(func():PerfOverlay.show_build=false)
	add_to_group("notification_context")
	Visuals.setup_world(self,11.8,Vector3(0,0,0))
	preload("res://scripts/base_surroundings.gd").hub(self,Color(room_palette().floor).darkened(.12))
	var outskirts=preload("res://scripts/hub_outskirts.gd").new();outskirts.hub=self;add_child(outskirts)
	Visuals.box(self,Vector3(1,-.4,.5),Vector3(13.3,.6,8.3),Color("8b9585"))
	var positions: Array=[]
	for x in range(-5,8):
		for z in range(-3,5):positions.append(Vector3(x,0,z))
	Visuals.tiled_floor(self,positions)
	var gate=Visuals.model("gate",self,Vector3(5,0,-2))
	gate.scale=Vector3(1.4,1.4,1.4)
	Visuals.box(self,Vector3(5,.03,-2),Vector3(2.6,.03,1.7),Color("d29849"))
	update_bench_visuals()
	Visuals.box(self,Vector3(4,-.08,-5.7),Vector3(4.1,.16,3.2),Color("919b88"))
	var parked=Visuals.model("base",self,Vector3(3.7,0,-5.9));parked.rotation.y=PI*.65
	Visuals.model("hq_supplies",self,Vector3(5.15,0,-5.7))
	printer_model=Visuals.model("printer",self,printer_pos)
	Visuals.label3d(self,"Боец",printer_pos+Vector3(0,1.95,0),Color("dcf6ec"),24)
	Visuals.model("crate",self,Vector3(-2,0,-2))
	Visuals.model("supply_stack",self,Vector3(-1,0,-2.4))
	displayed_vehicle=Game.garage.starting_vehicle()
	training_tank=Visuals.model(displayed_vehicle if displayed_vehicle!="" else "buggy",self,Vector3(6,0,1))
	preload("res://scripts/world_lighting.gd").headlights(training_tank,true)
	training_tank.rotation.y=PI;training_tank.visible=Game.garage.starting_vehicle()!=""
	pass
	for x in range(-5,8):
		if x in [4,5,6]:continue
		var style=preload("res://scripts/concrete_style.gd").pick(17041,Vector2i(x,-3))
		Visuals.model(preload("res://scripts/concrete_style.gd").asset(style),self,Vector3(x,0,-3))
	avatar=Visuals.model("soldier",self,Vector3(2,0,2))
	Visuals.equip_model(avatar,Game.selected_weapon)
	preload("res://scripts/world_lighting.gd").headlights(avatar)
	avatar.rotation.y=PI
	Visuals.ring(avatar,Color("fac47a"),.44)
	dummy=Node3D.new();add_child(dummy);dummy.position=Vector3(2,0,-2)
	Visuals.box(dummy,Vector3(0,.65,0),Vector3(.14,1.3,.14),Color("77634b"))
	Visuals.box(dummy,Vector3(0,1.05,0),Vector3(.95,.13,.13),Color("77634b"))
	Visuals.box(dummy,Vector3(0,.9,0),Vector3(.58,.75,.3),Color("be9a62"))
	Visuals.box(dummy,Vector3(0,.9,.17),Vector3(.25,.25,.04),Color("994837"))
	dummy.visible="range" in Game.built_workshops
	dummy_label=Visuals.label3d(dummy,"",Vector3(0,1.7,0),Color("f7d891"),26)
	Game.progression.prepare_telegrams()
	command_model=Visuals.model("command_center",self,command_pos)
	command_model.rotation.y=.55  # screen turned toward the hub centre and the camera
	build_command_screen()
	command_meshes=command_model.find_children("*","MeshInstance3D",true,false).filter(func(m):return not command_beams.is_ancestor_of(m))
	command_alert=Visuals.label3d(self,"!",command_pos+Vector3(0,3.3,0),Color("ed4f40"),85)
	command_alert.no_depth_test=true
	refresh_command_alert()
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Управление",command_pos,1.65)
	preload("res://scripts/ui/recycling_station.gd").model(self,recycling_pos)
	build_ui()
	hub_skills=preload("res://scripts/ui/hub_skills.gd").new();hub_skills.hub=self;root.add_child(hub_skills)
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Боец",printer_pos,1.4)
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"В бой",Vector3(5,0,-2),2.2)
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Стоянка",Vector3(6,0,1),1.65,func():return "garage" in Game.built_workshops and not mounted)
	preload("res://scripts/printer_intro.gd").play(self)

func build_ui():
	var canvas=CanvasLayer.new();add_child(canvas)
	root=preload("res://scenes/ui/hub_screen.tscn").instantiate();canvas.add_child(root)
	root.get_node("GalleryButton").pressed.connect(func():gallery_requested.emit())
	title=root.get_node("GameTitle");credits=root.get_node("AlloyLabel")
	var title_plate=UiKit.glass(root,Vector2(30,25),Vector2(300,130),Color("242d27ed"));title_plate.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.move_child(title_plate,0)
	for child in root.get_children():
		if child is TextureRect and child.position==Vector2(48,109):child.hide()
	credits.size.x=600;credits.add_theme_font_size_override("font_size",23)
	for i in range(3):
		var button=root.get_node(["BuildButton","GalleryButton","DebugAlloyButton"][i]);button.position=Vector2(30,205+i*60);button.size=Vector2(300,50)
	root.get_node("DebugAlloyButton").pressed.connect(func():Game.earn(1000);refresh())
	var alloy_button=root.get_node("DebugAlloyButton");alloy_button.size.x=146
	var docs_button=UiKit.button(root,"+10 док.",alloy_button.position+Vector2(154,0),Vector2(146,alloy_button.size.y),func():Game.cores+=10;Game.save_progress();refresh());docs_button.add_theme_font_size_override("font_size",17)
	alloy_button.add_theme_font_size_override("font_size",17)
	root.get_node("BuildButton").text="Строительство"
	root.get_node("BuildButton").pressed.connect(show_build_menu)
	var recipe_button=UiKit.button(root,"Магазин чертежей · тест",Vector2(30,385),Vector2(300,50),show_recipe_shop)
	recipe_button.add_theme_font_size_override("font_size",18);root.move_child(recipe_button,0)
	var sandbox_button=UiKit.button(root,"Песочница",Vector2(30,445),Vector2(300,50),func():sandbox_requested.emit());sandbox_button.name="SandboxButton"
	sandbox_button.add_theme_font_size_override("font_size",18);root.move_child(sandbox_button,0)
	dpad=root.get_node("MovePad");dpad.apply_movement_layout();fire_pad=root.get_node("FirePad")
	start_button=root.get_node("StartButton");start_button.pressed.connect(launch)
	root.get_node("SettingsButton").hide()
	board_button=root.get_node("InteractButton");board_button.pressed.connect(interact)
	station=root.get_node("CharacterWorkshop");weapon_station=root.get_node("WeaponWorkshop");bonus_station=root.get_node("BonusWorkshop")
	for panel in [station,weapon_station,bonus_station]:
		panel.z_index=10;panel.add_to_group("selection_scope");panel.get_node("CloseButton").pressed.connect(close_station)
	for i in range(5):
		var button=station.get_node("Tab"+str(i));button.icon=UiKit.icon_texture(["heart","base","guide","inventory","settings"][i]);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",22);tab_buttons.append(button);button.pressed.connect(func():workshop_tab=i;refresh())
	workshop_content=station.get_node("Content");bonus_content=bonus_station.get_node("Content")
	for pair in [[weapon_station,"weapons"],[bonus_station,"bonuses"]]:
		var panel=pair[0];var id=pair[1]
		preload("res://scripts/ui/build_catalog.gd").preview(panel,id,Vector2(20,12),Vector2(110,104))
		panel.get_node("Heading").position.x=144;panel.get_node("Heading").size.x=650
		panel.get_node("Hint").position.x=144;panel.get_node("Hint").size.x=660;panel.get_node("Hint").text="Выбери оружие и улучши его навсегда" if id=="weapons" else "Усиления выпадают в бою · развитие сохраняется"
	var bonus_scroll=ScrollContainer.new();bonus_station.add_child(bonus_scroll);bonus_scroll.position=Vector2(25,120);bonus_scroll.size=Vector2(890,455);bonus_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	bonus_station.remove_child(bonus_content);bonus_scroll.add_child(bonus_content);bonus_content.position=Vector2.ZERO;bonus_content.custom_minimum_size=Vector2(872,ceilf(LOOT.BONUSES.size()/3.0)*205)

	reset_button=station.get_node("ResetButton");reset_button.pressed.connect(reset_upgrades)
	status=station.get_node("StatusLabel")
	# Vertical branches keep the same content width for ability trees.
	station.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	station.size=Vector2(1120,650);station.position=(get_viewport().get_visible_rect().size-station.size)*.5
	preload("res://scripts/ui/build_catalog.gd").preview(station,"character",Vector2(20,10),Vector2(86,70))
	station.get_node("Heading").position.x=122
	station.get_node("Heading").text="Прокачка базы"
	station.add_theme_stylebox_override("panel",UiKit.style(Color("242d27"),18))
	station.get_node("CloseButton").position.x=1020
	for i in range(tab_buttons.size()):
		tab_buttons[i].position=Vector2(22,90+i*65);tab_buttons[i].size=Vector2(210,52)
	workshop_content.position=Vector2(260,100)
	reset_button.position=Vector2(22,578);reset_button.size.x=210;reset_button.add_theme_font_size_override("font_size",15)
	status.position=Vector2(260,593)
	refresh()

func refresh():
	credits.hide()
	update_bench_visuals()
	refresh_catalogs()
	for i in range(tab_buttons.size()):tab_buttons[i].text=["Снабжение","Поддержка","Разведка","Снаряжение","Системы"][i];tab_buttons[i].add_theme_stylebox_override("normal",UiKit.style(Color("584a2c") if i==workshop_tab else Color("242d27"),8))
	if not is_instance_valid(workshop_content) or not station.visible:return
	for child in workshop_content.get_children():workshop_content.remove_child(child);child.queue_free()
	if workshop_tab==3:show_abilities();return
	if workshop_tab==4:show_systems();return
	var groups=[["heal","supplies"],["base","turret"],["rarity","luck"]]
	var names={"supplies":"Аптечки в передышках","health":"Здоровье героя","base":"Прочность базы","heal":"Сила лечения","recovery":"Перезарядка щита","damage":"Сила атаки","turret":"Союзные турели","mobility":"Скорость передвижения","rarity":"Удача улучшений","luck":"Частота дропа"}
	var details={
		"supplies":"%d аптечек у механика/генерала · подбираются вручную" % Game.camp_level,
		"health":"%d HP · +2 HP/ур. Базе +1 каждые 5 ур." % (Balance.CONFIG.combat.hero_health+Game.health_upgrade_bonus()),
		"base":"%d HP базы · +1 HP за уровень" % (Balance.CONFIG.combat.base_health+int(Game.health_level/5.0)+Game.base_level),
		"heal":"Сердце %.2f · база %.2f · броня %.2f; +0,15/ур." % [Game.heal_amount(),2+Game.heal_level*.15,3+Game.heal_level*.15],
		"recovery":"%.1f с до восстановления · −5%%/ур." % (Balance.CONFIG.combat.shield_cooldown*pow(.95,Game.recovery_level)),
		"damage":"Стволы +%d%% базы; техника +%.2f урона" % [Game.damage_level*5,Game.meta_damage()],
		"turret":"%.2f урона по площади · +0,05/ур." % Game.turret_damage(),
		"mobility":"%.2f клетки/с пешком · Убывающий прирост скорости" % (Balance.CONFIG.combat.hero_speed*Game.mobility_multiplier()),
		"rarity":"Редкие %.1f%% · эпик %.1f%%; эпик +0,6 %%/ур." % [27+Game.rarity_level*.6,8+Game.rarity_level*.6],
		"luck":"Сердце %.1f%% · бонус %.1f%%; +0,5 %%/ур." % [Game.heart_chance()*100,Game.bonus_chance()*100]}
	var icons={"heal":"heart","supplies":"heart","base":"repair","turret":"turret","rarity":"star","luck":"alloy"}
	for i in range(groups[workshop_tab].size()):
		var branch=groups[workshop_tab][i];var unlocked=Game.branch_unlocked(branch)
		var card=UiKit.panel(workshop_content,Vector2(0,i*190),Vector2(810,174),Color("30382f"))
		UiKit.locked_preview(UiKit.icon(card,icons.get(branch,"settings"),Vector2(16,22),Vector2(96,96)),not unlocked)
		UiKit.label(card,names[branch],Vector2(132,14),Vector2(650,32),22)
		UiKit.label(card,details[branch],Vector2(132,52),Vector2(650,45),16,UiKit.MUTED).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		UiKit.label(card,"Уровень %d / %d" % [Game.level(branch),Game.upgrade_cap(branch)],Vector2(132,115),Vector2(275,32),17)
		var title=("Максимум" if Game.level(branch)>=Game.upgrade_cap(branch) else "+1 · %d ◈" % Game.cost(branch)) if unlocked else "Открыть · %d ◈" % Game.UNLOCK_COSTS[branch]
		var button=UiKit.button(card,title,Vector2(450,115),Vector2(340,42),func():buy(branch))
		button.disabled=(Game.level(branch)>=Game.upgrade_cap(branch) or Game.credits<Game.cost(branch)) if unlocked else Game.credits<Game.UNLOCK_COSTS[branch];UiKit.muted_locked_button(button)

func reset_upgrades():
	Game.reset_upgrades()
	mounted=false;moving=false;cell=Vector2i(2,2);destination=Vector3(2,0,2);avatar.position=destination;avatar.show()
	training_tank.position=Vector3(6,0,1);update_bench_visuals();close_station()
	Texts.set_text(status,"Профиль обнулён.")
	refresh()

func buy(branch: String):
	if (Game.purchase(branch) if Game.branch_unlocked(branch) else Game.unlock_branch(branch)):
		Game.sound("upgrade",self)
		Texts.set_text(status,"Улучшено.")
		refresh()

## Idle: dark screen paging abstract maps and dossiers. News: turquoise glow and rays on the floor.
func build_command_screen():
	var screen=command_model.find_child("CommandScreen",true,false)
	if screen is MeshInstance3D:
		command_screen=ShaderMaterial.new();command_screen.shader=preload("res://shaders/world/command_screen.gdshader");screen.material_override=command_screen
	command_beams=Node3D.new();command_beams.name="CommandBeams";command_model.add_child(command_beams)
	var ray_mat=ShaderMaterial.new();ray_mat.shader=preload("res://shaders/fx/loot_beam.gdshader")
	ray_mat.set_shader_parameter("tint",Color("5fe6d6"));ray_mat.set_shader_parameter("strength",.5)
	for x in [-.36,0.0,.36]:
		var ray=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2(.3,2.1);ray.mesh=quad;ray.material_override=ray_mat
		ray.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;command_beams.add_child(ray)
		ray.position=Vector3(x*1.3,.62,1.0);ray.rotation=Vector3(deg_to_rad(-58),0,0)
	var glow=SpotLight3D.new();glow.light_color=Color("5fe6d6");glow.light_energy=2.4;glow.spot_range=4.0;glow.spot_angle=42;glow.shadow_enabled=false
	command_beams.add_child(glow);glow.position=Vector3(0,1.4,.3);glow.rotation.x=deg_to_rad(-52)

func refresh_command_alert():
	if not is_instance_valid(command_alert):return
	var news=Game.progression.news_kind()
	if command_screen:command_screen.set_shader_parameter("alert",news!="")
	if is_instance_valid(command_beams):command_beams.visible=news!=""
	command_alert.visible=news!=""
	command_alert.modulate=Color("ed4f40") if news=="general" else Color("f1cf55")

func sync_model_animation():
	var active=phase=="combat" and moving and not station.visible and not weapon_station.visible and not bonus_station.visible and not is_instance_valid(build_menu)
	avatar.preview_moving=active and not mounted;avatar.preview_speed=3.4
	training_tank.preview_moving=active and mounted;training_tank.preview_speed=2.7

func _physics_process(delta):
	sync_model_animation()
	if is_instance_valid(dpad):dpad.visible=Settings.values.screen_controls;fire_pad.visible=Settings.values.screen_controls
	if phase in ["intro","profiles"]:return
	training_ability_cooldown=maxf(0,training_ability_cooldown-delta)
	if is_instance_valid(command_model):
		var faded=avatar.position.distance_to(command_pos)<1.7
		if faded!=command_faded:
			command_faded=faded
			for mesh in command_meshes:mesh.transparency=0.7 if faded else 0.0
	hint_clock+=delta;hint_refresh-=delta
	if hint_refresh<=0:
		var build_button=root.get_node("BuildButton")
		var dot=build_button.get_node_or_null("NewDot")
		if dot==null:dot=preload("res://scripts/ui/build_catalog.gd").dot(build_button,Vector2(build_button.size.x-26,8));dot.name="NewDot"
		dot.visible=Game.research_unlocks.any(func(id):return id in Game.BUILD_COST.keys()+["reroll"] and preload("res://scripts/ui/build_catalog.gd").has_news(id))
		for id in bench_dots:bench_dots[id].visible=bench_available(id)
		hint_refresh=.3
		refresh_command_alert()
		var targets=Game.progression.build_targets()
		for id in build_arrows:
			if is_instance_valid(build_arrows[id]):build_arrows[id].visible=id not in Game.built_workshops and (id in Game.research_unlocks or id in targets)
	if is_instance_valid(command_alert):command_alert.position.y=command_pos.y+3.3+(1-cos(hint_clock*TAU/2.8))*.14
	for arrow in build_arrows.values():
		if is_instance_valid(arrow):arrow.position.y=1.9+(1-cos(hint_clock*TAU/4.8))*.18
	if station.visible or weapon_station.visible or bonus_station.visible or is_instance_valid(build_menu):
		if Input.is_action_just_pressed("pause"):close_station()
		return
	if Input.is_action_just_pressed("pause"):preload("res://scripts/ui/pause_tablet.gd").open(self);return
	for slot in range(Game.hero_loadout().size()):
		if Input.is_action_just_pressed(Game.ability_action(slot)):use_training_ability(slot)
	fire_cooldown=maxf(0,fire_cooldown-delta);turn_timer=maxf(0,turn_timer-delta)
	var controlled=training_tank if mounted else avatar
	var dir=Game.direction()
	if dir!=Vector2i.ZERO:
		if dir!=facing:
			facing=dir;turn_timer=.105;turn_from=controlled.rotation.y;turn_to=atan2(-float(dir.x),-float(dir.y))
	controlled.rotation.y=lerp_angle(turn_from,turn_to,1.0-turn_timer/.105) if turn_timer>0 else atan2(-float(facing.x),-float(facing.y))
	if moving:
		controlled.position=controlled.position.move_toward(destination,(2.7 if mounted else 3.4)*delta)
		if controlled.position.distance_to(destination)<.01:moving=false
	if not moving:
		if dir!=Vector2i.ZERO:
			var next=controlled.position+Vector3(dir.x,0,dir.y)*.25
			next.x=snappedf(next.x,.25);next.z=snappedf(next.z,.25)
			if hub_stand(next):
				cell=Vector2i(roundi(next.x),roundi(next.z));destination=next;moving=true
	sync_model_animation()
	var near_station=not mounted and avatar.position.distance_to(Vector3(0,0,-1))<1.25
	var near_bonus=not mounted and avatar.position.distance_to(bonus_bench_pos)<1.2
	var near_weapon=not mounted and avatar.position.distance_to(weapon_bench_pos)<1.25
	Texts.set_text(board_button,"Бонусы [E]" if near_bonus else "Оружие [E]" if near_weapon else ("Прокачка [E]" if near_station else ("Выйти [E]" if mounted else "Занять [E]")))
	board_button.disabled=moving or (not near_station and not near_weapon and not near_bonus and not mounted and avatar.position.distance_to(training_tank.position)>1.65)
	if not mounted and avatar.position.distance_to(printer_pos)<1.4:Texts.set_text(board_button,"Боец [E]");board_button.disabled=moving
	if not mounted and avatar.position.distance_to(command_pos)<1.65:Texts.set_text(board_button,"Управление [E]");board_button.disabled=moving
	if not mounted and "garage" in Game.built_workshops and avatar.position.distance_to(Vector3(6,0,1))<1.65:Texts.set_text(board_button,"Стоянка [E]");board_button.disabled=moving
	if nearest_locked()!="":Texts.set_text(board_button,"Построить [E]");board_button.disabled=moving
	if not mounted and avatar.position.distance_to(hq_bench_pos)<1.2:Texts.set_text(board_button,"Технологии [E]");board_button.disabled=moving
	if not mounted and avatar.position.distance_to(recycling_pos)<1.3:Texts.set_text(board_button,"Продать [E]");board_button.disabled=moving
	if Game.wants_fire() and turn_timer<=0 and fire_cooldown<=0:shoot()
	if Game.wants_interact():interact()

func hub_free(p: Vector2i) -> bool:
	if p in training_barriers or p in [Vector2i(-2,3),Vector2i(3,3),Vector2i(6,3)]:return false
	if p.x< -4 or p.x>7 or p.y< -2 or p.y>4:return false
	if p in [Vector2i(-4,0),Vector2i(-4,1),Vector2i(-4,2),Vector2i(-3,-1),Vector2i(0,3),Vector2i(2,-2),Vector2i(-2,-2),Vector2i(-1,-2),Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1)]:return false
	if not mounted and training_tank.visible and Vector2i(roundi(training_tank.position.x),roundi(training_tank.position.z))==p:return false
	return true

func interact():
	if phase=="intro":return
	if station.visible or weapon_station.visible or bonus_station.visible or is_instance_valid(build_menu):close_station();return
	if moving:return
	if not mounted and avatar.position.distance_to(recycling_pos)<1.3:show_recycling();return
	if not mounted and avatar.position.distance_to(hq_bench_pos)<1.2:open_station("hq");return
	if not mounted and avatar.position.distance_to(command_pos)<1.65:show_command();return
	if not mounted and avatar.position.distance_to(printer_pos)<1.4:open_station("fighter");return
	if not mounted and "garage" in Game.built_workshops and avatar.position.distance_to(Vector3(6,0,1))<1.65:open_station("garage");return
	var locked=nearest_locked()
	if locked!="":build_tab=1 if locked in ["garage","range"] else 0;show_build_menu();return
	if not mounted and avatar.position.distance_to(weapon_bench_pos)<1.25:open_station("arsenal");return
	if mounted:
		var exit_cell=cell
		for dir in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.UP]:
			if hub_free(cell+dir):exit_cell=cell+dir;break
		if exit_cell==cell:return
		mounted=false
		cell=exit_cell;destination=Vector3(cell.x,0,cell.y)
		avatar.position=destination;avatar.visible=true;avatar.rotation.y=atan2(-float(facing.x),-float(facing.y))
		Texts.set_text(status,"Танк оставлен.")
	elif "garage" in Game.built_workshops and avatar.position.distance_to(training_tank.position)<=1.65:
		mounted=true;avatar.visible=false
		facing=Vector2i(roundi(-sin(training_tank.rotation.y)),roundi(-cos(training_tank.rotation.y)))
		cell=Vector2i(roundi(training_tank.position.x),roundi(training_tank.position.z))
		destination=training_tank.position
		Texts.set_text(status,"E — выйти.")
	elif avatar.position.distance_to(Vector3(5,0,-2))<2.2:
		launch()

func launch():
	if phase=="intro":return
	if exit_queued:return
	if station.visible or weapon_station.visible or bonus_station.visible or is_instance_valid(build_menu):return
	exit_queued=true
	Game.reset_input()
	start_requested.emit()

func close_station():
	if is_instance_valid(build_menu):build_menu.get_parent().remove_child(build_menu);build_menu.queue_free();build_menu=null
	station.hide();weapon_station.hide();bonus_station.hide();phase="combat";Game.reset_input();dpad.clear();fire_pad.clear();dpad.enabled=true;fire_pad.enabled=true;start_button.disabled=false
	call_deferred("present_unlock")

func shoot():
	if phase=="intro":return
	if station.visible or weapon_station.visible or bonus_station.visible or is_instance_valid(build_menu):return
	var controlled=training_tank if mounted else avatar
	controlled.kick()
	var data=LOOT.WEAPONS[Game.selected_weapon]
	fire_cooldown=1.25 if mounted else data.interval
	for i in range(1 if mounted else data.pellets):
		var bullet=load("res://scenes/projectile.tscn").instantiate()
		bullet.sniper_visual=not mounted and Game.selected_weapon=="sniper"
		bullet.arena=self;bullet.friendly=true;bullet.speed=13 if mounted else data.speed;bullet.damage=3+Game.meta_damage() if mounted else data.damage*Game.weapon_factor(Game.selected_weapon)*(1+Game.damage_level*.05)
		bullet.travel_direction=Vector3(facing.x,0,facing.y).rotated(Vector3.UP,0 if mounted else (i-(data.pellets-1)*.5)*.1)
		var muzzle_height=controlled.muzzle.global_position.y-controlled.position.y if is_instance_valid(controlled.muzzle) else .55
		bullet.position=controlled.position+bullet.travel_direction*.45+Vector3.UP*muzzle_height
		bullet.lifetime=2.5 if mounted else data.range/data.speed
		add_child(bullet);projectiles.append(bullet)
	Game.sound("shot",self)

func bullet_hit(bullet) -> bool:
	var pos=bullet.position
	if "range" in Game.built_workshops and absf(pos.x-dummy.position.x)<.4 and absf(pos.z-dummy.position.z)<.4:
		dummy_hits+=1;Texts.set_text(dummy_label,"−%.2f" % bullet.damage)
		dummy.scale=Vector3(1.08,.94,1.08)
		create_tween().tween_property(dummy,"scale",Vector3.ONE,.18)
		return true
	if pos.x< -3 or pos.x>8 or pos.z< -3 or pos.z>4:return true
	var p=Vector2i(roundi(pos.x),roundi(pos.z))
	return p in [Vector2i(-2,-2),Vector2i(-1,-2),Vector2i(0,-1)] or p.y== -3

func open_workshop(weapons: bool,bonuses: bool=false):
	if ("bonuses" if bonuses else "weapons" if weapons else "character") not in Game.built_workshops:show_build_menu();return
	preload("res://scripts/ui/build_catalog.gd").mark("bonuses" if bonuses else "weapons" if weapons else "character")
	station.visible=not weapons and not bonuses;weapon_station.visible=weapons;bonus_station.visible=bonuses;phase="workshop"
	Game.reset_input();dpad.clear();fire_pad.clear();dpad.enabled=false;fire_pad.enabled=false
	start_button.disabled=true;board_button.disabled=true;refresh()

func show_abilities():
	UiKit.label(workshop_content,"Гаджет / F",Vector2.ZERO,Vector2(800,38),23)
	var ids=["barrier","mine","laser","airstrike"]
	for i in range(ids.size()):
		var id=ids[i];var known=Game.ability_available(id);var data=AbilityCatalog.DATA[id]
		var card=UiKit.panel(workshop_content,Vector2((i%2)*408,55+floori(i/2.0)*180),Vector2(396,168))
		UiKit.locked_preview(UiKit.icon(card,id,Vector2(10,10),Vector2(76,76)),not known);UiKit.label(card,("" if known else "🔒 ")+data.name,Vector2(100,10),Vector2(280,30),19)
		UiKit.label(card,data.description,Vector2(100,44),Vector2(280,67),14).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var button=UiKit.button(card,"Взят" if Game.gadget==id else "Взять" if id in Game.purchased_gadgets else "Открыть · %d ◈" % Game.gadget_cost(id),Vector2(10,122),Vector2(376,36),func():Game.unlock_or_equip_ability(id);refresh());button.disabled=not known or Game.gadget==id;UiKit.muted_locked_button(button)

func equip_ability(id):
	if not Game.ability_available(id):return
	var existing=Game.equipped_abilities.find(id)
	if existing>=0 and existing!=equip_slot:
		if equip_slot<Game.equipped_abilities.size():Game.equipped_abilities[existing]=Game.equipped_abilities[equip_slot]
		else:return
	if equip_slot>=Game.equipped_abilities.size():Game.equipped_abilities.append(id)
	else:Game.equipped_abilities[equip_slot]=id
	Game.selected_ability=Game.equipped_abilities[0];Game.save_progress();refresh()
func show_systems():
	for i in range(2):
		var alloy=i==0
		var price=Game.insurance_cost() if alloy else Game.special_cost("rescue")
		var capped=Game.progression.insurance>=Balance.CONFIG.economy.insurance_cap if alloy else price<0
		var known=alloy or "rescue" in Game.research_unlocks
		var card=UiKit.panel(workshop_content,Vector2(0,i*226),Vector2(810,212),Color("30382f"))
		UiKit.locked_preview(UiKit.icon(card,"alloy" if alloy else "documents",Vector2(18,34),Vector2(96,96)),not known)
		UiKit.label(card,"Страховка сплава" if alloy else "Страховка чертежей",Vector2(136,16),Vector2(650,34),23)
		var description="При гибели теряется %d%% сплава, добытого за вылазку." % roundi(Game.death_loss_fraction()*100) if alloy else "Шанс сохранить каждый найденный чертёж при гибели."
		UiKit.label(card,description,Vector2(136,58),Vector2(650,45),16,UiKit.MUTED).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var detail="Потеря: %d%% → %d%%" % [roundi(Game.death_loss_fraction()*100),roundi(maxf(.2,Game.death_loss_fraction()-.05)*100)] if alloy else "Сохранение: %d%% → %d%%" % [Game.rescue_level*6,mini(60,(Game.rescue_level+1)*6)]
		if capped and known:detail="Достигнут предел" if alloy and Game.progression.insurance<Balance.CONFIG.economy.insurance_cap else "Достигнут максимум"
		UiKit.label(card,detail,Vector2(136,108),Vector2(650,30),18)
		var button=UiKit.button(card,"Нужен чертёж" if not known else "Предел улучшений" if capped else "Улучшить · %d ◈" % price,Vector2(136,156),Vector2(650,40),func():
			if alloy:Game.buy_insurance()
			else:Game.buy_special("rescue")
			refresh())
		button.disabled=not known or capped or Game.credits<price;UiKit.muted_locked_button(button)

func refresh_catalogs():
	if not is_instance_valid(bonus_content):return
	if weapon_station.visible:
		for child in weapon_station.get_children():
			if child.has_meta("weapon_card") or child.name=="CatalogScroll":weapon_station.remove_child(child);child.queue_free()
		var scroll=ScrollContainer.new();scroll.name="CatalogScroll";weapon_station.add_child(scroll);scroll.position=Vector2(25,130);scroll.size=Vector2(850,445);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		var cards=Control.new();scroll.add_child(cards);cards.custom_minimum_size=Vector2(825,ceilf(LOOT.WEAPONS.size()/3.0)*310)
		var weapons=LOOT.WEAPONS.keys()
		for i in range(weapons.size()):
			var id=weapons[i];var info=LOOT.WEAPONS[id];var unlocked=id in Game.weapon_unlocks
			var card=preload("res://scenes/ui/weapon_card.tscn").instantiate();cards.add_child(card);card.position=Vector2((i%3)*278,int(i/3.0)*310);card.set_meta("weapon_card",true)
			var style=card.get_theme_stylebox("panel").duplicate();style.bg_color=Color("29322b");style.border_color=Color(LOOT.RARITY_COLORS[info.rarity]).darkened(.25) if unlocked else Color("535d51");card.add_theme_stylebox_override("panel",style)
			UiKit.locked_preview(card.get_node("Icon"),not unlocked);card.get_node("Icon").texture=UiKit.icon_texture(info.icon);card.get_node("Title").text=("" if unlocked else "🔒 ")+info.name
			if unlocked:preload("res://scripts/ui/build_catalog.gd").item_dot(card,"weapons",id,Vector2(243,12))
			card.get_node("Description").hide()
			card.get_node("Icon").position=Vector2(54,42);card.get_node("Icon").size=Vector2(162,108)
			card.get_node("Title").size.x=244
			var benchmark=preload("res://scripts/ui/weapon_benchmarks.gd").weapon(id)
			UiKit.stat_bars(card,Vector2(15,150),244,[["Урон × "+str(info.pellets),info.damage*Game.weapon_factor(id),benchmark.damage],["Темп",1.0/info.interval,benchmark.rate," /с"],["Дальность",info.range,benchmark.range]],28)
			card.tooltip_text=preload("res://scripts/ui/weapon_benchmarks.gd").hint(id) if unlocked else "🔒 Нужен чертёж"
			var button=card.get_node("ChooseButton");Texts.set_text(button,"Взято в бой" if id==Game.selected_weapon else "Взять в бой" if unlocked else "🔒 Нужен чертёж");button.pressed.connect(func():Game.equip_weapon(id);refresh())
			button.disabled=not unlocked or id==Game.selected_weapon
			UiKit.muted_locked_button(button)
			button.position.y=240;button.add_theme_font_size_override("font_size",15)
			var tune=UiKit.button(card,"Ур. %d · +1,5%% · %d ◈" % [Game.weapon_level(id),Game.weapon_upgrade_cost(id)] if unlocked else "🔒 Улучшение",Vector2(15,271),Vector2(244,28),func():Game.upgrade_weapon(id);refresh())
			card.size=Vector2(268,302)
			for compact in [button,tune]:
				for state in ["normal","hover","pressed","disabled","focus"]:
					var compact_style=compact.get_theme_stylebox(state).duplicate();compact_style.content_margin_top=3;compact_style.content_margin_bottom=3;compact.add_theme_stylebox_override(state,compact_style)
				compact.custom_minimum_size=Vector2.ZERO;compact.size=Vector2(244,28)
			tune.add_theme_font_size_override("font_size",13)
			if unlocked and Game.weapon_level(id)>=Balance.CONFIG.economy.weapon_level_cap:Texts.set_text(tune,"Ур. %d · %s" % [Game.weapon_level(id),"максимум"])
			tune.disabled=not unlocked or Game.weapon_level(id)>=Balance.CONFIG.economy.weapon_level_cap or Game.credits<Game.weapon_upgrade_cost(id)
			UiKit.muted_locked_button(tune)
	if bonus_station.visible:
		for child in bonus_content.get_children():bonus_content.remove_child(child);child.queue_free()
		var ids=LOOT.BONUSES.keys()
		for i in range(ids.size()):
			var id=ids[i];var info=LOOT.BONUSES[id];var owned=id in Game.bonus_unlocks;var level=Game.bonus_level(id)
			var card=preload("res://scenes/ui/bonus_card.tscn").instantiate();bonus_content.add_child(card);card.position=Vector2((i%3)*298,int(i/3.0)*205)
			var style=card.get_theme_stylebox("panel").duplicate();style.bg_color=Color("29322b");style.border_color=Color(LOOT.RARITY_COLORS[info.rarity]).darkened(.25) if owned else Color("535d51");card.add_theme_stylebox_override("panel",style)
			card.tooltip_text=info.effect if owned else "🔒 Нужен чертёж"
			card.get_node("Icon").texture=UiKit.icon_texture(id);UiKit.locked_preview(card.get_node("Icon"),not owned)
			if owned:preload("res://scripts/ui/build_catalog.gd").item_dot(card,"bonuses",id,Vector2(266,8))
			card.size=Vector2(286,195)
			card.get_node("Icon").position=Vector2(10,8);card.get_node("Icon").size=Vector2(78,78)
			card.get_node("Title").position=Vector2(98,12);card.get_node("Title").size.x=176
			card.get_node("Rarity").position=Vector2(98,47)
			card.get_node("Description").position=Vector2(12,94);card.get_node("Description").size=Vector2(262,48)
			card.get_node("ChooseButton").position.y=152
			card.get_node("Title").text=("" if owned else "🔒 ")+info.name;card.get_node("Rarity").text=(LOOT.RARITY_NAMES[info.rarity]+" · %d/3" % level) if owned else "🔒 Закрыто"
			var detail=info.effect+"\n"+("Дроп: +0,2 %/ур." if id=="heart" else "Общий дроп: +0,1 %/ур.")
			if id=="star":detail="Неуязвимость · 1 выстрел\nБетон · %.1f с (+1,5/ур.)\nШанс II/III: %.2f / %.2f%%" % [Game.star_duration(),(.006+level*.0015)*100,(.015+level*.003)*100]
			card.get_node("Description").text=info.effect;card.get_node("Description").tooltip_text=detail if owned else ""
			if owned and level<3:UiKit.numeric_description(card.get_node("Description"),bonus_change(id,level))
			var price=Game.bonus_cost(id)
			var button=card.get_node("ChooseButton");Texts.set_text(button,"🔒 Нужен чертёж" if not owned else ("Максимум" if level>=Balance.CONFIG.economy.bonus_level_cap else "+1 · %d ◈" % price))
			button.pressed.connect(func():Game.upgrade_bonus(id);refresh());button.disabled=not owned or level>=Balance.CONFIG.economy.bonus_level_cap or Game.credits<price
			UiKit.muted_locked_button(button)

func update_bench_visuals():
	if is_instance_valid(avatar) and avatar.weapon_id!=Game.selected_weapon:Visuals.equip_model(avatar,Game.selected_weapon)
	hint_refresh=0
	if not is_instance_valid(bench_visuals) or bench_signature!=Game.built_workshops:
		bench_signature=Game.built_workshops.duplicate()
		build_arrows.clear();bench_dots.clear()
		if is_instance_valid(bench_visuals):remove_child(bench_visuals);bench_visuals.queue_free()
		bench_visuals=Node3D.new();add_child(bench_visuals)
		for id in Game.BUILD_COST:
			var pos={"headquarters":hq_bench_pos,"character":Vector3(0,0,-1),"weapons":weapon_bench_pos,"bonuses":bonus_bench_pos,"garage":Vector3(6,0,1),"range":Vector3(2,0,-2)}[id]
			if id not in Game.built_workshops:
				var arrow=Visuals.label3d(bench_visuals,"▼",pos+Vector3.UP*1.9,Color("f1cf55"),65)
				arrow.no_depth_test=true;arrow.visible=id in Game.research_unlocks or id in Game.progression.build_targets();build_arrows[id]=arrow
			if id not in ["garage","range"]:
				preload("res://scripts/interaction_prompt.gd").attach(bench_visuals,self,Game.RESEARCH[id].name if id in Game.built_workshops else "🔒 Построить · "+Game.RESEARCH[id].name,pos,1.25)
			if id=="garage":
				Visuals.model("parking",bench_visuals,pos)
				continue
			if id in Game.built_workshops:
				var dot=Visuals.label3d(bench_visuals,"●",pos+Vector3.UP*2.0,Color("b6ff76"),42);dot.outline_size=0
				bench_dots[id]=dot;dot.visible=bench_available(id)
				if id in ["garage","range"]:continue
				Visuals.model("bench_"+id,bench_visuals,pos)
			else:
				Visuals.box(bench_visuals,pos+Vector3.UP*.06,Vector3(1.25*sqrt(.6),.12,1.25*sqrt(.6)),Color("758783"))
				Visuals.box(bench_visuals,pos+Vector3(0,.3,0),Vector3(.40,.35,.22),Color("e2d5a9"))
				Visuals.box(bench_visuals,pos+Vector3(-.14,.58,0),Vector3(.07,.25,.12),Color("e2d5a9"));Visuals.box(bench_visuals,pos+Vector3(.14,.58,0),Vector3(.07,.25,.12),Color("e2d5a9"));Visuals.box(bench_visuals,pos+Vector3(0,.7,0),Vector3(.34,.07,.12),Color("e2d5a9"))
	if is_instance_valid(training_tank):
		var selected=Game.garage.starting_vehicle()
		if selected!="" and selected!=displayed_vehicle:
			training_tank.queue_free();training_tank=Visuals.model(selected,self,Vector3(6,0,1));training_tank.rotation.y=PI
		displayed_vehicle=selected;training_tank.visible=selected!=""
	if is_instance_valid(dummy):dummy.visible="range" in Game.built_workshops
func show_build_menu():preload("res://scripts/ui/build_menu.gd").show(self)

## The four stations share one screen (scripts/ui/station_screen.gd); only «Боец» needs no building.
const STATIONS={"fighter":["","res://scripts/ui/stations/fighter_station.gd"],"arsenal":["weapons","res://scripts/ui/stations/arsenal_station.gd"],"hq":["headquarters","res://scripts/ui/stations/hq_station.gd"],"garage":["garage","res://scripts/ui/stations/garage_station.gd"]}
func open_station(kind:String):
	var building=STATIONS[kind][0]
	if building!="" and building not in Game.built_workshops:build_tab=0;show_build_menu();return
	if building!="":preload("res://scripts/ui/build_catalog.gd").mark(building)
	close_station();phase="workshop";Game.reset_input();dpad.clear();fire_pad.clear();dpad.enabled=false;fire_pad.enabled=false;start_button.disabled=true
	var screen=preload("res://scripts/ui/station_screen.gd").new();screen.name="Station_"+kind;screen.provider=load(STATIONS[kind][1]).new()
	build_menu=screen;root.add_child(screen);screen.closed.connect(close_station);screen.changed.connect(refresh)

func nearest_locked() -> String:
	if mounted:return ""
	for id in Game.BUILD_COST:
		var pos={"headquarters":hq_bench_pos,"character":Vector3(0,0,-1),"weapons":weapon_bench_pos,"bonuses":bonus_bench_pos,"garage":Vector3(6,0,1),"range":Vector3(2,0,-2)}[id]
		if id not in Game.built_workshops and avatar.position.distance_to(pos)<1.25:return id
	return ""

func bench_available(id:String)->bool:
	if id=="headquarters":
		for tech in Game.hq_unlocks:
			if HQCatalog.available(tech) and int(Game.hq_levels.get(tech,0))<HQCatalog.cap() and Game.credits>=HQCatalog.permanent_cost(tech):return true
	if id=="weapons":
		for bonus in Game.bonus_unlocks:
			if Game.bonus_level(bonus)<Balance.CONFIG.economy.bonus_level_cap and Game.credits>=Game.bonus_cost(bonus):return true
	if id=="character":
		for branch in Game.UNLOCK_COSTS:
			if Game.level(branch)<Game.upgrade_cap(branch) and Game.credits>=(Game.cost(branch) if Game.branch_unlocked(branch) else Game.UNLOCK_COSTS[branch]):return true
		for key in ["slots","rescue"]:
			if Game.special_cost(key)>=0 and (Game.cores if key=="slots" else Game.credits)>=Game.special_cost(key):return true
	if id=="weapons":return Game.weapon_unlocks.size()>1
	if id=="bonuses":
		for bonus in Game.bonus_unlocks:
			if Game.bonus_level(bonus)<Balance.CONFIG.economy.bonus_level_cap and Game.credits>=Game.bonus_cost(bonus):return true
	return false
func show_classes():preload("res://scripts/ui/fighter_station.gd").shell(self)

func show_class_catalog():
	close_station();phase="workshop";dpad.enabled=false;fire_pad.enabled=false;start_button.disabled=true
	build_menu=preload("res://scripts/ui/class_gallery.gd").new();root.add_child(build_menu);build_menu.closed.connect(close_station);build_menu.shell_requested.connect(show_classes)

func show_recipe_shop():
	close_station();phase="workshop";dpad.enabled=false;fire_pad.enabled=false;start_button.disabled=true
	build_menu=load("res://scripts/garage/recipe_shop.gd").new();root.add_child(build_menu)
	build_menu.closed.connect(close_station);build_menu.changed.connect(refresh);build_menu.reset_requested.connect(reset_upgrades)

func bonus_change(id:String,level:int)->String:
	var before=0.0;var after=0.0;var title="Сила";var suffix=""
	match id:
		"heart","repair","vehicle_repair":
			var base=Game.heal_amount() if id=="heart" else (2 if id=="repair" else 3)+Game.heal_level*.15
			before=base*(1+level*.1);after=base*(1+(level+1)*.1);title="Броня" if id=="vehicle_repair" else "Лечение"
		"star":before=6+level*1.5;after=before+1.5;title="Длительность";suffix=" с"
		"freeze":before=3+level;after=before+1;title="Длительность";suffix=" с"
		"pressure":before=8+level*2;after=before+2;title="Длительность";suffix=" с"
		"wall":before=4+level;after=before+1;title="HP стен"
		"turret":before=Balance.CONFIG.enemy("mortar").health+level;after=before+1;title="HP турели"
		"vehicle":before=pow(.92,level)*100;after=pow(.92,level+1)*100;title="Время доставки";suffix="%"
	return UiKit.change_text(title,before,after,suffix)

func show_command():
	close_station();phase="workshop";dpad.enabled=false;fire_pad.enabled=false;start_button.disabled=true
	build_menu=preload("res://scenes/progression/command_screen.tscn").instantiate();root.add_child(build_menu);build_menu.closed.connect(close_station)

func present_unlock():
	if not is_inside_tree() or is_queued_for_deletion():return
	if Game.new_recipes.is_empty() or phase!="combat" or is_instance_valid(build_menu):return
	var recipe=Game.new_recipes.pop_front();phase="workshop"
	build_menu=Control.new();root.add_child(build_menu);build_menu.add_to_group("selection_scope");build_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade=ColorRect.new();build_menu.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.55)
	var panel=UiKit.panel(build_menu,(get_viewport().get_visible_rect().size-Vector2(680,390))*.5,Vector2(680,390))
	UiKit.label(panel,"Новое открытие",Vector2(25,25),Vector2(630,40),29)
	UiKit.icon(panel,recipe.id if recipe.category!="research" else "recipe",Vector2(25,90),Vector2(120,120))
	UiKit.label(panel,Game.recipe_name(recipe),Vector2(165,98),Vector2(490,60),26)
	var info=Game.recipe_catalog(recipe.category)[recipe.id]
	UiKit.label(panel,info.get("description",info.get("effect",info.get("role","Доступно для постройки в хабе."))),Vector2(165,163),Vector2(470,95),17)
	UiKit.button(panel,"Ок",Vector2(25,300),Vector2(300,55),close_station)
	UiKit.button(panel,"Перейти",Vector2(345,300),Vector2(310,55),func():
		close_station()
		if recipe.category=="research":show_build_menu()
		elif recipe.category in ["weapon","bonus","ability"]:open_station("arsenal")
		elif recipe.category=="hq":open_station("hq")
		elif recipe.category=="garage":open_station("garage")
		else:open_station("fighter")
	,true)
	Game.music_stinger("wave_victory")

func use_training_ability(slot:int=0):
	if phase=="intro":return
	hub_skills.cast(slot)

func show_hq_workshop():
	if "headquarters" not in Game.built_workshops:build_tab=0;show_build_menu();return
	close_station();phase="workshop";dpad.enabled=false;fire_pad.enabled=false;start_button.disabled=true
	build_menu=preload("res://scenes/headquarters/workbench.tscn").instantiate();root.add_child(build_menu);build_menu.closed.connect(close_station)

func show_garage():
	if "garage" not in Game.built_workshops:build_tab=1;show_build_menu();return
	close_station();phase="workshop";dpad.enabled=false;fire_pad.enabled=false;start_button.disabled=true
	build_menu=load("res://scenes/garage/workbench.tscn").instantiate();root.add_child(build_menu)
	build_menu.closed.connect(close_station);build_menu.changed.connect(refresh)

func show_recycling():
	close_station();phase="workshop";Game.reset_input()
	build_menu=preload("res://scripts/ui/recycling_station.gd").build(self);root.add_child(build_menu)

func hub_stand(pos:Vector3)->bool:
	var half=.499 if mounted else .249
	for x in [-half,half]:
		for z in [-half,half]:
			if not hub_free(Vector2i(roundi(pos.x+x),roundi(pos.z+z))):return false
	return true

func show_arrival():
	if arrival_reason=="":phase="combat";present_unlock();return
	phase="intro";dpad.enabled=false;fire_pad.enabled=false
	var dialog=preload("res://scripts/ui/arrival_dialog.gd").new();dialog.reason=arrival_reason;arrival_reason=""
	root.add_child(dialog)
	dialog.closed.connect(func():
		phase="combat";dpad.enabled=true;fire_pad.enabled=true;Game.reset_input();call_deferred("present_unlock"))
