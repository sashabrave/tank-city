extends Node3D
signal enter_requested(index:int)
signal route_selected(index:int,node_id:String)
signal service_requested(branch:String,index:int)
signal test_requested(target:int,replay_rewards:bool)
signal dev_requested(target:int,progress:bool,node_id:String)
var run_context
var modal:Control
var pending_info:Dictionary={}
var pending_service=""
var preview_only=false
var return_position:Vector3
var return_scroll=0.0
var return_size=28.0
var pause_over_entry=false
var showing_pause=false
signal hub_requested
const MINI=preload("res://scripts/route_miniatures.gd")
var path_keys={}
var service_nodes:Array=[]
const PREVIEW=preload("res://scripts/room_wave_preview.gd")
var available=0
var wave_seed=-1
var hero_kind="soldier"
var hero_weapon=""
var route_choices:Dictionary={}
var plan:Array=[]
var reachable:Array=[]
var wave_rosters:Array=[]
var node_rosters:Dictionary={}
var room_previews:Array=[]
var previews:Dictionary={}
var needs_service=false
var ability_available=false
var camera:Camera3D
var root:Control
var scroll=0.0
var dragging=false
var drag_distance=0.0
var travelling=false
const MINI_SCALE=0.52
## The start pad sits one regular step before the first stage; the hero model is 1.5× smaller than before.
const START_POINT=Vector3(0,0,RoutePlan.STAGE_STEP)
const HERO_SCALE=2.8/1.5
var start_pad:Node3D
var player_marker:Node3D
var foreground_hangar:Node3D
var travel_tween:Tween
var intro_tween:Tween
var fork_positions={}
var service_choices:Array=[]
var selection_index=0
var selection_ring:Node3D
func stage_z(stage:int)->float:
	var camps=Campaign.SERVICES.filter(func(i):return i<=stage).size()
	return -(stage+camps)*RoutePlan.STAGE_STEP
func room_point(info:Dictionary,count:int)->Vector3:
	var point=RoutePlan.point(info,count);point.z=stage_z(info.stage);return point
func path_line(a:Vector3,b:Vector3):
	var key=str(a)+str(b)
	if path_keys.has(key):return
	path_keys[key]=true
	var road=Node3D.new();road.name="RouteRoad";add_child(road)
	road.position=(a+b)*.5;road.rotation.y=atan2(b.x-a.x,b.z-a.z)
	var length=a.distance_to(b)
	Visuals.box(road,Vector3(0,-.42,0),Vector3(1.28,.035,length),Color("827c69"))
	Visuals.box(road,Vector3(0,-.395,0),Vector3(1.05,.025,length),Color("626655"))
	for side in [-1,1]:Visuals.box(road,Vector3(side*.32,-.375,0),Vector3(.12,.014,length),Color("4c5247"))

func selection_point()->Vector3:
	return fork_positions[service_choices[selection_index%service_choices.size()]] if needs_service else previews[reachable[selection_index%reachable.size()]].position
func update_selection():
	if not is_instance_valid(selection_ring):return
	selection_ring.position=selection_point()+Vector3.UP*.12
	scroll=maxf(0,-(selection_point().z+current_point().z)*.5);move_camera()
func _ready():
	add_to_group("notification_context")
	Game.music_context("map")
	if wave_seed<0:wave_seed=Game.visual_run_seed
	if hero_weapon=="":hero_weapon=Game.selected_weapon
	plan=RoutePlan.build(wave_seed);reachable=RoutePlan.reachable(plan,available,route_choices)
	camera=Visuals.setup_world(self,28,Vector3.ZERO)
	get_node("WorldAtmosphere").anchor_to_map(-stage_z(plan.size()-1))
	preload("res://scripts/base_surroundings.gd").route(self,-stage_z(plan.size()-1))
	Visuals.box(self,Vector3(0,-.55,stage_z(plan.size()-1)*.5),Vector3(23,.2,-stage_z(plan.size()-1)+35),Color("8c918c"))
	for stage in range(plan.size()):
		wave_rosters.append(PREVIEW.waves(wave_seed,stage))
		for info in plan[stage]:
			node_rosters[info.id]=PREVIEW.waves(wave_seed,stage,info.difficulty,info.id)
			var pos=room_point(info,plan[stage].size())
			for next_id in info.next:
				var target=plan[stage+1].filter(func(n):return n.id==next_id)[0]
				var end=room_point(target,plan[stage+1].size())
				if stage+1 in Campaign.SERVICES:
					var side=-1 if (pos.x+end.x)*.5<=0 else 1
					var camp=Vector3(side*3.25,0,stage_z(stage+1)+RoutePlan.STAGE_STEP)
					path_line(pos,camp);path_line(camp,end)
				else:path_line(pos,end)
			var node=Node3D.new();add_child(node);node.position=pos;node.scale=Vector3.ONE*MINI_SCALE;previews[info.id]=node
			node.set_meta("info",info)
			if info.lane==0:room_previews.append(node)
			var biome=LocationStyle.biome(wave_seed,stage)
			var visited=stage<available and RoutePlan.chosen(plan,stage,route_choices).id==info.id
			var skipped=stage<available and not visited
			var color=LocationStyle.COLORS[biome]
			if skipped:color=color.darkened(.28)
			var branch=RoutePlan.node_branch(info)
			if branch=="headquarters":MINI.headquarters(node)
			elif branch=="vehicle":MINI.service(node,true,Color("839c9f").darkened(.28 if skipped else 0.0))
			else:MINI.battle(node,posmod(wave_seed+stage+info.lane,4),color,visited)
			var caption={"vehicle":"Техника","headquarters":"Штаб"}.get(branch,"%02d" % (stage+1))
			Visuals.label3d(node,"✓ "+caption if visited else caption,Vector3(0,.35,3.65),Color("f3eee0"),30).pixel_size=.025
			if not visited and not skipped and branch=="":
				for badge in range(info.difficulty):MINI.star(node,info.difficulty,badge)
			if stage==available and info.id in reachable and not needs_service:MINI.border(node,Color("c6cfbc"))
	for service_stage in Campaign.SERVICES:
		var choices=Campaign.service_options(wave_seed,service_stage)
		for i in range(choices.size()):
			var branch=choices[i];var pos=Vector3((i-(choices.size()-1)*.5)*6.5,0,stage_z(service_stage)+RoutePlan.STAGE_STEP)
			var base=Node3D.new();add_child(base);base.position=pos;base.scale=Vector3.ONE*MINI_SCALE;service_nodes.append(base)
			if branch=="headquarters":MINI.headquarters(base)
			else:MINI.service(base,branch=="vehicle",Color("839c9f") if branch=="vehicle" else Color("a99b79"))
			Visuals.label3d(base,{"vehicle":"Техника","ability":"Способность","headquarters":"Штаб"}[branch],Vector3(0,.35,3.65),Color("f3eee0"),30).pixel_size=.025
			if service_stage==available:fork_positions[branch]=pos;service_choices.append(branch)

	build_ui()
	player_marker=Node3D.new();player_marker.scale=Vector3.ONE*MINI_SCALE;player_marker.name="PlayerMarker";add_child(player_marker)
	var hero=Visuals.model("base",player_marker);hero.name="CurrentHero"
	hero.rotation.y=PI;hero.scale=Vector3.ONE*HERO_SCALE
	Visuals.ring(player_marker,Color("f3b95f"),2.0/1.5)
	player_marker.position=current_point()+Vector3(0,.17,2)*MINI_SCALE
	foreground_hangar=preload("res://scripts/route_foreground.gd").new();add_child(foreground_hangar)
	for info in plan[0]:path_line(START_POINT,previews[info.id].position)
	start_pad=Node3D.new();start_pad.name="StartPad";add_child(start_pad);start_pad.position=START_POINT;start_pad.scale=Vector3.ONE*MINI_SCALE
	MINI.start(start_pad);Visuals.label3d(start_pad,"Старт",Vector3(0,.35,3.65),Color("f3eee0"),30).pixel_size=.025
	selection_ring=Node3D.new();add_child(selection_ring);selection_ring.scale=Vector3.ONE*MINI_SCALE;MINI.border(selection_ring,Color("ffb52c"),needs_service)
	scroll=maxf(0,-stage_z(available)-7);move_camera();update_selection()
	intro_tween=create_tween();camera.size=31;intro_tween.tween_property(camera,"size",28.0,.65).set_trans(Tween.TRANS_SINE)
	if available==0:
		travelling=true
		var exit_position=player_marker.position;player_marker.position=START_POINT+Vector3(0,.136,4.7)
		intro_tween.parallel().tween_property(player_marker,"position",exit_position,1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		intro_tween.chain().tween_callback(func():travelling=false)
func current_point()->Vector3:
	if is_instance_valid(run_context) and run_context.visited_services.has(available):
		var branch=run_context.visited_services[available]
		if branch in fork_positions:return fork_positions[branch]
	if available==0:return START_POINT
	return room_point(RoutePlan.chosen(plan,available-1,route_choices),plan[available-1].size())
func build_ui():
	var canvas=CanvasLayer.new();add_child(canvas);root=Control.new();canvas.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var heading_plate=UiKit.panel(root,Vector2(25,20),Vector2(475,120),Color("242d27ed"));heading_plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var legend_plate=UiKit.panel(root,Vector2(25,238),Vector2(360,115),Color("242d27ed"));legend_plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UiKit.label(root,"Бесконечный / сектор %d" % (Campaign.cycle+1) if Campaign.endless else "Мир %d / %s" % [Campaign.world,Campaign.WORLDS[Campaign.world].name],Vector2(35,25),Vector2(670,65),29)
	UiKit.label(root,"WASD — выбор · E — перейти",Vector2(35,95),Vector2(580,40),18)
	UiKit.button(root,"Вернуться в хаб",Vector2(35,155),Vector2(260,58),func():hub_requested.emit())
	UiKit.label(root,"Без ★ — простая\n★ Средняя · частые чертежи\n★★ Сложная · редкие чертежи",Vector2(35,245),Vector2(540,110),19,UiKit.MUTED)
	UiKit.button(root,"Рюкзак / статы [Esc]",Vector2(35,365),Vector2(320,52),show_pause)
	UiKit.button(root,"К текущему пути",Vector2(35,430),Vector2(260,48),update_selection)
	UiKit.button(root,"unlock-dev",Vector2(35,490),Vector2(140,32),func():Game.progression.cleared_worlds=[1,2,3];Game.save_progress()).add_theme_font_size_override("font_size",13)
	var size=get_viewport().get_visible_rect().size
	if needs_service:
		UiKit.label(root,"Сначала выбери передышку",Vector2(size.x/2-250,size.y-155),Vector2(500,40),25)
		for i in range(service_choices.size()):
			var branch=service_choices[i]
			UiKit.button(root,{"vehicle":"Техника","ability":"Способность","headquarters":"Штаб"}[branch],Vector2(size.x/2-330+i*350,size.y-100),Vector2(310,65),func():choose_service(branch),i==0)
	else:
		var hint_plate=UiKit.panel(root,Vector2(size.x-535,size.y-93),Vector2(515,58),Color("242d27ed"));hint_plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
		UiKit.label(root,"WASD — выбор поля боя · E — войти",Vector2(size.x-520,size.y-90),Vector2(500,55),22)
func choose_service(branch:String):
	if travelling or is_instance_valid(modal) or not needs_service or branch not in fork_positions:return
	pending_service=branch;pending_info={};preview_only=false
	return_position=player_marker.position;return_scroll=scroll;return_size=camera.size
	Game.sound("route_select",Game);travelling=true;selection_ring.hide()
	var target=fork_positions[branch]+Vector3(0,.17,2)*MINI_SCALE
	player_marker.get_node("CurrentHero").rotation.y=PI
	player_marker.rotation.y=atan2(-(target.x-player_marker.position.x),-(target.z-player_marker.position.z))
	if intro_tween and intro_tween.is_valid():intro_tween.kill()
	var tween=create_tween().set_parallel(true)
	tween.tween_property(player_marker,"position",target,.45).set_trans(Tween.TRANS_SINE)
	tween.tween_method(func(value):scroll=value;move_camera(),scroll,-target.z,.45)
	tween.tween_property(camera,"size",25.0,.45)
	tween.chain().tween_callback(func():travelling=false;modal=preload("res://scripts/route_service_dialog.gd").build(self,branch))
func confirm_service():
	if travelling or not needs_service or pending_service not in fork_positions:return
	var branch=pending_service;travelling=true;close_dialog();service_requested.emit(branch,available)
func move_camera():
	scroll=clampf(scroll,0,-stage_z(plan.size()-1))
	for id in previews:
		previews[id].visible=absf(previews[id].position.z+scroll)<30
	for node in service_nodes:node.visible=absf(node.position.z+scroll)<30
	var focus=Vector3(0,0,-scroll)
	camera.position=focus+Vector3(0,19,14).rotated(Vector3.UP,deg_to_rad(10));camera.look_at(focus)
func travel_to_room(index:int,node_id:String=""):
	if travelling or is_instance_valid(modal):return
	if node_id=="":
		if index!=available or needs_service:return
		node_id=reachable[0]
	if node_id not in previews:return
	pending_service=""
	pending_info=previews[node_id].get_meta("info")
	return_position=player_marker.position;return_scroll=scroll;return_size=camera.size
	preview_only=index!=available or node_id not in reachable or needs_service
	if preview_only:
		modal=node_dialog(pending_info,cancel_entry);return
	Game.sound("route_select",Game)
	travelling=true;selection_ring.hide()
	if intro_tween and intro_tween.is_valid():intro_tween.kill()
	var hero=player_marker.get_node("CurrentHero")
	if hero.has_method("equip_weapon"):hero.preview_moving=true
	var target=previews[node_id].position+Vector3(0,.17,2)*MINI_SCALE
	player_marker.get_node("CurrentHero").rotation.y=PI
	player_marker.rotation.y=atan2(-(target.x-player_marker.position.x),-(target.z-player_marker.position.z))
	travel_tween=create_tween().set_parallel(true)
	travel_tween.tween_property(player_marker,"position",target,.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	travel_tween.tween_method(func(value):scroll=value;move_camera(),scroll,-target.z,.85)
	travel_tween.tween_property(camera,"size",24.0,.85)
	travel_tween.chain().tween_callback(func():
		if hero.has_method("equip_weapon"):hero.preview_moving=false
		travelling=false;modal=node_dialog(pending_info,confirm_entry))
## Battle nodes show the wave preview; service nodes show the service description.
func node_dialog(info:Dictionary,confirm:Callable)->Control:
	var branch=RoutePlan.node_branch(info)
	if branch!="":return preload("res://scripts/route_service_dialog.gd").build(self,branch,confirm)
	return preload("res://scripts/route_room_dialog.gd").build(self,info)
func close_dialog():
	if is_instance_valid(modal):remove_modal(modal)
	modal=null
func remove_modal(control:Control):
	control.get_parent().remove_child(control);control.queue_free()
func confirm_entry():
	if travelling or pending_info.is_empty() or needs_service or pending_info.id not in reachable or pending_info.stage!=available:return
	Game.sound("route_enter",Game)
	fade_entry(false,false)
func dev_entry(progress:bool):
	if travelling or pending_info.is_empty():return
	fade_entry(true,progress)
func fade_entry(dev:bool,progress:bool):
	travelling=true;close_dialog()
	var shade=ColorRect.new();root.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,0)
	var tween=create_tween().set_parallel(true)
	tween.tween_property(shade,"color:a",1.0,.35)
	tween.tween_property(camera,"size",18.0,.35)
	tween.tween_property(camera,"position:y",camera.position.y-3,.35)
	tween.chain().tween_callback(func():
		if dev:dev_requested.emit(pending_info.stage,progress,pending_info.id)
		else:route_selected.emit(available,pending_info.id);enter_requested.emit(available))
func cancel_entry():
	Game.sound("route_cancel",Game)
	if travelling:return
	close_dialog()
	if preview_only:
		pending_info={};pending_service="";preview_only=false;selection_ring.show();return
	travelling=true
	var tween=create_tween().set_parallel(true)
	tween.tween_property(player_marker,"position",return_position,.55).set_trans(Tween.TRANS_SINE)
	tween.tween_method(func(value):scroll=value;move_camera(),scroll,return_scroll,.55)
	tween.tween_property(camera,"size",return_size,.55)
	tween.chain().tween_callback(func():travelling=false;pending_info={};pending_service="";selection_ring.show())
func show_pause():
	if travelling:return
	showing_pause=true;pause_over_entry=not pending_info.is_empty() or pending_service!=""
	close_dialog()
	preload("res://scripts/ui/pause_tablet.gd").open(self,resume_map,func():hub_requested.emit())

func resume_map():
	close_dialog();showing_pause=false
	if pause_over_entry:modal=preload("res://scripts/route_service_dialog.gd").build(self,pending_service) if pending_service!="" else preload("res://scripts/route_room_dialog.gd").build(self,pending_info)
	pause_over_entry=false
func tap_at(screen_pos:Vector2):
	if travelling or is_instance_valid(modal):return
	var point=Plane(Vector3.UP,.17).intersects_ray(camera.project_ray_origin(screen_pos),camera.project_ray_normal(screen_pos))
	if point==null:return
	if needs_service:
		for branch in fork_positions:
			var delta=point-fork_positions[branch]
			if absf(delta.x)<=3.15*MINI_SCALE and absf(delta.z)<=3.15*MINI_SCALE:choose_service(branch);return
	for id in previews:
		if not previews[id].visible:continue
		var delta=point-previews[id].position
		if absf(delta.x)<=3.15*MINI_SCALE and absf(delta.z)<=3.15*MINI_SCALE:travel_to_room(previews[id].get_meta("info").stage,id);return
func _unhandled_input(event):
	if travelling:return
	if event.is_action_pressed("pause"):
		if is_instance_valid(modal):
			if showing_pause:resume_map()
			elif not pending_info.is_empty() or pending_service!="":cancel_entry()
			else:resume_map()
		else:show_pause()
		get_viewport().set_input_as_handled();return
	if is_instance_valid(modal):return
	if event.is_pressed() and not event.is_echo():
		var step=0
		if event.is_action("east") or event.is_action("south"):step=1
		if event.is_action("west") or event.is_action("north"):step=-1
		if step!=0:
			selection_index=clampi(selection_index+step,0,(service_choices.size() if needs_service else reachable.size())-1);update_selection();get_viewport().set_input_as_handled();return
		if event.is_action("interact"):
			get_viewport().set_input_as_handled()
			if needs_service:choose_service(service_choices[selection_index%service_choices.size()])
			else:travel_to_room(available,reachable[selection_index%reachable.size()])
			return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			dragging=event.pressed
			if event.pressed:drag_distance=0
			elif drag_distance<8:tap_at(event.position)
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:scroll+=2;move_camera()
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:scroll-=2;move_camera()
	if event is InputEventMouseMotion and dragging:
		drag_distance+=event.relative.length();scroll+=event.relative.y*.04;move_camera()
	if event is InputEventScreenTouch:
		if event.pressed:drag_distance=0
		elif drag_distance<8:tap_at(event.position)
	if event is InputEventScreenDrag:
		drag_distance+=event.relative.length();scroll+=event.relative.y*.04;move_camera()

func _process(_delta):
	if is_instance_valid(foreground_hangar) and is_instance_valid(camera):
		foreground_hangar.follow_camera(scroll,camera.size)
