extends "res://scripts/playground.gd"
## The hub on the one field engine (step 2, guides/02_development/07_one_world.md): a playground of the practice
## run's Arena in «hub» mode. The arena owns the hero — the same Actor as in battle (movement, speed, collision,
## animation, shooting through Gun/CombatSystem, abilities through RunAbility with real cooldowns, ammo, the
## backpack and the drop floor, the HUD) — built from the hub loadout of this moment like a sortie start
## (arena.start_run_state). Station changes rebuild it at once (sync_practice → arena.reset_practice). Nothing here
## hurts the hero, earns alloy or writes the profile. The hub keeps only what is its own: the hangar and yard
## dressing, the stations and their windows, calls and dialogs, the range dummy's stand, the camera that follows
## the hero across the yard. Open with Hub.open_practice(parent) (main.gd).
signal start_requested
signal gallery_requested
signal sandbox_requested
var arrival_reason=""
var recycling_pos=Vector3(6,0,3)
var printer_pos=Vector3(3,0,3)
var printer_model:Node3D
var credits: Label
var start_button: Button
var status: Label
var title: TextureRect
var subtitle: Label
var exit_queued=false
## The range dummy: a practice target of the arena (service_field.spawn_target) — every card, ammo and ability
## hits it through the combat code; it never falls.
var dummy: Node3D
## The hub's own UI state: «combat» (free), «workshop» (a station or window), «intro», «ringing», «profiles».
## Anything but «combat» holds the field (window_open → arena phase «upgrade»).
var phase="combat"
## Open station or window; the same slot as a room's `modal`.
var build_menu:Control:
	get:return modal
	set(value):modal=value
## The printer intro drives the camera while it plays.
var intro_camera:=false
## Hub world cells held as arena walls now (the edge of the walkable floor), to follow buildings as they appear.
var solid_now:Dictionary={}
var practice_key:=""
var field_live:=false
## Outdoor yard to the right of the hangar, through the gap between the racks (row y=0): the parking spot
## and a fenced range with the dummy. Vehicles can drive out there too; the camera slides to follow.
const YARD_PARK=Vector3(12,0,-2)  # T-270: one cell right of the passage exit
## T-010: the range is a long lane — fire from the marked spot, the target stands far away behind sandbags.
const YARD_DUMMY=Vector3(21,0,-2)
const FIRING_SPOT=Vector3(15,0,-2)
const YARD_EAST=22
## Motor pool terminal next to the parking bay (T-014).
const GARAGE_TERMINAL=Vector3(12,0,-3)
## Rectangular test track in the south of the yard (centre, half extents) and the guard booth cell.
const TRACK_CENTER=Vector3(16.3,0,.9)  # T-270: a cell up, clear of the south barriers
## Half extents of the rectangular track.
const TRACK_RADII=Vector2(5.3,1.35)
const BOOTH_CELL=Vector2i(10,3)
## Tyre stacks on the track infield stand on whole cells, and those cells are not walkable (T-270).
const TYRE_CELLS=[Vector2i(15,1),Vector2i(17,1)]
## The hub frame (the old hub scene's camera): orthographic 11.2, the same arm as every field.
const CAMERA_SIZE:=11.2
var camera_tilt:Node
var yard_gate:Node3D
var uniform_preview:MeshInstance3D
var parking_sign:Node3D
var command_meshes:Array=[]
var command_faded=false
var bench_signature:Array=[]
var bench_dots:Dictionary={}
var command_model:Node3D
var build_tab=0
var recipe_tab="weapon"
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
var roadmap_alert:Label3D
var barracks_dot:Label3D
var hq_bench_pos=Vector3(-2,0,3)
var weapon_bench_pos=Vector3(0,0,3)


## Opens the hub: a practice-run arena under `parent` with this hub as its playground (one field engine, step 2).
## Returns the hub; freeing the hub frees its arena too.
static func open_practice(parent:Node,reason:="")->Node3D:
	var field=load("res://scenes/arena.tscn").instantiate();field.practice=true;field.auto_pause_enabled=false
	var hub=load("res://scenes/hub.tscn").instantiate();hub.arrival_reason=reason
	# Known before the arena enters the tree: its light is set up once, in the hub's palette (arena.room_palette).
	field.playground=hub
	parent.add_child(field)
	field.begin_hub(hub)
	return hub

func _ready():
	add_to_group("profile_hub")
	PerfOverlay.show_build=true;tree_exiting.connect(func():PerfOverlay.show_build=false)
	add_to_group("notification_context")
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
	exit_marks()
	update_bench_visuals()
	Visuals.box(self,Vector3(4,-.08,-5.7),Vector3(4.1,.16,3.2),Color("919b88"))
	var parked=Visuals.model("base",self,Vector3(3.7,0,-5.9));parked.rotation.y=PI*.65
	Visuals.model("hq_supplies",self,Vector3(5.15,0,-5.7))
	printer_model=Visuals.model("printer",self,printer_pos)
	Visuals.label3d(self,"Казарма",printer_pos+Vector3(0,1.95,0),Color("dcf6ec"),24)
	# T-093: a green dot blinks over the Barracks while something there can be bought or upgraded.
	barracks_dot=Visuals.label3d(self,"●",printer_pos+Vector3(0,2.35,0),UiKit.NOTICE.ready,48);barracks_dot.outline_size=0;barracks_dot.no_depth_test=true;barracks_dot.name="BarracksDot"
	Visuals.model("crate",self,Vector3(-2,0,-2))
	Visuals.model("supply_stack",self,Vector3(-1,0,-2.4))
	for x in range(-5,8):
		if x in [4,5,6]:continue
		var style=preload("res://scripts/concrete_style.gd").pick(17041,Vector2i(x,-3))
		Visuals.model(preload("res://scripts/concrete_style.gd").asset(style),self,Vector3(x,0,-3))
	build_yard()
	build_wardrobe()
	# T-174: the number on the back wall (boss wins count it down).
	var counter=preload("res://scripts/wall_counter.gd").new();add_child(counter);counter.position=Vector3(-1.0,1.95,-3.0)
	build_roadmap()
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
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Управление",command_pos,1.65,on_foot)
	preload("res://scripts/ui/recycling_station.gd").model(self,recycling_pos)
	build_hub_ui()
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Казарма",printer_pos,1.4,on_foot)
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"В бой",Vector3(5,0,-2),2.2,on_foot)
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Стоянка",GARAGE_TERMINAL,1.2,func():return "garage" in Game.built_workshops and on_foot())
	var terminal=Visuals.box(self,GARAGE_TERMINAL+Vector3(0,.55,0),Vector3(.45,1.1,.3),Color("5b6650"));terminal.name="GarageTerminal"
	var screen=Visuals.box(self,GARAGE_TERMINAL+Vector3(0,.82,.16),Vector3(.34,.26,.02),Color("7fd0ff"));screen.material_override=Visuals.material(Color("7fd0ff"),true)

## The hero stands on the field (the arena spawned him): the hub's HUD layout and camera, the range dummy, the
## parked vehicle, then the printer intro.
func field_ready():
	arena.hud.hub_mode(true)
	arena.camera.size=CAMERA_SIZE
	var hero=avatar;hero.facing=Vector2i.DOWN;hero.model.rotation.y=PI
	practice_key=practice_signature()
	field_live=true
	sync_field()
	preload("res://scripts/printer_intro.gd").play(self)

## Freeing the hub frees its practice arena (main.clear_current frees the hub).
func _exit_tree():
	if is_instance_valid(arena) and arena.get("practice") and not arena.is_queued_for_deletion():arena.queue_free()

func build_hub_ui():
	var canvas=CanvasLayer.new();add_child(canvas)
	root=preload("res://scenes/ui/hub_screen.tscn").instantiate();canvas.add_child(root)
	root.get_node("GalleryButton").pressed.connect(func():gallery_requested.emit())
	title=root.get_node("GameTitle");credits=root.get_node("AlloyLabel")
	var title_plate=UiKit.glass(root,Vector2(30,25),Vector2(345,150),Color("242d27ed"));title_plate.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.move_child(title_plate,0)
	for child in root.get_children():
		if child is TextureRect and child.position==Vector2(48,109):child.hide()
	credits.size.x=600;credits.add_theme_font_size_override("font_size",23)
	build_dev_menu()
	# Movement, fire and E on touch are the arena HUD's own pads (one field engine): the hub screen has none.
	start_button=root.get_node("StartButton");start_button.pressed.connect(launch);UiKit.accent(start_button,26)
	root.get_node("SettingsButton").hide()
	# Interaction notes: kept as a hidden label; stations open through station_screen.gd.
	status=Label.new();status.name="StatusLabel";status.visible=false;root.add_child(status)
	refresh()


## Test tools live in one glass menu under the logo; construction is reached in the world (locked benches)
## and from HQ → Buildings, so it sits here only as a shortcut.
func build_dev_menu():
	var toggle=UiKit.button(root,"Инструменты",Vector2(30,191),Vector2(345,50),func():toggle_dev_menu());toggle.name="ToolsButton"
	toggle.icon=UiKit.interface_icon("debug");toggle.expand_icon=true;toggle.add_theme_constant_override("icon_max_width",20);toggle.add_theme_font_size_override("font_size",18)
	var rows=[["DebugAlloyButton","+1000 сплава"],["RecipeShopButton","Магазин чертежей"],["SandboxButton","Песочница"],["DevMapButton","Дев-режим карты: выкл"],["TasksButton","Задачи (F9) · новая — F8"],["MaterialsButton","Материалы"]]
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
	menu.get_node("MaterialsButton").pressed.connect(func():toggle_dev_menu(false);preload("res://scripts/ui/material_library_view.gd").open(get_tree()))
	menu.get_node("TasksButton").pressed.connect(func():toggle_dev_menu(false);preload("res://scripts/ui/task_board_view.gd").open(get_tree(),"board"))
	var dev_map:Button=menu.get_node("DevMapButton");Texts.set_text(dev_map,"Дев-режим карты: "+("вкл" if Game.dev_map else "выкл"))
	dev_map.pressed.connect(func():Game.dev_map=not Game.dev_map;Texts.set_text(dev_map,"Дев-режим карты: "+("вкл" if Game.dev_map else "выкл")))
func toggle_dev_menu(open=null):
	var menu=root.get_node("DevMenu");menu.visible=not menu.visible if open==null else bool(open)
	if menu.visible:UiKit.reveal(menu,0,Vector2(0,-10),.2)

func refresh():
	credits.hide()
	update_bench_visuals()
	sync_practice()

## What the practice run is built from: the hub loadout and everything that shapes the start of a sortie (class
## and its path, Arsenal weapon and its meta levels, gadget, HQ modules, Barracks upgrades, the garage, the
## uniform). Alloy, quests and notifications are left out: spending or a task tick does not rebuild the hero.
func practice_signature()->String:
	var data:Dictionary=Game.serialize_progress()
	for key in ["credits","notifications","progression","run_checkpoint","duplicate_recipes","research","built"]:data.erase(key)
	if data.get("v09") is Dictionary:data.v09.erase("cores")
	return str(data)+str(Game.progression.weapon_levels)
## A station changed the loadout: the practice hero is rebuilt at once, exactly as a sortie would start now.
func sync_practice():
	if not field_live or not is_instance_valid(arena):return
	var key=practice_signature()
	if key!=practice_key:
		practice_key=key;arena.reset_practice()
	sync_field()
func on_foot()->bool:return is_instance_valid(avatar) and avatar.kind=="soldier"
func riding()->bool:return is_instance_valid(avatar) and avatar.kind!="soldier"

## The field follows the buildings: walls at the edge of the walkable floor, the range dummy, the parked vehicle.
func sync_field():
	if not field_live or not is_instance_valid(arena):return
	var wanted={}
	for c in solid_cells():wanted[c]=true
	for c in solid_now.keys():
		if not wanted.has(c):arena.service.unblock(c)
	for c in wanted:
		if not solid_now.has(c):arena.service.block(c)
	solid_now=wanted
	sync_dummy();sync_vehicle()
func sync_dummy():
	var built="range" in Game.built_workshops
	if built and not is_instance_valid(dummy):
		dummy=arena.service.spawn_target(YARD_DUMMY,"training_dummy")  # tools/build_yard_props.py; stands apart in the range pen
		dummy.model.rotation.y=0;dummy.model.scale=Vector3.ONE*1.3;dummy.name="RangeDummy"
	elif not built and is_instance_valid(dummy):
		arena.actors.erase(dummy);dummy.queue_free();dummy=null
## The garage's selected vehicle waits on the parking bay as the arena's own vehicle (VehicleSystem): E boards it,
## its armour, gun and speed are GarageCatalog.stats with the garage upgrades — the same machine as in a sortie.
func sync_vehicle():
	var kind=Game.garage.starting_vehicle()
	# Every vehicle standing in the hub is the garage's (parked here or left where it was driven).
	for wreck in arena.wrecks.duplicate():
		if is_instance_valid(wreck) and wreck.kind!=kind:
			arena.wrecks.erase(wreck);wreck.queue_free()
	if kind=="":return
	if is_instance_valid(avatar) and avatar.kind==kind:return
	if arena.wrecks.any(func(w):return is_instance_valid(w) and not w.spent and w.kind==kind):return
	var wreck=arena.make_wreck(kind,arena.grid_pos(YARD_PARK),Vector2i.DOWN,false,arena.vehicle.player_armor(kind,"owned",1),"owned",1)
	wreck.set_meta("hub_parked",true)

## The hub's camera (presentation calls it): the old hub frame that slides right while the hero (on foot or driving)
## is out in the yard, with a few degrees of diorama tilt toward the cursor or a drag.
func frame_camera(camera:Camera3D,delta:float):
	if intro_camera or not is_instance_valid(avatar):return
	camera.size=CAMERA_SIZE
	var shift=clampf((avatar.position.x-6.0)*1.45,0.0,16.5)
	if camera_tilt==null:camera_tilt=preload("res://scripts/camera_tilt.gd").new();camera_tilt.name="CameraTilt";add_child(camera_tilt)
	camera_tilt.enabled=phase=="combat" and not is_instance_valid(build_menu)
	var focus=Vector3(shift,0,0)
	var arm=Vector3(0,19,14).rotated(Vector3.UP,deg_to_rad(10)).rotated(Vector3.UP,deg_to_rad(camera_tilt.yaw()))
	arm=arm.rotated(arm.cross(Vector3.UP).normalized(),deg_to_rad(camera_tilt.pitch()))
	camera.position=camera.position.lerp(focus+arm,minf(1.0,delta*4.0))
	camera.look_at(camera.position-arm)



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

## Only the hub's own signs live here (station dots, the task «!», build arrows, the yard gate and the parking
## sign); the hero, his gun, abilities and E belong to the arena (service_field.tick, actor.gd).
func _physics_process(delta):
	if is_instance_valid(yard_gate):yard_gate.visible="yard" not in Game.built_workshops
	if is_instance_valid(parking_sign):parking_sign.visible="garage" in Game.built_workshops and Game.garage.starting_vehicle()==""
	if phase in ["intro","profiles"]:return
	hint_clock+=delta;hint_refresh-=delta
	if hint_refresh<=0:
		for id in bench_dots:bench_dots[id].visible=bench_available(id)
		if is_instance_valid(barracks_dot):
			# One dot per station (T-179): the printer bench already carries the Barracks dot when it is built.
			barracks_dot.visible=not bench_dots.has("character") and preload("res://scripts/ui/station_notices.gd").has_dot("fighter")
		var build:Button=root.get_node("BuildButton")
		var badge=build.get_node_or_null("Badge")
		if badge==null:badge=UiKit.badge(build,"news")
		badge.visible=Game.research_unlocks.any(func(id):return id in Game.BUILD_COST.keys() and preload("res://scripts/ui/build_catalog.gd").has_news(id))
		hint_refresh=.3
		refresh_command_alert()
		if is_instance_valid(roadmap_alert):
			var roadmap=preload("res://scripts/ui/stations/roadmap_station.gd").new()
			roadmap_alert.visible=not roadmap.unseen_done().is_empty() or not roadmap.unclaimed().is_empty()  # T-148: alloy waiting
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
	if is_instance_valid(barracks_dot) and barracks_dot.visible:barracks_dot.modulate.a=.45+.55*(.5+.5*sin(hint_clock*5.0))
	if is_instance_valid(roadmap_alert) and roadmap_alert.visible:roadmap_alert.position.y=2.05+absf(sin(hint_clock*3.0))*.12
	for arrow in build_arrows.values():
		if is_instance_valid(arrow):arrow.position.y=1.9+(1-cos(hint_clock*TAU/4.8))*.18

## Concrete yard, the range fence (open toward the hangar so vehicles can drive in), a sandbag berm and a
## target board behind the dummy, a lamp post, and the parking sign that shows a tank icon while empty.
## Uniform locker on the old bonus-bench spot by the back wall.
const WARDROBE_POS=Vector3(-3,0,-1)
## «Развитие заставы»: the meta roadmap board by the back wall.
## One cell forward of the back wall so the truss does not hide it (T-088).
const ROADMAP_POS=Vector3(1,0,-1)
func build_roadmap():
	var board=Node3D.new();board.name="Roadmap";add_child(board);board.position=ROADMAP_POS
	var wood=Color("6d5a40");var cork=Color("b89a6a")
	# Layers never share a face (z-fighting on the board, 2026-10-03): posts behind the frame, the frame behind
	# the cork, the red lines and the cards each a few millimetres further forward.
	for x in [-.6,.6]:Visuals.box(board,Vector3(x,.75,-.09),Vector3(.1,1.5,.1),wood.darkened(.25))
	Visuals.box(board,Vector3(0,1.25,.02),Vector3(1.4,.95,.06),cork)
	Visuals.box(board,Vector3(0,1.25,-.02),Vector3(1.5,1.05,.04),wood)
	# Track lines with pinned cards: done cards are pale, the next goal is orange.
	for row in range(3):
		var y=1.55-row*.28
		Visuals.box(board,Vector3(0,y,.062),Vector3(1.2,.02,.01),Color("8a3a2a"))
		for i in range(4):
			var color=Color("e8dcc0") if i<2-row%2 else Color("f2a33a") if i==2-row%2 else Color("9c8f74")
			Visuals.box(board,Vector3(-.45+i*.3,y,.082),Vector3(.18,.14,.01),color)
	Visuals.label3d(board,"Развитие заставы",Vector3(0,2.0,0),Color("dcf6ec"),22)
	# A reached goal not seen yet: an orange «!» hops over the board until the station is opened.
	roadmap_alert=Visuals.label3d(board,"!",Vector3(.62,2.05,0),UiKit.ORANGE,64);roadmap_alert.outline_size=12;roadmap_alert.name="RoadmapAlert"
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Развитие заставы",ROADMAP_POS,1.3,on_foot)
## The way out (author's draft, 2026-10-03): even chevrons on the yellow plate pointing into the gate, and
## the two yellow panels on each pillar become lamps that softly pulse — a game-design «exit is here».
const GATE_POS=Vector3(5,0,-2)
var exit_lamps:Array=[]
func exit_marks():
	var dark=Color("2b2a24")
	for k in range(3):
		var z=GATE_POS.z+.55-k*.42
		for side in [-1.0,1.0]:
			var bar=Visuals.box(self,Vector3(GATE_POS.x+side*.19,.05,z-.05),Vector3(.5,.012,.09),dark)
			bar.rotation.y=-side*deg_to_rad(40);bar.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1.0,1.0]:
		for y in LAMP_HEIGHTS:
			var lamp=Visuals.box(self,Vector3(GATE_POS.x+side*LAMP_X,y,GATE_POS.z+LAMP_Z),Vector3(.3,.07,.02),Color("ffd36a"))
			var mat=StandardMaterial3D.new();mat.albedo_color=Color("ffd36a");mat.emission_enabled=true;mat.emission=Color("ffc04a");mat.emission_energy_multiplier=1.0;lamp.material_override=mat
			lamp.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;exit_lamps.append(mat)
	var glow=OmniLight3D.new();glow.name="ExitGlow";add_child(glow);glow.position=GATE_POS+Vector3(0,.6,.4);glow.light_color=Color("ffc04a");glow.omni_range=2.2;glow.light_energy=.4;glow.shadow_enabled=false
	exit_lamps.append(glow)
	var t=create_tween().set_loops()
	t.tween_method(func(v:float):
		for m in exit_lamps:
			if m is StandardMaterial3D:m.emission_energy_multiplier=.5+v*2.2
			elif is_instance_valid(m):m.light_energy=.15+v*.55
	,0.0,1.0,.9).set_trans(Tween.TRANS_SINE)
	t.tween_method(func(v:float):
		for m in exit_lamps:
			if m is StandardMaterial3D:m.emission_energy_multiplier=.5+v*2.2
			elif is_instance_valid(m):m.light_energy=.15+v*.55
	,1.0,0.0,.9).set_trans(Tween.TRANS_SINE)
const LAMP_X:=.98
const LAMP_Z:=.33
const LAMP_HEIGHTS=[.62,.36]
func build_wardrobe():
	var locker=Node3D.new();locker.name="Wardrobe";add_child(locker);locker.position=WARDROBE_POS
	var olive=Color("59603f");var dark=Color("3f4430")
	Visuals.box(locker,Vector3(0,.95,-.1),Vector3(1.1,1.9,.55),olive,"paint")
	for x in [-.27,.27]:
		Visuals.box(locker,Vector3(x,.95,.19),Vector3(.5,1.78,.03),dark,"paint")
		for i in range(3):Visuals.box(locker,Vector3(x,1.55+i*.07,.21),Vector3(.3,.025,.01),Color("2a2e22"))
		Visuals.box(locker,Vector3(x+(.18 if x<0 else -.18),.95,.22),Vector3(.04,.16,.03),Color("c9cfbe"),"steel")
	# The right door stands open: a uniform on a hanger inside.
	var hanger=Node3D.new();locker.add_child(hanger);hanger.position=Vector3(.62,0,.2)
	Visuals.box(hanger,Vector3(0,1.62,0),Vector3(.3,.03,.03),Color("c9cfbe"),"steel")
	uniform_preview=Visuals.box(hanger,Vector3(0,1.28,0),Vector3(.42,.62,.14),Color("5d6147"))
	Visuals.box(hanger,Vector3(0,.82,0),Vector3(.34,.32,.13),Color("4a5039"))
	Visuals.label3d(locker,"Шкаф",Vector3(0,2.15,0),Color("dcf6ec"),22)
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"Шкаф",WARDROBE_POS,1.3,on_foot)
## The wardrobe changed the uniform: the locker's preview, and the practice hero (rebuilt with the new model).
func refresh_uniform():
	if is_instance_valid(uniform_preview):
		var camo=Skins.camo(Game.skin);uniform_preview.material_override=Visuals.material(camo.get("camo_a",Color("5d6147")))
	sync_practice()
func build_yard():
	var yard=Node3D.new();yard.name="Yard";add_child(yard)
	# A concrete apron flush with the hangar floor (top at y=0), standing on the outside ground.
	Visuals.box(yard,Vector3(16.1,-.42,0),Vector3(13.4,.84,7.4),Color("8d9186"))
	passage(yard)
	range_pen(yard)
	test_track(yard)
	yard_dressing(yard)
	parking_sign=Node3D.new();parking_sign.name="ParkingSign";yard.add_child(parking_sign);parking_sign.position=YARD_PARK+Vector3(.75,0,-.7)
	var post=Color("5b5f57")
	Visuals.box(parking_sign,Vector3(0,.55,0),Vector3(.07,1.1,.07),Color("8a9196"),"steel")
	Visuals.box(parking_sign,Vector3(0,1.15,0),Vector3(.6,.45,.05),Color("2f3b33"))
	var icon=Sprite3D.new();icon.texture=load("res://assets/icons/v1/vehicle.png");  # world sign: plain sprite, not the UI pin
	icon.pixel_size=.4/maxf(1.0,float(icon.texture.get_width()));icon.position=Vector3(0,1.15,.035);parking_sign.add_child(icon)
## Range lane (T-010) along row -2: a painted firing spot at the west end, dashed lane edges, and the target far
## east inside a U of sandbags with a backstop wall. Open on the west so vehicles can drive up to the spot.
func range_pen(yard:Node3D):
	var paint=Color("e8e2d0");var bag=Color("b8a47c")
	# Firing spot: a mat with a chevron and a stencil line across the lane.
	Visuals.box(yard,FIRING_SPOT+Vector3(0,.013,0),Vector3(.9,.012,.9),Color("4f5a45"))
	Visuals.box(yard,FIRING_SPOT+Vector3(.5,.016,0),Vector3(.06,.012,.9),Color("e5b34f"))
	for k in [-1,1]:var chev=Visuals.box(yard,FIRING_SPOT+Vector3(-.05,.018,k*.14),Vector3(.32,.012,.07),Color("e5b34f"));chev.rotation.y=k*.6
	# Dashed lane edges from the spot to the target.
	for i in range(int(YARD_DUMMY.x-FIRING_SPOT.x)*2):
		for z in [-.55,.55]:Visuals.box(yard,Vector3(FIRING_SPOT.x+.8+i*.5,.013,YARD_DUMMY.z+z),Vector3(.25,.01,.05),paint)
	# Sandbag U around the target and a timber backstop behind it.
	for z in [-1.0,1.0]:
		for i in range(3):sandbag_row(yard,Vector3(YARD_DUMMY.x-.6+i*.5,0,YARD_DUMMY.z+z*.75),1)
	for i in range(3):sandbag_row(yard,Vector3(YARD_DUMMY.x+.75,0,YARD_DUMMY.z-.5+i*.5),1)
	Visuals.box(yard,Vector3(YARD_DUMMY.x+1.1,.75,YARD_DUMMY.z),Vector3(.2,1.5,2.2),Color("6d5a40"))
	var board=Visuals.box(yard,Vector3(YARD_DUMMY.x+.95,1.0,YARD_DUMMY.z),Vector3(.06,.75,.75),Color("e8e2d0"));board.rotation.y=PI*.5
	for r in [.28,.17,.07]:
		var ring=MeshInstance3D.new();var disc=CylinderMesh.new();disc.top_radius=r;disc.bottom_radius=r;disc.height=.02;ring.mesh=disc;ring.rotation.z=PI*.5
		ring.position=Vector3(YARD_DUMMY.x+.91-(.3-r)*.02,1.0,YARD_DUMMY.z);ring.material_override=Visuals.material(Color("cf613f") if r!=.17 else Color("e8e2d0"));yard.add_child(ring)
	preload("res://scripts/base_surroundings.gd").lamp(yard,Vector3(YARD_EAST+.6,0,-.6))
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
	for c in TYRE_CELLS:
		var p=Vector3(c.x,0,c.y)
		for i in range(2):
			var tyre=MeshInstance3D.new();var torus=TorusMesh.new();torus.inner_radius=.12;torus.outer_radius=.26;tyre.mesh=torus
			tyre.position=p+Vector3(0,.07+i*.13,0);tyre.material_override=Visuals.material(Color("2a2c2a") if i==0 else Color("cf613f"));yard.add_child(tyre)
## Covered passage from the hangar to the yard along row 0: grating floor with hazard edges, panel walls,
## roof beams with amber lamps and a raised roll-up gate on the hangar side.
func passage(yard:Node3D):
	var steel=Color("848b90");var panel=Color("6f766f")
	Visuals.box(yard,Vector3(9.15,.02,0),Vector3(2.5,.04,1.4),Color("4c514c"))  # decal layers: .04 grating, .05 stripes
	for i in range(9):Visuals.box(yard,Vector3(8.05+i*.28,.045,0),Vector3(.05,.01,1.3),Color("3b3f3b"))
	for z in [-.68,.68]:
		for i in range(10):Visuals.box(yard,Vector3(8.0+i*.25,.05,z),Vector3(.12,.012,.08),Color("e5b34f") if i%2==0 else Color("2f332d"))
		Visuals.box(yard,Vector3(9.25,.8,z*1.4),Vector3(1.9,1.6,.08),panel,"paint")
		for x in [8.3,9.25,10.2]:Visuals.box(yard,Vector3(x,1.1,z*1.4),Vector3(.12,2.2,.12),steel,"steel")
	for x in [8.3,8.95,9.6,10.2]:Visuals.box(yard,Vector3(x,2.22,0),Vector3(.12,.12,2.0),steel,"steel")
	# Open beams, no roof plate: the top-down camera must see who walks through.
	for x in [8.65,9.9]:
		var lamp=Visuals.box(yard,Vector3(x,2.08,0),Vector3(.3,.07,.14),Color("ffcf7a"));lamp.material_override=Visuals.material(Color("ffcf7a"),true)
	var light=OmniLight3D.new();light.light_color=Color("ffcf8a");light.light_energy=.9;light.omni_range=2.6;light.position=Vector3(9.25,1.8,0);yard.add_child(light)
	# Roll-up gate, raised: drum and rails at the hangar end, a beacon on top.
	var drum=MeshInstance3D.new();var cyl=CylinderMesh.new();cyl.top_radius=.16;cyl.bottom_radius=.16;cyl.height=1.9;drum.mesh=cyl;drum.rotation.x=PI*.5
	drum.position=Vector3(8.2,2.0,0);drum.material_override=Visuals.surface_material(Color("8a8f86"),"steel");yard.add_child(drum)
	var beacon=Visuals.box(yard,Vector3(8.2,2.4,.75),Vector3(.14,.14,.14),Color("ffb52c"));beacon.material_override=Visuals.material(Color("ffb52c"),true)
	# Closed gate until the yard is bought: a ribbed shutter with hazard stripes.
	yard_gate=Node3D.new();yard_gate.name="YardGate";yard.add_child(yard_gate);yard_gate.position=Vector3(8.2,0,0)
	Visuals.box(yard_gate,Vector3(0,1.0,0),Vector3(.08,2.0,1.8),Color("7d837b"),"paint")
	for i in range(6):Visuals.box(yard_gate,Vector3(-.05,.3+i*.3,0),Vector3(.02,.05,1.8),Color("8a9196"),"steel")
	for i in range(5):Visuals.box(yard_gate,Vector3(-.05,.12,-.72+i*.36),Vector3(.02,.12,.18),Color("e5b34f"))
	preload("res://scripts/interaction_prompt.gd").attach(self,self,"🔒 Площадка · %d ◈" % Game.YARD_COST,Vector3(7,0,0),1.3,func():return "yard" not in Game.built_workshops and on_foot())
## Around the apron: concrete barriers along the south and east edges, parking lines, a guard booth and a
## flag at the entrance, a container on the ground behind the range.
func yard_dressing(yard:Node3D):
	var block=Color("a2a596")
	# South row low (T-270): the camera looks over it, so a tall block would hide the soldier walking along row 3.
	for x in [11.0,12.3,13.6,14.9,16.2,17.5,18.8,20.1,21.4]:Visuals.box(yard,Vector3(x,.15,3.55),Vector3(1.1,.3,.35),block)
	for z in [.2,1.5,2.8]:Visuals.box(yard,Vector3(YARD_EAST+.65,.25,z),Vector3(.35,.5,1.1),block)
	for dx in [-.55,.55]:Visuals.box(yard,YARD_PARK+Vector3(dx,.012,0),Vector3(.06,.012,1.5),Color("e8e2d0"))
	Visuals.box(yard,YARD_PARK+Vector3(0,.012,.72),Vector3(1.16,.012,.06),Color("e8e2d0"))
	var booth=Node3D.new();yard.add_child(booth);booth.position=Vector3(BOOTH_CELL.x,0,BOOTH_CELL.y)
	Visuals.box(booth,Vector3(0,.7,0),Vector3(.9,1.4,.8),Color("59603f"))
	Visuals.box(booth,Vector3(0,1.46,0),Vector3(1.05,.1,.95),Color("454a33"))
	var window=Visuals.box(booth,Vector3(.46,.95,0),Vector3(.02,.35,.5),Color("9fd4ff"));window.material_override=Visuals.material(Color("9fd4ff"),true)
	var flag=Node3D.new();yard.add_child(flag);flag.position=Vector3(10.2,0,-3.1);flag.scale=Vector3.ONE*.55;ExitFlag.build(flag)
	# The old container now stands outside the apron, behind the range backstop.
	var container=Visuals.box(self,Vector3(YARD_EAST+2.2,-.72+.65,-1.6),Vector3(1.3,1.3,2.8),Color("7a4a33"))
	for i in range(6):Visuals.box(self,Vector3(YARD_EAST+1.53,-.72+.65,-2.8+i*.48),Vector3(.02,1.2,.08),Color("5f3a28"))
func sandbag_row(parent:Node3D,center:Vector3,count:int):
	for i in range(count):Visuals.box(parent,center+Vector3((i-(count-1)*.5)*.46,.14+(i%2)*.02,0),Vector3(.44,.26,.3),Color("b8a47c"))

## The hub on the arena grid. The hub spans x −5…23 (hangar, passage, yard), so the square field is 47 cells with
## the hub's own world coordinates (arena.world_pos(cell) = hub position); only the cells along the edge of the
## walkable floor become walls (solid_cells), the rest of the square is never reached.
const FIELD:=47
func field_size()->int:return FIELD
## The walkable floor (the old hub_free): the hangar x −4…7, z −2…4 without the props, the rack gap on row 0 and
## the yard x 10…YARD_EAST, z −3…3 without the target pen, the booth, the tyres and the terminal, once the yard
## is built. The range dummy and the parked vehicle are actors and block by themselves.
func walkable(p:Vector2i)->bool:
	if p in [Vector2i(-2,3),Vector2i(3,3),Vector2i(6,3)]:return false
	if p.x>7:
		if "yard" not in Game.built_workshops:return false
		# Yard: the rack gap (x 8-9 only on row 0), then open concrete x 10..YARD_EAST, y -3..3 except the target pen and booth.
		if p.x<=9:return p.y==0
		var d=Vector2i(roundi(YARD_DUMMY.x),roundi(YARD_DUMMY.z))
		return p.x<=YARD_EAST and p.y>=-3 and p.y<=3 and p not in [d+Vector2i(0,-1),d+Vector2i(0,1),d+Vector2i(1,0)] and p!=BOOTH_CELL and p not in TYRE_CELLS and p!=Vector2i(roundi(GARAGE_TERMINAL.x),roundi(GARAGE_TERMINAL.z))
	if p.x< -4 or p.y< -2 or p.y>4:return false
	# Command centre (left edge), crates by the back wall, the range pad and the arsenal spot. The retired
	# workbench cells (character at 0,-1 and bonuses at -3,-1) are walkable floor now.
	if p in [Vector2i(-4,0),Vector2i(-4,1),Vector2i(-4,2),Vector2i(0,3),Vector2i(-2,-2),Vector2i(-1,-2),Vector2i(-3,-1),Vector2i(1,-1)]:return false
	return true
## Walls only where the floor ends (every non-walkable cell touching a walkable one): collision, bullets, blasts
## and the laser stop there exactly as on a battle field. ~150 cells instead of the whole 47×47 square.
func solid_cells()->Array:
	var result=[]
	for x in range(-6,YARD_EAST+3):
		for z in range(-5,7):
			var c=Vector2i(x,z)
			if walkable(c):continue
			for dx in [-1,0,1]:
				for dz in [-1,0,1]:
					if (dx!=0 or dz!=0) and walkable(c+Vector2i(dx,dz)):result.append(c);break
				if not result.is_empty() and result.back()==c:break
	return result
func start_position()->Vector3:return Vector3(2,0,2)

## E on the hub field (the arena's dispatcher calls it): a dropped item's card first, then the stations on foot,
## then the vehicles (VehicleSystem: board the parked one, leave the one driven), then the gate.
func interact():
	if phase=="intro" or not is_instance_valid(avatar):return
	if preload("res://scripts/ui/drop_prompt.gd").engaged(self):return
	if window_open():return
	var at:Vector3=avatar.position
	if on_foot():
		if at.distance_to(recycling_pos)<1.3:show_recycling();return
		if at.distance_to(hq_bench_pos)<1.2:open_station("hq");return
		if at.distance_to(command_pos)<1.65:show_command();return
		if at.distance_to(printer_pos)<1.4:open_station("fighter");return
		if at.distance_to(WARDROBE_POS)<1.3:open_station("wardrobe");return
		if at.distance_to(ROADMAP_POS)<1.3:open_station("roadmap");return
		# T-014: the motor pool station opens from its terminal beside the bay; the parked vehicle boards with E.
		if "garage" in Game.built_workshops and at.distance_to(GARAGE_TERMINAL)<1.2:open_station("garage");return
		var locked=nearest_locked()
		if locked!="":build_tab=1 if locked in ["garage","range"] else 0;show_build_menu();return
		if "yard" not in Game.built_workshops and at.distance_to(Vector3(7,0,0))<1.3:show_build_menu();return
		if at.distance_to(weapon_bench_pos)<1.25:open_station("arsenal");return
	if riding() or arena.nearest_wreck()!=null:arena.vehicle.interact_vehicle();return
	if on_foot() and at.distance_to(Vector3(5,0,-2))<2.2:launch()

func launch():
	if phase=="intro":return
	if exit_queued:return
	if is_instance_valid(build_menu):return
	exit_queued=true
	Game.reset_input()
	start_requested.emit()

func close_station():
	# Dots follow the items (0.8.0): leaving a station does not clear them, selecting the last new item does.
	if is_instance_valid(build_menu):build_menu.get_parent().remove_child(build_menu);build_menu.queue_free();build_menu=null
	phase="combat";Game.reset_input();start_button.disabled=false
	sync_practice()
	call_deferred("present_unlock")
func close_window():close_station()
## The field holds while the hub shows anything over it (a station, a dialog, a call, the profiles).
func window_open()->bool:return phase!="combat" or super()

## Soft contact shadows under hub props («Глубина света»), rebuilt when stations change.
func refresh_floor_ao():
	var old=get_node_or_null("FloorAO")
	if old:old.name="FloorAOOld";old.queue_free()
	preload("res://scripts/systems/floor_ao.gd").build_props(self,[command_beams,get_node_or_null("HubOutskirts")])
func update_bench_visuals():
	hint_refresh=0
	if not is_instance_valid(bench_visuals) or bench_signature!=Game.built_workshops:
		bench_signature=Game.built_workshops.duplicate()
		refresh_floor_ao.call_deferred()
		sync_field.call_deferred()
		build_arrows.clear();bench_dots.clear()
		if is_instance_valid(bench_visuals):remove_child(bench_visuals);bench_visuals.queue_free()
		bench_visuals=Node3D.new();add_child(bench_visuals)
		for id in Game.BUILD_COST:
			var pos={"headquarters":hq_bench_pos,"character":Vector3(0,0,-1),"weapons":weapon_bench_pos,"bonuses":bonus_bench_pos,"garage":YARD_PARK,"range":YARD_DUMMY}[id]
			if id not in Game.built_workshops:
				# A soft round marker instead of a sharp triangle (T-052): a light disc with a small chevron.
				var arrow=Visuals.label3d(bench_visuals,"⌄",pos+Vector3.UP*1.55,Color("fff3c8"),64);arrow.modulate.a=.95;arrow.outline_size=0
				var disc=Visuals.label3d(arrow,"●",Vector3(0,.02,-.01),UiKit.NOTICE.goal,96);disc.modulate.a=.55;disc.outline_size=0;disc.no_depth_test=true
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
func show_build_menu():preload("res://scripts/ui/build_menu.gd").show(self)

## The four stations share one screen (scripts/ui/station_screen.gd); only «Казарма» needs no building.
const STATIONS={"roadmap":["","res://scripts/ui/stations/roadmap_station.gd"],"wardrobe":["","res://scripts/ui/stations/wardrobe_station.gd"],"fighter":["","res://scripts/ui/stations/fighter_station.gd"],"arsenal":["weapons","res://scripts/ui/stations/arsenal_station.gd"],"hq":["headquarters","res://scripts/ui/stations/hq_station.gd"],"garage":["garage","res://scripts/ui/stations/garage_station.gd"]}
func open_station(kind:String):
	var building=STATIONS[kind][0]
	if building!="" and building not in Game.built_workshops:build_tab=0;show_build_menu();return
	if building!="":preload("res://scripts/ui/build_catalog.gd").mark(building)
	close_station();phase="workshop";Game.reset_input();start_button.disabled=true
	var screen=preload("res://scripts/ui/station_screen.gd").new();screen.name="Station_"+kind;screen.provider=load(STATIONS[kind][1]).new();screen.station_kind=kind
	build_menu=screen;root.add_child(screen);screen.closed.connect(close_station);screen.changed.connect(refresh)
	if kind=="wardrobe":screen.changed.connect(refresh_uniform)
	if kind=="roadmap":
		screen.provider.mark_seen()
		if is_instance_valid(roadmap_alert):roadmap_alert.hide()

func nearest_locked() -> String:
	if not on_foot():return ""
	for id in Game.BUILD_COST:
		var pos={"headquarters":hq_bench_pos,"character":Vector3(0,0,-1),"weapons":weapon_bench_pos,"bonuses":bonus_bench_pos,"garage":YARD_PARK,"range":YARD_DUMMY}[id]
		if id not in Game.built_workshops and avatar.position.distance_to(pos)<1.25:return id
	return ""

## A bench dot is seen-aware: it lights up when something new became affordable or unlocked since the
## station was last opened (scripts/ui/station_notices.gd), not whenever money is enough for anything.
func bench_available(id:String)->bool:
	var notices=preload("res://scripts/ui/station_notices.gd")
	return id in notices.BENCHES and notices.has_dot(notices.BENCHES[id])


## Dev «reset profile» (recipe shop): wipe upgrades; the practice hero is rebuilt where he stands.
func reset_upgrades():
	Game.reset_upgrades()
	update_bench_visuals();close_station()
	Texts.set_text(status,"Профиль обнулён.")
	refresh()
func show_recipe_shop():
	close_station();phase="workshop";start_button.disabled=true
	build_menu=load("res://scripts/garage/recipe_shop.gd").new();root.add_child(build_menu)
	build_menu.closed.connect(close_station);build_menu.changed.connect(refresh);build_menu.reset_requested.connect(reset_upgrades)


func show_command():
	close_station();phase="workshop";start_button.disabled=true
	build_menu=preload("res://scenes/progression/command_screen.tscn").instantiate();root.add_child(build_menu);build_menu.closed.connect(close_station)

func present_unlock():
	if not is_inside_tree() or is_queued_for_deletion():return
	if Game.new_recipes.is_empty() or phase!="combat" or is_instance_valid(build_menu):return
	var recipe=Game.new_recipes.pop_front();phase="workshop"
	build_menu=Control.new();root.add_child(build_menu);build_menu.add_to_group("selection_scope");build_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade=ColorRect.new();build_menu.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.55)
	var panel=UiKit.panel(build_menu,(get_viewport().get_visible_rect().size-Vector2(680,390))*.5,Vector2(680,390))
	UiKit.accent(UiKit.label(panel,"Новое открытие",Vector2(25,25),Vector2(630,40),29))
	# A building blueprint shows the same clipboard as in the backpack (T-223); other finds show the item itself.
	UiKit.icon(panel,recipe.id if recipe.category!="research" else preload("res://scripts/ui/item_info.gd").blueprint_key(recipe),Vector2(25,90),Vector2(120,120))
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

func show_recycling():
	close_station();phase="workshop";Game.reset_input()
	build_menu=preload("res://scripts/ui/recycling_station.gd").build(self);root.add_child(build_menu)

func show_arrival():
	if arrival_reason=="":phase="combat";present_call();return
	phase="intro"
	var dialog=preload("res://scripts/ui/arrival_dialog.gd").new();dialog.reason=arrival_reason;arrival_reason=""
	root.add_child(dialog)
	dialog.closed.connect(func():
		phase="combat";Game.reset_input();call_deferred("present_call"))

## Tutorial video call from HQ (once per trigger), then pending unlock cards.
func present_call():
	if not is_inside_tree() or is_queued_for_deletion():return
	var VideoCall=preload("res://scripts/ui/video_call.gd")
	var call=VideoCall.due(self)
	if call=="" or phase!="combat" or Engine.get_meta("hub_calls_off",false):present_unlock();return
	# The call rings in the corner; the player answers when ready, nothing is blocked meanwhile.
	if root.has_node("IncomingCall"):return
	# The call opens as a dialog (T-120) and holds the hub until «Взять» or «Позже».
	phase="ringing"
	var ring=preload("res://scripts/ui/incoming_call.gd").new();ring.call_id=call;root.add_child(ring)
	ring.answered.connect(func():
		if phase=="ringing":phase="combat"
		open_call(call,ring.answered_rect))
	ring.postponed.connect(func():phase="combat";Game.reset_input();present_unlock())
	present_unlock()
func open_call(call:String,from_rect:=Rect2()):
	# Answered while an unlock card is open: the call starts right after it.
	while is_inside_tree() and phase!="combat":await get_tree().process_frame
	if not is_inside_tree():return
	phase="intro"
	var view=preload("res://scripts/ui/video_call.gd").new();view.id=call;view.from_rect=from_rect;root.add_child(view)
	view.closed.connect(func():
		phase="combat";Game.reset_input())

## Esc (T-189): the topmost open window closes first — windows that handle Esc themselves get it before the hub
## (they are deeper in the tree); a station without its own handler is closed here. With nothing open the event
## goes on to the arena (the hub's parent), whose pause opens the tablet over the practice run — as in battle.
func _unhandled_input(event):
	if not event.is_action_pressed("pause") or event.is_echo():return
	if is_instance_valid(build_menu):get_viewport().set_input_as_handled();close_station();return
	for node in get_tree().get_nodes_in_group("selection_scope"):
		if node is CanvasItem and node.is_visible_in_tree() and is_ancestor_of(node):get_viewport().set_input_as_handled();return
	if phase!="combat":get_viewport().set_input_as_handled()
## The rooms' Esc poll (playground.gd) is not used here: the hub answers Esc in _unhandled_input above.
func _process(_delta):pass
