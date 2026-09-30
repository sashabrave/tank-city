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
## Driving: the player steers the HQ car; it stays on the roads that lead to this stage's choices.
const ROAD_HALF=.62
const CARD_RADIUS=2.5    # the node card shows up
const ENTER_RADIUS=3.1   # E works a little before the card, so it can be pressed early
const DRIVE_SPEED=6.5
var road_paths:Array=[]
var open_roads:Array=[]
var drive_velocity=Vector3.ZERO
var follow_camera=true
var node_card:Control
var card_key=""
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
	# Smooth S-curve: the road leaves and enters each node along the map axis.
	var bend=(b.z-a.z)*.5;var points=[]
	for i in range(21):
		var t=i/20.0;var u=1.0-t
		points.append(a*u*u*u+(a+Vector3(0,0,bend))*3*u*u*t+(b-Vector3(0,0,bend))*3*u*t*t+b*t*t*t)
	road.add_child(ribbon(points,2.05,-.43,Color("8f8a74")))
	road.add_child(ribbon(points,1.45,-.41,Color("6b6e5c")))
	road_paths.append({"a":a,"b":b,"points":points,"node":road})
func ribbon(points:Array,width:float,height:float,color:Color)->MeshInstance3D:
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left=[];var right=[]
	for i in range(points.size()):
		var tangent=(points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var side=Vector3(-tangent.z,0,tangent.x)*width*.5
		left.append(points[i]+side+Vector3.UP*height);right.append(points[i]-side+Vector3.UP*height)
	for i in range(points.size()-1):
		for p in [left[i],right[i],right[i+1],left[i],right[i+1],left[i+1]]:surface.set_normal(Vector3.UP);surface.add_vertex(p)
	var mesh=MeshInstance3D.new();mesh.mesh=surface.commit();mesh.material_override=Visuals.material(color)
	mesh.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh

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
	var visited_branch=run_context.visited_services.get(available,"") if is_instance_valid(run_context) else ""
	plan=RoutePlan.build(wave_seed);reachable=RoutePlan.reachable(plan,available,route_choices,visited_branch)
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
				if stage+1 in Campaign.SERVICES and RoutePlan.service_roads():pass
				elif stage+1 in Campaign.SERVICES:
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
			if branch=="headquarters":MINI.depot(node)
			elif branch=="vehicle":MINI.service(node,true,Color("839c9f").darkened(.28 if skipped else 0.0))
			elif info.type in RoutePlan.CHALLENGES:MINI.challenge(node,info.type,color)
			elif stage in Campaign.BOSSES:MINI.boss(node,color)
			else:MINI.battle(node,posmod(wave_seed+stage*3+info.lane*7,4),color,visited,info.difficulty)
			if branch=="" and not skipped:MINI.weather(node,MINI.weather_for(preload("res://scripts/biome_catalog.gd").entry(wave_seed,stage)))
			var caption={"vehicle":"Техника","headquarters":"Депо"}.get(branch,ChallengeRooms.TITLES.get(info.type,"%02d" % (stage+1)))
			Visuals.label3d(node,"✓ "+caption if visited else caption,Vector3(0,.35,3.65),Color("f3eee0"),30).pixel_size=.025
			if not visited and not skipped and branch=="":
				for badge in range(info.difficulty):MINI.star(node,info.difficulty,badge)
			if stage==available and info.id in reachable and not needs_service:MINI.border(node,Color("c6cfbc"))
	for service_stage in Campaign.SERVICES:
		var choices=Campaign.service_options(wave_seed,service_stage)
		for i in range(choices.size()):
			var branch=choices[i];var pos=Vector3((i-(choices.size()-1)*.5)*6.5,0,stage_z(service_stage)+RoutePlan.STAGE_STEP)
			var base=Node3D.new();add_child(base);base.position=pos;base.scale=Vector3.ONE*MINI_SCALE;service_nodes.append(base)
			if branch=="headquarters":MINI.depot(base)
			elif branch=="merchant":MINI.merchant(base)
			else:MINI.service(base,branch=="vehicle",Color("839c9f") if branch=="vehicle" else Color("a99b79"))
			Visuals.label3d(base,{"vehicle":"Техника","ability":"Способность","headquarters":"Штаб","merchant":"Торговец"}[branch],Vector3(0,.35,3.65),Color("f3eee0"),30).pixel_size=.025
			if RoutePlan.service_roads() and service_stage<plan.size():
				# Roads into the stop from neighbouring lanes of the previous stage, and out to the next stage.
				for lane in RoutePlan.lane_span(i,choices.size(),plan[service_stage-1].size()):path_line(room_point(plan[service_stage-1][lane],plan[service_stage-1].size()),pos)
				for lane in RoutePlan.lane_span(i,choices.size(),plan[service_stage].size()):path_line(pos,room_point(plan[service_stage][lane],plan[service_stage].size()))
			if service_stage==available and branch in RoutePlan.service_options_from(plan,available,route_choices,choices):fork_positions[branch]=pos;service_choices.append(branch)

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
	Visuals.label3d(start_pad,"E — в хаб",Vector3(0,.35,5.1),Color("c9cfbe"),22).pixel_size=.025
	selection_ring=Node3D.new();add_child(selection_ring);selection_ring.scale=Vector3.ONE*MINI_SCALE;MINI.border(selection_ring,Color("ffb52c"),needs_service)
	scroll=maxf(0,-stage_z(available)-7);move_camera();update_selection()
	setup_driving()
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
	# One quiet plate: world, a one-line legend and the controls. Two small buttons top right.
	var size=get_viewport().get_visible_rect().size
	var plate=UiKit.glass(root,Vector2(20,18),Vector2(560,96),Color("242d27d8"));plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UiKit.label(plate,"Бесконечный · сектор %d" % (Campaign.cycle+1) if Campaign.endless else "Мир %d · %s" % [Campaign.world,Campaign.WORLDS[Campaign.world].name],Vector2(16,8),Vector2(530,36),24)
	var hint="Сначала заедь на передышку" if needs_service else "★ средняя · ★★ сложная · редкие чертежи"
	UiKit.label(plate,hint,Vector2(16,44),Vector2(530,22),15,UiKit.MUTED)
	UiKit.label(plate,"WASD — ехать · E — войти · колесо, перетаскивание — обзор",Vector2(16,66),Vector2(530,22),15,UiKit.MUTED)
	UiKit.button(root,"В хаб",Vector2(size.x-300,18),Vector2(130,44),func():hub_requested.emit()).add_theme_font_size_override("font_size",16)
	UiKit.button(root,"Рюкзак [Esc]",Vector2(size.x-160,18),Vector2(140,44),show_pause).add_theme_font_size_override("font_size",16)
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
	tween.chain().tween_callback(func():travelling=false)
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
		travelling=false)
## Battle nodes show the wave preview; service nodes show the service description.
func node_dialog(info:Dictionary,confirm:Callable)->Control:
	var branch=RoutePlan.node_branch(info)
	if branch!="":return preload("res://scripts/route_service_dialog.gd").build(self,branch,confirm)
	if info.type in RoutePlan.CHALLENGES:return preload("res://scripts/route_challenge_dialog.gd").build(self,info,confirm)
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
	if Game.dev_map:
		for id in previews:
			var delta=point-previews[id].position
			if previews[id].visible and absf(delta.x)<=3.15*MINI_SCALE and absf(delta.z)<=3.15*MINI_SCALE:
				pending_info=previews[id].get_meta("info");pending_service="";preview_only=true;selection_ring.hide()
				modal=preload("res://scripts/route_room_dialog.gd").build(self,pending_info);return
	if needs_service:
		for branch in fork_positions:
			var delta=point-fork_positions[branch]
			if absf(delta.x)<=3.15*MINI_SCALE and absf(delta.z)<=3.15*MINI_SCALE:choose_service(branch);return
	for id in previews:
		if not previews[id].visible:continue
		var delta=point-previews[id].position
		if absf(delta.x)<=3.15*MINI_SCALE and absf(delta.z)<=3.15*MINI_SCALE:travel_to_room(previews[id].get_meta("info").stage,id);return
## Mouse wheel zooms the map. Handled in _input: the map UI layer would swallow it otherwise.
func _input(event):
	if travelling or is_instance_valid(modal) or not event is InputEventMouseButton or not event.pressed:return
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		camera.size=clampf(camera.size+(-2.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 2.0),16.0,42.0);move_camera()
		get_viewport().set_input_as_handled()
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
		if event.is_action("interact"):
			get_viewport().set_input_as_handled()
			var target=nearest_target(ENTER_RADIUS)
			if not target.is_empty():enter_target(target)
			return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			dragging=event.pressed
			if event.pressed:drag_distance=0
			elif drag_distance<8:tap_at(event.position)
	if event is InputEventMouseMotion and dragging:
		drag_distance+=event.relative.length();scroll+=event.relative.y*.04;follow_camera=false;move_camera()
	if event is InputEventScreenTouch:
		if event.pressed:drag_distance=0
		elif drag_distance<8:tap_at(event.position)
	if event is InputEventScreenDrag:
		drag_distance+=event.relative.length();scroll+=event.relative.y*.04;follow_camera=false;move_camera()

func _process(delta):
	if is_instance_valid(foreground_hangar) and is_instance_valid(camera):
		foreground_hangar.follow_camera(scroll,camera.size)
	drive(delta)

# ---------------------------------------------------------------- driving
func anchor_point()->Vector3:
	var p=current_point();return Vector3(p.x,0,p.z)
func open_ends()->Array:
	var ends=[]
	if needs_service:
		for branch in fork_positions:ends.append(fork_positions[branch])
	else:
		for id in reachable:ends.append(previews[id].position)
	return ends
func setup_driving():
	selection_ring.hide()
	var start=anchor_point();var ends=open_ends()
	var starts=[start] if available>0 else [START_POINT]
	var flat=func(v:Vector3):return Vector3(v.x,0,v.z)
	var is_end=func(v:Vector3):return ends.any(func(p):return flat.call(v).distance_to(flat.call(p))<.2)
	for road in road_paths:
		if not starts.any(func(p):return flat.call(road.a).distance_to(p)<.2):continue
		if is_end.call(road.b):open_roads.append(road);continue
		# Two-leg route through a rest camp: open both legs if the camp continues to a choice.
		var onward=road_paths.filter(func(next):return flat.call(next.a).distance_to(flat.call(road.b))<.2 and is_end.call(next.b))
		if onward.is_empty():barrier(road)
		else:
			open_roads.append(road)
			for next in onward:
				if next not in open_roads:open_roads.append(next)
	# Also close every other road touching the open area: other routes into our choices and the
	# roads leading on from them (the car is held to open roads anyway; this shows it).
	for road in road_paths:
		if road in open_roads:continue
		if is_end.call(road.b):barrier(road,true)
		elif is_end.call(road.a):barrier(road)
	# The start apron joins the first roads.
	if available==0:open_roads.append({"points":[START_POINT+Vector3(0,0,4.7),START_POINT]})
func barrier(road:Dictionary,at_end:=false):
	# Closed branch: a short line of minimal czech hedgehogs across the road (near its start, or its end).
	var points:Array=road.points
	var i=points.size()-6 if at_end else 4
	i=clampi(i,0,points.size()-2)
	var at:Vector3=points[i];var next:Vector3=points[i+1]
	var along=(next-at).normalized();var side=Vector3(-along.z,0,along.x)
	var line=Node3D.new();line.name="RoadBlock";add_child(line)
	for k in range(-1,2):
		var hog=Node3D.new();line.add_child(hog);hog.position=at+side*k*.55+Vector3(0,-.4,0);hog.rotation.y=k*.6
		for axis in [Vector3(1,1,0),Vector3(-1,1,0),Vector3(0,1,1)]:
			var beam=Visuals.box(hog,Vector3(0,.22,0),Vector3(.07,.62,.07),Color("4f5443"))
			beam.basis=Basis(Vector3.UP.cross(axis.normalized()).normalized() if Vector3.UP.cross(axis.normalized()).length()>.01 else Vector3.RIGHT,Vector3.UP.angle_to(axis.normalized()))
		Visuals.box(hog,Vector3(0,.02,0),Vector3(.5,.03,.08),Color("e0692a"))
func road_clamp(p:Vector3)->Vector3:
	var best=p;var best_d=INF
	for road in open_roads:
		var pts:Array=road.points
		for i in range(pts.size()-1):
			var a=Vector3(pts[i].x,0,pts[i].z);var b=Vector3(pts[i+1].x,0,pts[i+1].z)
			var ab=b-a;var t=clampf((p-a).dot(ab)/maxf(ab.length_squared(),.0001),0,1);var q=a+ab*t
			var d=p.distance_to(q)
			if d<best_d:best_d=d;best=q
	if best_d<=ROAD_HALF:return p
	return best+(p-best).normalized()*ROAD_HALF if best_d<INF else p
func drive(delta):
	if not is_instance_valid(player_marker) or open_roads.is_empty():return
	if travelling or is_instance_valid(modal) or showing_pause:
		update_card();return
	var input=Input.get_vector("west","east","north","south")
	var wish=Vector3(input.x,0,input.y).rotated(Vector3.UP,deg_to_rad(10))*DRIVE_SPEED
	drive_velocity=drive_velocity.move_toward(wish,delta*(22.0 if wish.length()>.1 else 16.0))
	var hero=player_marker.get_node_or_null("CurrentHero")
	if wish.length()>.1 and get_viewport().gui_get_focus_owner()!=null:get_viewport().gui_release_focus()  # WASD drives, not menus
	if drive_velocity.length()>.05:
		var ground=Vector3(player_marker.position.x,0,player_marker.position.z)
		var next=road_clamp(ground+drive_velocity*delta)
		player_marker.position=Vector3(next.x,player_marker.position.y,next.z)
		if hero:hero.rotation.y=PI
		player_marker.rotation.y=lerp_angle(player_marker.rotation.y,atan2(-drive_velocity.x,-drive_velocity.z),minf(1,delta*9))
		follow_camera=true
	if follow_camera and not dragging:
		scroll=lerpf(scroll,-player_marker.position.z-2.0,minf(1,delta*3));move_camera()
	update_card()
func nearest_target(radius:float)->Dictionary:
	var here=Vector3(player_marker.position.x,0,player_marker.position.z);var best={};var best_d=radius
	if needs_service:
		for branch in fork_positions:
			var d=here.distance_to(Vector3(fork_positions[branch].x,0,fork_positions[branch].z))
			if d<best_d:best_d=d;best={"branch":branch,"pos":fork_positions[branch]}
	else:
		for id in reachable:
			var d=here.distance_to(Vector3(previews[id].position.x,0,previews[id].position.z))
			if d<best_d:best_d=d;best={"id":id,"pos":previews[id].position}
	# Back into the garage at the start: E returns to the hub.
	if best.is_empty() and here.distance_to(START_POINT+Vector3(0,0,4.7))<radius:best={"garage":true,"pos":START_POINT+Vector3(0,0,4.7)}
	return best
func enter_target(target:Dictionary):
	if travelling or is_instance_valid(modal):return
	if target.has("garage"):hub_requested.emit();return
	if target.has("branch"):
		pending_service=target.branch;pending_info={};confirm_service()
	else:
		pending_info=previews[target.id].get_meta("info");pending_service="";preview_only=false;confirm_entry()
func update_card():
	var target={} if (travelling or is_instance_valid(modal) or showing_pause) else nearest_target(CARD_RADIUS)
	if target.has("garage"):target={}
	var key=str(target.get("id",target.get("branch","")))
	if key==card_key:return
	card_key=key
	if is_instance_valid(node_card):node_card.queue_free()
	node_card=null
	if target.is_empty():return
	Game.sound("route_select",Game)
	var info=previews[target.id].get_meta("info") if target.has("id") else {}
	node_card=preload("res://scripts/route_node_card.gd").open(self,target.pos,info,target.get("branch",""))
