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
var credits: Label
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
var hub_skills:Control
var training_barriers:Array=[]
## Outdoor yard to the right of the hangar, through the gap between the racks (row y=0): the parking spot
## and a fenced range with the dummy. Vehicles can drive out there too; the camera slides to follow.
const YARD_PARK=Vector3(11,0,-2)
const YARD_DUMMY=Vector3(16,0,-2)
## Rectangular test track in the south of the yard (centre, half extents) and the guard booth cell.
const TRACK_CENTER=Vector3(13.9,0,1.9)
## Half extents of the rectangular track.
const TRACK_RADII=Vector2(3.1,1.35)
const BOOTH_CELL=Vector2i(10,3)
var camera_base:=Vector3.INF
var camera_tilt:Node
var yard_gate:Node3D
var uniform_preview:MeshInstance3D
var parking_sign:Node3D
var command_meshes:Array=[]
var command_faded=false
var bench_signature:Array=[]
var bench_dots:Dictionary={}
var command_model:Node3D
var training_ability_cooldown=0.0
var build_tab=0
var recipe_tab="weapon"
var build_menu: Control
var bench_visuals: Node3D
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
	# Hangar reflections for metal (T-065): captured once after the hub is built.
	(func():preload("res://scripts/world_lighting.gd").reflection_probe(self,Vector3(16,6,10),Vector3(1,0,.5))).call_deferred()
	var gate=Visuals.model("gate",self,Vector3(5,0,-2))
	gate.scale=Vector3(1.4,1.4,1.4)
	Visuals.box(self,Vector3(5,.03,-2),Vector3(2.6,.03,1.7),Color("d29849"))
	update_bench_visuals()
	Visuals.box(self,Vector3(4,-.08,-5.7),Vector3(4.1,.16,3.2),Color("919b88"))
	var parked=Visuals.model("base",self,Vector3(3.7,0,-5.9));parked.rotation.y=PI*.65
	Visuals.model("hq_supplies",self,Vector3(5.15,0,-5.7))
	printer_model=Visuals.model("printer",self,printer_pos)
	Visuals.label3d(self,"Казарма",printer_pos+Vector3(0,1.95,0),Color("dcf6ec"),24)
	Visuals.model("crate",self,Vector3(-2,0,-2))
	Visuals.model("supply_stack",self,Vector3(-1,0,-2.4))
	displayed_vehicle=Game.garage.starting_vehicle()
	training_tank=Visuals.model(displayed_vehicle if displayed_vehicle!="" else "buggy",self,YARD_PARK)
	preload("res://scripts/world_lighting.gd").headlights(training_tank,true)
	training_tank.rotation.y=PI;training_tank.visible=Game.garage.starting_vehicle()!=""
	pass
	for x in range(-5,8):
		if x in [4,5,6]:continue
		var style=preload("res://scripts/concrete_style.gd").pick(17041,Vector2i(x,-3))
		Visuals.model(preload("res://scripts/concrete_style.gd").asset(style),self,Vector3(x,0,-3))
	spawn_avatar(Vector3(2,0,2),PI)
	# Cool rim light from behind and above keeps the soldier readable against the floor.
	dummy=Node3D.new();add_child(dummy);dummy.position=YARD_DUMMY
	Visuals.model("training_dummy",dummy).scale=Vector3.ONE*1.3  # tools/build_yard_props.py; stands apart in the range pen
	dummy.visible="range" in Game.built_workshops
	build_yard()
	build_wardrobe()
	build_roadmap()
	dummy_label=Visuals.label3d(dummy,"",Vector3(0,1.7,0),Color("f7d891"),26)
	Game.progression.prepare_telegrams()
	command_model=Visuals.model("command_center",self,command_pos)
	command_model.rotation.y=.55  # screen turned toward the hub centre and the camera
	build_command_screen()
	command_meshes=command_model.find_children("*","MeshInstance3D",true,false).filter(func(m):return not command_beams.is_ancestor_of(m))
	# Task alert: a big glowing «!» that hops above the command screen.
	command_alert=Visuals.label3d(self,"!",command_pos+Vector3(0,3.1,0),Color("ed4f40"),96)
	command_alert.no_depth_test=true;command_alert.pixel_size=.014;command_alert.outline_size=16;command_alert.outline_modulate=Color(0,0,0,.55)
	var halo=Visuals.label3d(command_alert,"!",Vector3(0,0,-.01),Color(1,.55,.4,.35),128);halo.name="Halo";halo.no_depth_test=true;halo.outline_size=0;halo.pixel_size=.014
	var glow=OmniLight3D.new();glow.name="Glow";command_alert.add_child(glow);glow.light_color=Color("ff6a4d");glow.omni_range=2.6;glow.light_energy=1.4
	refresh_command_alert()
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Управление",command_pos,1.65)
	preload("res://scripts/ui/recycling_station.gd").model(self,recycling_pos)
	build_ui()
	hub_skills=preload("res://scripts/ui/hub_skills.gd").new();hub_skills.hub=self;root.add_child(hub_skills)
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Казарма",printer_pos,1.4)
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"В бой",Vector3(5,0,-2),2.2)
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Стоянка",YARD_PARK,1.65,func():return "garage" in Game.built_workshops and not mounted)
	preload("res://scripts/printer_intro.gd").play(self)

func build_ui():
	var canvas=CanvasLayer.new();add_child(canvas)
	root=preload("res://scenes/ui/hub_screen.tscn").instantiate();canvas.add_child(root)
	root.get_node("GalleryButton").pressed.connect(func():gallery_requested.emit())
	title=root.get_node("GameTitle");credits=root.get_node("AlloyLabel")
	var title_plate=UiKit.glass(root,Vector2(30,25),Vector2(345,150),Color("242d27ed"));title_plate.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.move_child(title_plate,0)
	for child in root.get_children():
		if child is TextureRect and child.position==Vector2(48,109):child.hide()
	credits.size.x=600;credits.add_theme_font_size_override("font_size",23)
	build_dev_menu()
	dpad=root.get_node("MovePad");dpad.apply_movement_layout();fire_pad=root.get_node("FirePad")
	start_button=root.get_node("StartButton");start_button.pressed.connect(launch);UiKit.accent(start_button,26)
	root.get_node("SettingsButton").hide()
	board_button=root.get_node("InteractButton");board_button.pressed.connect(interact);board_button.hide()
	# Interaction notes («E — выйти»): kept as a hidden label; stations open through station_screen.gd.
	status=Label.new();status.name="StatusLabel";status.visible=false;root.add_child(status)
	refresh()

## Test tools live in one glass menu under the logo; construction is reached in the world (locked benches)
## and from HQ → Buildings, so it sits here only as a shortcut.
func build_dev_menu():
	var toggle=UiKit.button(root,"Инструменты",Vector2(30,191),Vector2(345,50),func():toggle_dev_menu());toggle.name="ToolsButton"
	toggle.icon=UiKit.interface_icon("debug");toggle.expand_icon=true;toggle.add_theme_constant_override("icon_max_width",20);toggle.add_theme_font_size_override("font_size",18)
	var rows=[["DebugAlloyButton","+1000 сплава"],["RecipeShopButton","Магазин чертежей"],["SandboxButton","Песочница"],["DevMapButton","Дев-режим карты: выкл"],["TasksButton","Задачи (F9) · новая — F8"]]
	const PAD=12.0;const ROW=46.0;const GAP=8.0
	var menu=UiKit.glass(root,Vector2(30,249),Vector2(345,PAD*2+rows.size()*ROW+(rows.size()-1)*GAP));menu.name="DevMenu";menu.hide();menu.z_index=20
	var y=PAD
	for row in rows:
		var half=row.size()>2
		for i in range(0,row.size(),2):
			var button:Button=root.get_node_or_null(row[i])
			if button==null:button=UiKit.button(menu,row[i+1],Vector2.ZERO,Vector2.ZERO,func():pass);button.name=row[i]
			else:button.get_parent().remove_child(button);menu.add_child(button)
			button.text=row[i+1];button.add_theme_font_size_override("font_size",16)
			var width=(321.0-GAP)*.5 if half else 321.0
			button.position=Vector2(PAD+(i/2)*(width+GAP),y);button.size=Vector2(width,ROW)
		y+=ROW+GAP
	root.get_node("GalleryButton").hide()
	# Construction: square icon button, second in emphasis after «В бой», in the thumb zone.
	var build:Button=root.get_node("BuildButton");build.text="";build.tooltip_text=Texts.render("Строительство")
	build.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT);build.offset_left=-408;build.offset_right=-332;build.offset_top=-112;build.offset_bottom=-36
	# Thumb-zone actions share the ability tiles' height (76) and top line.
	root.get_node("StartButton").offset_top=-112;root.get_node("StartButton").offset_bottom=-36
	build.icon=load("res://assets/ui/construction/crane.png");build.expand_icon=true;build.add_theme_constant_override("icon_max_width",52);build.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	build.pressed.connect(show_build_menu)
	menu.get_node("DebugAlloyButton").pressed.connect(func():Game.earn(1000);refresh())
	menu.get_node("RecipeShopButton").pressed.connect(func():toggle_dev_menu(false);show_recipe_shop())
	menu.get_node("SandboxButton").pressed.connect(func():toggle_dev_menu(false);sandbox_requested.emit())
	menu.get_node("TasksButton").pressed.connect(func():toggle_dev_menu(false);preload("res://scripts/ui/task_board_view.gd").open(get_tree(),"board"))
	var dev_map:Button=menu.get_node("DevMapButton");Texts.set_text(dev_map,"Дев-режим карты: "+("вкл" if Game.dev_map else "выкл"))
	dev_map.pressed.connect(func():Game.dev_map=not Game.dev_map;Texts.set_text(dev_map,"Дев-режим карты: "+("вкл" if Game.dev_map else "выкл")))
func toggle_dev_menu(open=null):
	var menu=root.get_node("DevMenu");menu.visible=not menu.visible if open==null else bool(open)
	if menu.visible:UiKit.reveal(menu,0,Vector2(0,-10),.2)

func refresh():
	credits.hide()
	update_bench_visuals()



## Idle: dark screen paging abstract maps and dossiers. News: the screen glows with a letter icon and a real
## blue spot light from it softly lights the floor in front. No fake beams.
func build_command_screen():
	var screen=command_model.find_child("CommandScreen",true,false)
	if screen is MeshInstance3D:
		command_screen=ShaderMaterial.new();command_screen.shader=preload("res://shaders/world/command_screen.gdshader");screen.material_override=command_screen
	command_beams=Node3D.new();command_beams.name="CommandLight";command_model.add_child(command_beams)
	var glow=SpotLight3D.new();glow.name="ScreenGlow";glow.light_color=Color("6fb4ff");glow.light_energy=1.6;glow.spot_range=3.6;glow.spot_angle=38;glow.spot_attenuation=1.4;glow.shadow_enabled=false
	# The screen plane faces -Z in the model file; the monolith front (and the camera) is +Z, so the light aims +Z.
	command_beams.add_child(glow);glow.position=Vector3(0,1.5,.55);glow.rotation=Vector3(deg_to_rad(-55),PI,0)

func refresh_command_alert():
	if not is_instance_valid(command_alert):return
	var news=Game.progression.news_kind()
	if command_screen:command_screen.set_shader_parameter("alert",news!="")
	# The blue light belongs to the screen: a faint glow while idle, bright when there is news.
	var glow=command_beams.get_node_or_null("ScreenGlow") if is_instance_valid(command_beams) else null
	if glow:glow.light_energy=1.6 if news!="" else .35
	command_alert.visible=news!=""
	command_alert.modulate=UiKit.NOTICE.news if news=="general" else UiKit.NOTICE.goal

func sync_model_animation():
	var active=phase=="combat" and moving and not is_instance_valid(build_menu)
	avatar.preview_moving=active and not mounted;avatar.preview_speed=3.4
	training_tank.preview_moving=active and mounted;training_tank.preview_speed=2.7

func _physics_process(delta):
	follow_yard(delta)
	sync_model_animation()
	if is_instance_valid(dpad):dpad.visible=InputScheme.touch();fire_pad.visible=InputScheme.touch()
	if phase in ["intro","profiles"]:return
	training_ability_cooldown=maxf(0,training_ability_cooldown-delta)
	hint_clock+=delta;hint_refresh-=delta
	if hint_refresh<=0:
		for id in bench_dots:bench_dots[id].visible=bench_available(id)
		var build:Button=root.get_node("BuildButton")
		var badge=build.get_node_or_null("Badge")
		if badge==null:badge=UiKit.badge(build,"news")
		badge.visible=Game.research_unlocks.any(func(id):return id in Game.BUILD_COST.keys() and preload("res://scripts/ui/build_catalog.gd").has_news(id))
		hint_refresh=.3
		refresh_command_alert()
		var targets=Game.progression.build_targets()
		for id in build_arrows:
			if is_instance_valid(build_arrows[id]):build_arrows[id].visible=id not in Game.built_workshops and (id in Game.research_unlocks or id in targets)
	if is_instance_valid(command_alert):
		# A hop every 1.2 s with a squash on landing; the halo and the light pulse with it.
		var t=fposmod(hint_clock,1.2)/1.2;var hop=sin(minf(t/.45,1.0)*PI) if t<.45 else 0.0
		command_alert.position.y=command_pos.y+3.4+hop*.5
		var squash=1.0-(.18*sin((t-.45)/.15*PI) if t>=.45 and t<.6 else 0.0)
		command_alert.scale=Vector3(2.0-squash,squash,1.0)
		var pulse=.5+.5*sin(hint_clock*TAU/1.2)
		command_alert.get_node("Halo").modulate.a=.2+.3*pulse;command_alert.get_node("Glow").light_energy=.9+1.1*pulse
	for arrow in build_arrows.values():
		if is_instance_valid(arrow):arrow.position.y=1.9+(1-cos(hint_clock*TAU/4.8))*.18
	if is_instance_valid(build_menu):
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
	if not mounted and "garage" in Game.built_workshops and avatar.position.distance_to(YARD_PARK)<1.65:Texts.set_text(board_button,"Стоянка [E]");board_button.disabled=moving
	if nearest_locked()!="":Texts.set_text(board_button,"Построить [E]");board_button.disabled=moving
	if not mounted and avatar.position.distance_to(hq_bench_pos)<1.2:Texts.set_text(board_button,"Технологии [E]");board_button.disabled=moving
	if not mounted and avatar.position.distance_to(recycling_pos)<1.3:Texts.set_text(board_button,"Продать [E]");board_button.disabled=moving
	if Game.wants_fire() and turn_timer<=0 and fire_cooldown<=0:shoot()
	if Game.wants_interact():interact()

## Concrete yard, the range fence (open toward the hangar so vehicles can drive in), a sandbag berm and a
## target board behind the dummy, a lamp post, and the parking sign that shows a tank icon while empty.
## Uniform locker on the old bonus-bench spot by the back wall.
const WARDROBE_POS=Vector3(-3,0,-1)
## «Развитие заставы»: the meta roadmap board by the back wall.
const ROADMAP_POS=Vector3(1,0,-2)
func build_roadmap():
	var board=Node3D.new();board.name="Roadmap";add_child(board);board.position=ROADMAP_POS
	var wood=Color("6d5a40");var cork=Color("b89a6a")
	for x in [-.6,.6]:Visuals.box(board,Vector3(x,.75,0),Vector3(.1,1.5,.1),wood.darkened(.25))
	Visuals.box(board,Vector3(0,1.25,.02),Vector3(1.4,.95,.06),cork)
	Visuals.box(board,Vector3(0,1.25,-.01),Vector3(1.5,1.05,.04),wood)
	# Track lines with pinned cards: done cards are pale, the next goal is orange.
	for row in range(3):
		var y=1.55-row*.28
		Visuals.box(board,Vector3(0,y,.06),Vector3(1.2,.02,.01),Color("8a3a2a"))
		for i in range(4):
			var color=Color("e8dcc0") if i<2-row%2 else Color("f2a33a") if i==2-row%2 else Color("9c8f74")
			Visuals.box(board,Vector3(-.45+i*.3,y,.07),Vector3(.18,.14,.01),color)
	Visuals.label3d(board,"Развитие заставы",Vector3(0,2.0,0),Color("dcf6ec"),22)
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Развитие заставы",ROADMAP_POS,1.3,func():return not mounted)
func build_wardrobe():
	var locker=Node3D.new();locker.name="Wardrobe";add_child(locker);locker.position=WARDROBE_POS
	var olive=Color("59603f");var dark=Color("3f4430")
	Visuals.box(locker,Vector3(0,.95,-.1),Vector3(1.1,1.9,.55),olive)
	for x in [-.27,.27]:
		Visuals.box(locker,Vector3(x,.95,.19),Vector3(.5,1.78,.03),dark)
		for i in range(3):Visuals.box(locker,Vector3(x,1.55+i*.07,.21),Vector3(.3,.025,.01),Color("2a2e22"))
		Visuals.box(locker,Vector3(x+(.18 if x<0 else -.18),.95,.22),Vector3(.04,.16,.03),Color("c9cfbe"))
	# The right door stands open: a uniform on a hanger inside.
	var hanger=Node3D.new();locker.add_child(hanger);hanger.position=Vector3(.62,0,.2)
	Visuals.box(hanger,Vector3(0,1.62,0),Vector3(.3,.03,.03),Color("c9cfbe"))
	uniform_preview=Visuals.box(hanger,Vector3(0,1.28,0),Vector3(.42,.62,.14),Color("5d6147"))
	Visuals.box(hanger,Vector3(0,.82,0),Vector3(.34,.32,.13),Color("4a5039"))
	Visuals.label3d(locker,"Шкаф",Vector3(0,2.15,0),Color("dcf6ec"),22)
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Шкаф",WARDROBE_POS,1.3,func():return not mounted)
## Player soldier in the hub: the wardrobe's cat model with the selected weapon, lamp and ring.
func spawn_avatar(pos:Vector3,yaw:float):
	avatar=Visuals.model("soldier",self,pos,"cat",true)
	avatar.set_meta("player_model",Game.player_model)
	Visuals.equip_model(avatar,Game.selected_weapon)
	preload("res://scripts/world_lighting.gd").headlights(avatar)
	avatar.rotation.y=yaw
	Visuals.ring(avatar,Color("fac47a"),.44)
func refresh_uniform():
	if is_instance_valid(avatar) and avatar.get_meta("player_model","")!=Game.player_model:
		var pos=avatar.position;var yaw=avatar.rotation.y;var shown=avatar.visible
		avatar.queue_free();spawn_avatar(pos,yaw);avatar.visible=shown
	if is_instance_valid(uniform_preview):
		var camo=Skins.camo(Game.skin);uniform_preview.material_override=Visuals.material(camo.get("camo_a",Color("5d6147")))
	if is_instance_valid(avatar) and avatar.has_method("apply_palette"):avatar.apply_palette()
func build_yard():
	var yard=Node3D.new();yard.name="Yard";add_child(yard)
	# A concrete apron flush with the hangar floor (top at y=0), standing on the outside ground.
	Visuals.box(yard,Vector3(13.6,-.42,0),Vector3(8.4,.84,7.4),Color("8d9186"))
	passage(yard)
	range_pen(yard)
	test_track(yard)
	yard_dressing(yard)
	parking_sign=Node3D.new();parking_sign.name="ParkingSign";yard.add_child(parking_sign);parking_sign.position=YARD_PARK+Vector3(.75,0,-.7)
	var post=Color("5b5f57")
	Visuals.box(parking_sign,Vector3(0,.55,0),Vector3(.07,1.1,.07),post)
	Visuals.box(parking_sign,Vector3(0,1.15,0),Vector3(.6,.45,.05),Color("2f3b33"))
	var icon=Sprite3D.new();icon.texture=load("res://assets/icons/v1/vehicle.png");  # world sign: plain sprite, not the UI pin
	icon.pixel_size=.4/maxf(1.0,float(icon.texture.get_width()));icon.position=Vector3(0,1.15,.035);parking_sign.add_child(icon)
## Fenced range in the north-east corner, open on the west side so vehicles can drive in.
func range_pen(yard:Node3D):
	var post=Color("5b5f57");var rail=Color("9aa093")
	for x in [14.5,15.5,16.5,17.4]:Visuals.box(yard,Vector3(x,.45,-3.35),Vector3(.1,.9,.1),post)
	for z in [-2.35,-1.2]:Visuals.box(yard,Vector3(17.4,.45,z),Vector3(.1,.9,.1),post)
	for y in [.35,.75]:
		Visuals.box(yard,Vector3(15.95,y,-3.35),Vector3(2.95,.05,.05),rail)
		Visuals.box(yard,Vector3(17.4,y,-2.28),Vector3(.05,.05,2.15),rail)
	sandbag_row(yard,Vector3(16,0,-2.85),5)
	var board=Visuals.box(yard,Vector3(17.0,.9,-2.9),Vector3(.7,.7,.06),Color("e8e2d0"))
	for r in [.26,.16,.07]:
		var ring=MeshInstance3D.new();var disc=CylinderMesh.new();disc.top_radius=r;disc.bottom_radius=r;disc.height=.02;ring.mesh=disc;ring.rotation.x=PI*.5
		ring.position=Vector3(17.0,.9,-2.86+(.3-r)*.02);ring.material_override=Visuals.material(Color("cf613f") if r!=.16 else Color("e8e2d0"));yard.add_child(ring)
	preload("res://scripts/base_surroundings.gd").lamp(yard,Vector3(17.6,0,-.6))
## Rectangular test track with rounded corners: asphalt, red-white kerbs, a chequered start line, cones,
## a ramp and tyre stacks on the infield. Decoration only; soldier and vehicles drive over it.
func track_point(t:float)->Vector3:
	# Rounded rectangle, perimeter parameter t in [0,1).
	var half=TRACK_RADII;var r=.55
	var sx=(half.x-r)*2.0;var sz=(half.y-r)*2.0;var arc=PI*.5*r
	var total=2.0*(sx+sz)+4.0*arc;var d=fposmod(t,1.0)*total
	var corners=[Vector2(half.x-r,-(half.y-r)),Vector2(half.x-r,half.y-r),Vector2(-(half.x-r),half.y-r),Vector2(-(half.x-r),-(half.y-r))]
	var starts=[Vector2(-(half.x-r),-half.y),Vector2(half.x,-(half.y-r)),Vector2(half.x-r,half.y),Vector2(-half.x,half.y-r)]
	var dirs=[Vector2(1,0),Vector2(0,1),Vector2(-1,0),Vector2(0,-1)];var lengths=[sx,sz,sx,sz]
	for k in range(4):
		if d<=lengths[k]:var q=starts[k]+dirs[k]*d;return TRACK_CENTER+Vector3(q.x,0,q.y)
		d-=lengths[k]
		if d<=arc:
			var a=-PI*.5+k*PI*.5+d/r;var c=corners[k];return TRACK_CENTER+Vector3(c.x+cos(a)*r,0,c.y+sin(a)*r)
		d-=arc
	return TRACK_CENTER+Vector3(-(half.x-r),0,-half.y)
func test_track(yard:Node3D):
	var segments=40;var asphalt=Color("575a55")
	Visuals.box(yard,TRACK_CENTER+Vector3(0,.012,0),Vector3(TRACK_RADII.x*2.0-.9,.012,TRACK_RADII.y*2.0-.9),Color("7d8a6a"))
	for i in range(segments):
		var pa=track_point(float(i)/segments);var pb=track_point(float(i+1)/segments)
		var mid=(pa+pb)*.5;var length=pa.distance_to(pb)+.05;var yaw=-atan2(pb.z-pa.z,pb.x-pa.x)
		var piece=Visuals.box(yard,mid+Vector3(0,.022,0),Vector3(length,.02,.5),asphalt);piece.rotation.y=yaw
		var normal=Vector3(-(pb.z-pa.z),0,pb.x-pa.x).normalized()
		for side in [-1,1]:
			var kerb=Visuals.box(yard,mid+normal*side*.27+Vector3(0,.035,0),Vector3(length*.9,.03,.06),Color("cf613f") if i%2==0 else Color("e8e2d0"));kerb.rotation.y=yaw
	for k in range(6):Visuals.box(yard,track_point(0.02)+Vector3(0,.036,-.2+k*.08),Vector3(.12,.012,.08),Color("f2f1df") if k%2==0 else Color("222522"))
	for t in [.14,.3,.62,.78]:
		var cone=MeshInstance3D.new();var shape=CylinderMesh.new();shape.top_radius=.02;shape.bottom_radius=.1;shape.height=.26;cone.mesh=shape
		cone.position=track_point(t)+Vector3(0,.16,0);cone.material_override=Visuals.material(Color("ff8a3d"));yard.add_child(cone)
	var ramp=Visuals.box(yard,track_point(.45)+Vector3(0,.09,0),Vector3(.8,.08,.46),Color("b8a47c"));ramp.rotation.z=.16
	for p in [TRACK_CENTER+Vector3(-.9,0,0),TRACK_CENTER+Vector3(1.0,0,0)]:
		for i in range(2):
			var tyre=MeshInstance3D.new();var torus=TorusMesh.new();torus.inner_radius=.12;torus.outer_radius=.26;tyre.mesh=torus
			tyre.position=p+Vector3(0,.07+i*.13,0);tyre.material_override=Visuals.material(Color("2a2c2a") if i==0 else Color("cf613f"));yard.add_child(tyre)
## Covered passage from the hangar to the yard along row 0: grating floor with hazard edges, panel walls,
## roof beams with amber lamps and a raised roll-up gate on the hangar side.
func passage(yard:Node3D):
	var steel=Color("5d646a");var panel=Color("6f766f")
	Visuals.box(yard,Vector3(9.15,.02,0),Vector3(2.5,.04,1.4),Color("4c514c"))  # decal layers: .04 grating, .05 stripes
	for i in range(9):Visuals.box(yard,Vector3(8.05+i*.28,.045,0),Vector3(.05,.01,1.3),Color("3b3f3b"))
	for z in [-.68,.68]:
		for i in range(10):Visuals.box(yard,Vector3(8.0+i*.25,.05,z),Vector3(.12,.012,.08),Color("e5b34f") if i%2==0 else Color("2f332d"))
		Visuals.box(yard,Vector3(9.25,.8,z*1.4),Vector3(1.9,1.6,.08),panel)
		for x in [8.3,9.25,10.2]:Visuals.box(yard,Vector3(x,1.1,z*1.4),Vector3(.12,2.2,.12),steel)
	for x in [8.3,8.95,9.6,10.2]:Visuals.box(yard,Vector3(x,2.22,0),Vector3(.12,.12,2.0),steel)
	# Open beams, no roof plate: the top-down camera must see who walks through.
	for x in [8.65,9.9]:
		var lamp=Visuals.box(yard,Vector3(x,2.08,0),Vector3(.3,.07,.14),Color("ffcf7a"));lamp.material_override=Visuals.material(Color("ffcf7a"),true)
	var light=OmniLight3D.new();light.light_color=Color("ffcf8a");light.light_energy=.9;light.omni_range=2.6;light.position=Vector3(9.25,1.8,0);yard.add_child(light)
	# Roll-up gate, raised: drum and rails at the hangar end, a beacon on top.
	var drum=MeshInstance3D.new();var cyl=CylinderMesh.new();cyl.top_radius=.16;cyl.bottom_radius=.16;cyl.height=1.9;drum.mesh=cyl;drum.rotation.x=PI*.5
	drum.position=Vector3(8.2,2.0,0);drum.material_override=Visuals.material(Color("8a8f86"));yard.add_child(drum)
	var beacon=Visuals.box(yard,Vector3(8.2,2.4,.75),Vector3(.14,.14,.14),Color("ffb52c"));beacon.material_override=Visuals.material(Color("ffb52c"),true)
	# Closed gate until the yard is bought: a ribbed shutter with hazard stripes.
	yard_gate=Node3D.new();yard_gate.name="YardGate";yard.add_child(yard_gate);yard_gate.position=Vector3(8.2,0,0)
	Visuals.box(yard_gate,Vector3(0,1.0,0),Vector3(.08,2.0,1.8),Color("7d837b"))
	for i in range(6):Visuals.box(yard_gate,Vector3(-.05,.3+i*.3,0),Vector3(.02,.05,1.8),Color("5d635b"))
	for i in range(5):Visuals.box(yard_gate,Vector3(-.05,.12,-.72+i*.36),Vector3(.02,.12,.18),Color("e5b34f"))
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"🔒 Площадка · %d ◈" % Game.YARD_COST,Vector3(7,0,0),1.3,func():return "yard" not in Game.built_workshops and not mounted)
## Around the apron: concrete barriers along the south and east edges, parking lines, a guard booth and a
## flag at the entrance, a container on the ground behind the range.
func yard_dressing(yard:Node3D):
	var block=Color("a2a596")
	for x in [11.0,12.3,13.6,14.9,16.2]:Visuals.box(yard,Vector3(x,.25,3.55),Vector3(1.1,.5,.35),block)
	for z in [.2,1.5,2.8]:Visuals.box(yard,Vector3(17.65,.25,z),Vector3(.35,.5,1.1),block)
	for dx in [-.55,.55]:Visuals.box(yard,YARD_PARK+Vector3(dx,.012,0),Vector3(.06,.012,1.5),Color("e8e2d0"))
	Visuals.box(yard,YARD_PARK+Vector3(0,.012,.72),Vector3(1.16,.012,.06),Color("e8e2d0"))
	var booth=Node3D.new();yard.add_child(booth);booth.position=Vector3(BOOTH_CELL.x,0,BOOTH_CELL.y)
	Visuals.box(booth,Vector3(0,.7,0),Vector3(.9,1.4,.8),Color("59603f"))
	Visuals.box(booth,Vector3(0,1.46,0),Vector3(1.05,.1,.95),Color("454a33"))
	var window=Visuals.box(booth,Vector3(.46,.95,0),Vector3(.02,.35,.5),Color("9fd4ff"));window.material_override=Visuals.material(Color("9fd4ff"),true)
	var flag=Node3D.new();yard.add_child(flag);flag.position=Vector3(10.2,0,-3.1);flag.scale=Vector3.ONE*.55;ExitFlag.build(flag)
	var container=Visuals.box(self,Vector3(19.4,-.72+.65,-1.6),Vector3(1.3,1.3,2.8),Color("7a4a33"))
	for i in range(6):Visuals.box(self,Vector3(18.73,-.72+.65,-2.8+i*.48),Vector3(.02,1.2,.08),Color("5f3a28"))
func sandbag_row(parent:Node3D,center:Vector3,count:int):
	for i in range(count):Visuals.box(parent,center+Vector3((i-(count-1)*.5)*.46,.14+(i%2)*.02,0),Vector3(.44,.26,.3),Color("b8a47c"))
## The camera slides right while the soldier or the parked vehicle is out in the yard.
func follow_yard(delta:float):
	var camera=get_viewport().get_camera_3d()
	if not is_instance_valid(camera) or not is_instance_valid(avatar):return
	if camera_base==Vector3.INF:camera_base=camera.position
	var who=training_tank if mounted else avatar
	var shift=clampf((who.position.x-6.0)*1.1,0.0,10.0)
	# A few degrees of diorama tilt toward the cursor or a drag; eases back on its own.
	if camera_tilt==null:camera_tilt=preload("res://scripts/camera_tilt.gd").new();camera_tilt.name="CameraTilt";add_child(camera_tilt)
	camera_tilt.enabled=phase=="combat" and not is_instance_valid(build_menu)
	var focus=Vector3(shift,0,0)
	var arm=(camera_base-Vector3.ZERO).rotated(Vector3.UP,deg_to_rad(camera_tilt.yaw()))
	arm=arm.rotated(arm.cross(Vector3.UP).normalized(),deg_to_rad(camera_tilt.pitch()))
	camera.position=camera.position.lerp(focus+arm,minf(1.0,delta*4.0))
	camera.look_at(camera.position-arm)
	if is_instance_valid(yard_gate):yard_gate.visible="yard" not in Game.built_workshops
	if is_instance_valid(parking_sign):parking_sign.visible="garage" in Game.built_workshops and (Game.garage.starting_vehicle()=="" or (not training_tank.visible and not mounted))

func hub_free(p: Vector2i) -> bool:
	if p in training_barriers or p in [Vector2i(-2,3),Vector2i(3,3),Vector2i(6,3)]:return false
	if p.x>7:
		if "yard" not in Game.built_workshops:return false
		# Yard: the rack gap (x 8-9 only on row 0), then open concrete x 10-17, y -3..3 except the dummy and booth.
		if p.x<=9:return p.y==0
		return p.x<=17 and p.y>=-3 and p.y<=3 and p!=Vector2i(roundi(YARD_DUMMY.x),roundi(YARD_DUMMY.z)) and p!=BOOTH_CELL
	if p.x< -4 or p.y< -2 or p.y>4:return false
	# Command centre (left edge), crates by the back wall, the range pad and the arsenal spot. The retired
	# workbench cells (character at 0,-1 and bonuses at -3,-1) are walkable floor now.
	if p in [Vector2i(-4,0),Vector2i(-4,1),Vector2i(-4,2),Vector2i(0,3),Vector2i(-2,-2),Vector2i(-1,-2),Vector2i(-3,-1),Vector2i(1,-2)]:return false
	if not mounted and training_tank.visible and Vector2i(roundi(training_tank.position.x),roundi(training_tank.position.z))==p:return false
	return true

func interact():
	if phase=="intro":return
	if is_instance_valid(build_menu):close_station();return
	if moving:return
	if not mounted and avatar.position.distance_to(recycling_pos)<1.3:show_recycling();return
	if not mounted and avatar.position.distance_to(hq_bench_pos)<1.2:open_station("hq");return
	if not mounted and avatar.position.distance_to(command_pos)<1.65:show_command();return
	if not mounted and avatar.position.distance_to(printer_pos)<1.4:open_station("fighter");return
	if not mounted and avatar.position.distance_to(WARDROBE_POS)<1.3:open_station("wardrobe");return
	if not mounted and avatar.position.distance_to(ROADMAP_POS)<1.3:open_station("roadmap");return
	if not mounted and "garage" in Game.built_workshops and avatar.position.distance_to(YARD_PARK)<1.65:open_station("garage");return
	var locked=nearest_locked()
	if locked!="":build_tab=1 if locked in ["garage","range"] else 0;show_build_menu();return
	if not mounted and "yard" not in Game.built_workshops and avatar.position.distance_to(Vector3(7,0,0))<1.3:show_build_menu();return
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
	if is_instance_valid(build_menu):return
	exit_queued=true
	Game.reset_input()
	start_requested.emit()

func close_station():
	# Leaving a station marks what was affordable there as seen: its bench dot waits for something new.
	if is_instance_valid(build_menu) and str(build_menu.get("station_kind") if "station_kind" in build_menu else "")!="":
		preload("res://scripts/ui/station_notices.gd").mark_viewed(build_menu.station_kind)
	if is_instance_valid(build_menu):build_menu.get_parent().remove_child(build_menu);build_menu.queue_free();build_menu=null
	phase="combat";Game.reset_input();dpad.clear();fire_pad.clear();dpad.enabled=true;fire_pad.enabled=true;start_button.disabled=false
	call_deferred("present_unlock")

func shoot():
	if phase=="intro":return
	if is_instance_valid(build_menu):return
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
	# The built yard extends the hub east to the range pen: shots there must reach the dummy.
	if pos.x< -3 or pos.x>(17.5 if "yard" in Game.built_workshops else 8.0) or pos.z< -3 or pos.z>4:return true
	var p=Vector2i(roundi(pos.x),roundi(pos.z))
	return p in [Vector2i(-2,-2),Vector2i(-1,-2),Vector2i(0,-1)] or p.y== -3





func update_bench_visuals():
	if is_instance_valid(avatar) and avatar.weapon_id!=Game.selected_weapon:Visuals.equip_model(avatar,Game.selected_weapon)
	hint_refresh=0
	if not is_instance_valid(bench_visuals) or bench_signature!=Game.built_workshops:
		bench_signature=Game.built_workshops.duplicate()
		build_arrows.clear();bench_dots.clear()
		if is_instance_valid(bench_visuals):remove_child(bench_visuals);bench_visuals.queue_free()
		bench_visuals=Node3D.new();add_child(bench_visuals)
		for id in Game.BUILD_COST:
			var pos={"headquarters":hq_bench_pos,"character":Vector3(0,0,-1),"weapons":weapon_bench_pos,"bonuses":bonus_bench_pos,"garage":YARD_PARK,"range":YARD_DUMMY}[id]
			if id not in Game.built_workshops:
				var arrow=Visuals.label3d(bench_visuals,"▼",pos+Vector3.UP*1.5,UiKit.NOTICE.goal,38);arrow.modulate.a=.82;arrow.outline_size=6
				arrow.no_depth_test=true;arrow.visible=id in Game.research_unlocks or id in Game.progression.build_targets();build_arrows[id]=arrow
			if id not in ["garage","range"]:
				preload("res://scripts/interaction_prompt.gd").attach(bench_visuals,self,Game.RESEARCH[id].name if id in Game.built_workshops else "🔒 Построить · "+Game.RESEARCH[id].name,pos,1.25)
			if id=="garage":
				Visuals.model("parking",bench_visuals,pos)
				continue
			if id in Game.built_workshops:
				var dot=Visuals.label3d(bench_visuals,"●",pos+Vector3.UP*2.0,UiKit.NOTICE.ready,42);dot.outline_size=0
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
			training_tank.queue_free();training_tank=Visuals.model(selected,self,YARD_PARK);training_tank.rotation.y=PI
		displayed_vehicle=selected;training_tank.visible=selected!=""
	if is_instance_valid(dummy):dummy.visible="range" in Game.built_workshops
func show_build_menu():preload("res://scripts/ui/build_menu.gd").show(self)

## The four stations share one screen (scripts/ui/station_screen.gd); only «Казарма» needs no building.
const STATIONS={"roadmap":["","res://scripts/ui/stations/roadmap_station.gd"],"wardrobe":["","res://scripts/ui/stations/wardrobe_station.gd"],"fighter":["","res://scripts/ui/stations/fighter_station.gd"],"arsenal":["weapons","res://scripts/ui/stations/arsenal_station.gd"],"hq":["headquarters","res://scripts/ui/stations/hq_station.gd"],"garage":["garage","res://scripts/ui/stations/garage_station.gd"]}
func open_station(kind:String):
	var building=STATIONS[kind][0]
	if building!="" and building not in Game.built_workshops:build_tab=0;show_build_menu();return
	if building!="":preload("res://scripts/ui/build_catalog.gd").mark(building)
	close_station();phase="workshop";Game.reset_input();dpad.clear();fire_pad.clear();dpad.enabled=false;fire_pad.enabled=false;start_button.disabled=true
	var screen=preload("res://scripts/ui/station_screen.gd").new();screen.name="Station_"+kind;screen.provider=load(STATIONS[kind][1]).new();screen.station_kind=kind
	build_menu=screen;root.add_child(screen);screen.closed.connect(close_station);screen.changed.connect(refresh)
	if kind=="wardrobe":screen.changed.connect(refresh_uniform)

func nearest_locked() -> String:
	if mounted:return ""
	for id in Game.BUILD_COST:
		var pos={"headquarters":hq_bench_pos,"character":Vector3(0,0,-1),"weapons":weapon_bench_pos,"bonuses":bonus_bench_pos,"garage":YARD_PARK,"range":YARD_DUMMY}[id]
		if id not in Game.built_workshops and avatar.position.distance_to(pos)<1.25:return id
	return ""

## A bench dot is seen-aware: it lights up when something new became affordable or unlocked since the
## station was last opened (scripts/ui/station_notices.gd), not whenever money is enough for anything.
func bench_available(id:String)->bool:
	var notices=preload("res://scripts/ui/station_notices.gd")
	return id in notices.BENCHES and notices.has_dot(notices.BENCHES[id])


## Dev «reset profile» (recipe shop): wipe upgrades, park the avatar and the training tank.
func reset_upgrades():
	Game.reset_upgrades()
	mounted=false;moving=false;cell=Vector2i(2,2);destination=Vector3(2,0,2);avatar.position=destination;avatar.show()
	training_tank.position=YARD_PARK;update_bench_visuals();close_station()
	Texts.set_text(status,"Профиль обнулён.")
	refresh()
func show_recipe_shop():
	close_station();phase="workshop";dpad.enabled=false;fire_pad.enabled=false;start_button.disabled=true
	build_menu=load("res://scripts/garage/recipe_shop.gd").new();root.add_child(build_menu)
	build_menu.closed.connect(close_station);build_menu.changed.connect(refresh);build_menu.reset_requested.connect(reset_upgrades)


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
	UiKit.accent(UiKit.label(panel,"Новое открытие",Vector2(25,25),Vector2(630,40),29))
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
	if arrival_reason=="":phase="combat";present_call();return
	phase="intro";dpad.enabled=false;fire_pad.enabled=false
	var dialog=preload("res://scripts/ui/arrival_dialog.gd").new();dialog.reason=arrival_reason;arrival_reason=""
	root.add_child(dialog)
	dialog.closed.connect(func():
		phase="combat";dpad.enabled=true;fire_pad.enabled=true;Game.reset_input();call_deferred("present_call"))

## Tutorial video call from HQ (once per trigger), then pending unlock cards.
func present_call():
	if not is_inside_tree() or is_queued_for_deletion():return
	var VideoCall=preload("res://scripts/ui/video_call.gd")
	var call=VideoCall.due(self)
	if call=="" or phase!="combat":present_unlock();return
	# The call rings in the corner; the player answers when ready, nothing is blocked meanwhile.
	if root.has_node("IncomingCall"):return
	var ring=preload("res://scripts/ui/incoming_call.gd").new();ring.call_id=call;root.add_child(ring)
	ring.answered.connect(func():open_call(call))
	present_unlock()
func open_call(call:String):
	# Answered while an unlock card is open: the call starts right after it.
	while is_inside_tree() and phase!="combat":await get_tree().process_frame
	if not is_inside_tree():return
	phase="intro";dpad.enabled=false;fire_pad.enabled=false
	var view=preload("res://scripts/ui/video_call.gd").new();view.id=call;root.add_child(view)
	view.closed.connect(func():
		phase="combat";dpad.enabled=true;fire_pad.enabled=true;Game.reset_input())
