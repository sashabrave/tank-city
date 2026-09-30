extends Node
var current
var run_arena
var route_choices:Dictionary={}
func _ready():
	Game.profile_changed.connect(reload_profile_hub)
	if Game.profiles.selected and not Game.save_blocked:show_hub()
	else:ProfileMenu.call_deferred("open_start")
	if "--arena" in OS.get_cmdline_user_args():call_deferred("start_run")
func clear_current():
	Game.reset_input()
	if is_instance_valid(current):
		if current.get_parent()==self:remove_child(current)
		if current!=run_arena:current.queue_free()
func show_hub():
	call_deferred("_return_hub")
func _return_hub():
	var greeting="wake" if not is_instance_valid(current) or (is_instance_valid(run_arena) and run_arena.run.lost_run) else "return" if is_instance_valid(run_arena) or current.get_script().resource_path.ends_with("route_map.gd") else ""
	Game.return_through_gate=is_instance_valid(run_arena) and not run_arena.run.lost_run
	Game.music_context("hub")
	if is_instance_valid(run_arena):
		run_arena.resolve_recipes_on_return()
		if not run_arena.run.lost_run:Game.progression.event("extracted",run_arena.run.earned)
	if is_instance_valid(run_arena):Game.clear_run_checkpoint()
	# A kept checkpoint (left from the map before the first room) must not freeze hub purchases.
	Game.run_save_baseline={}
	if Game.run_checkpoint.is_empty():Game.progression.end_run()
	clear_current()
	if is_instance_valid(run_arena):run_arena.queue_free()
	run_arena=null
	current=load("res://scenes/hub.tscn").instantiate();current.arrival_reason=greeting;add_child(current)
	current.start_requested.connect(request_run)
	current.gallery_requested.connect(show_gallery)
	current.sandbox_requested.connect(show_sandbox)
func select_world():
	var picker=load("res://scripts/ui/world_select.gd").new();current.root.add_child(picker)
	current.build_menu=picker;current.phase="workshop";current.exit_queued=false
	picker.cancelled.connect(current.close_station)
	picker.selected.connect(func(id,infinite):Campaign.configure(id,infinite);picker.queue_free();start_run())

func start_run():
	Game.clear_run_checkpoint()
	Game.progression.begin_run();Game.progression.event("enter_world_"+str(Campaign.world),1,true)
	if Campaign.endless:Game.progression.event("enter_endless",1,true)
	route_choices.clear();Game.visual_run_seed=randi();show_map(0)
func show_map(index: int):
	if Campaign.endless and index>=Campaign.SIZES.size():
		Campaign.cycle+=1;index=0;route_choices.clear()
		Game.progression.event("endless_cycle",Campaign.cycle+1,true)
		if is_instance_valid(run_arena):run_arena.visited_services.clear();run_arena.run.route_choices=route_choices
	if Campaign.endless:
		advance_endless(index);return
	Game.music_context("map")
	clear_current()
	current=load("res://scripts/route_map.gd").new();current.available=index;current.run_context=run_arena
	current.needs_service=is_instance_valid(run_arena) and index in Campaign.SERVICES and not run_arena.visited_services.has(index)
	current.ability_available=is_instance_valid(run_arena) and run_arena.abilities.selected!=""
	current.wave_seed=run_arena.run_seed if is_instance_valid(run_arena) else Game.visual_run_seed
	current.route_choices=route_choices
	current.hero_weapon=run_arena.weapon if is_instance_valid(run_arena) else Game.selected_weapon
	if not is_instance_valid(run_arena) and Game.garage.starting_vehicle()!="":current.hero_kind=Game.garage.starting_vehicle()
	if is_instance_valid(run_arena):
		if run_arena.pending_vehicle!="":current.hero_kind=run_arena.pending_vehicle
		elif is_instance_valid(run_arena.player):current.hero_kind=run_arena.player.kind
		elif not run_arena.resume_checkpoint.get("hero",{}).is_empty():current.hero_kind=str(run_arena.resume_checkpoint.hero.kind)
	add_child(current)
	Game.checkpoint_run(run_arena,index,"map",route_choices)
	current.dev_requested.connect(test_jump);current.test_requested.connect(test_jump);current.route_selected.connect(enter_room);current.hub_requested.connect(show_hub);current.service_requested.connect(show_service)
func enter_room(index: int,node_id:String=""):
	if is_instance_valid(current) and current.has_method("travel_to_room") and index!=current.available:return
	var seed_value=run_arena.run_seed if is_instance_valid(run_arena) else Game.visual_run_seed
	var plan=RoutePlan.build(seed_value)
	var service_branch=run_arena.visited_services.get(index,"") if is_instance_valid(run_arena) else ""
	var reachable=RoutePlan.reachable(plan,index,route_choices,service_branch)
	if reachable.is_empty():return
	if node_id=="":node_id=reachable[0]
	if node_id not in reachable:return
	if is_instance_valid(run_arena) and index in Campaign.SERVICES and not run_arena.visited_services.has(index):return
	route_choices[index]=node_id
	var branch=RoutePlan.node_branch(RoutePlan.chosen(plan,index,route_choices))
	if branch!="" and is_instance_valid(run_arena):
		show_node_service(branch,index);return
	clear_current()
	if not is_instance_valid(run_arena):
		run_arena=load("res://scenes/arena.tscn").instantiate();run_arena.run_seed=Game.visual_run_seed;run_arena.run.route_choices=route_choices;current=run_arena;add_child(current)
		current.exit_requested.connect(show_hub);current.map_requested.connect(show_map);current.restart_requested.connect(restart_room)
	else:
		current=run_arena;add_child(current);current.begin_room(index)

	Game.checkpoint_run(run_arena,index,"room",route_choices)

func show_service(branch: String,index: int):
	if not is_instance_valid(run_arena) or run_arena.visited_services.has(index):return
	if branch=="ability" and run_arena.abilities.slots.is_empty():
		run_arena.abilities.slots.append("shield");run_arena.abilities.select("shield")
	clear_current()
	if branch=="merchant":current=load("res://scripts/merchant_room.gd").new()
	else:current=load("res://scripts/service_room.gd").new();current.branch=branch
	current.arena=run_arena;current.index=index;add_child(current)
	current.hub_requested.connect(show_hub)
	current.completed.connect(func(completed_index):run_arena.visited_services[completed_index]=branch;show_map(completed_index))

## A service placed on the route as an ordinary node: after it the next stage opens.
func show_node_service(branch:String,index:int):
	Game.progression.event("visit_"+branch)
	if branch=="headquarters" and is_instance_valid(current) and "root" in current:
		# Depot pit stop: cards over the map, then the next stage opens.
		var stop=preload("res://scripts/depot_stop.gd").new();stop.arena=run_arena;stop.index=index
		current.root.add_child(stop)
		stop.done.connect(func():run_arena.run.route_choices=route_choices;show_map(index+1))
		return
	clear_current();current=load("res://scripts/service_room.gd").new();current.arena=run_arena;current.index=index;current.branch=branch;add_child(current)
	current.hub_requested.connect(show_hub)
	current.completed.connect(func(_completed):run_arena.run.route_choices=route_choices;show_map(index+1))

func test_jump(target:int,replay_rewards:bool,node_id:String=""):
	var plan=RoutePlan.build(Game.visual_run_seed)
	if node_id=="":node_id=plan[target][0].id
	route_choices=RoutePlan.path_to(plan,target,node_id)
	clear_current()
	if is_instance_valid(run_arena):run_arena.queue_free()
	run_arena=load("res://scenes/arena.tscn").instantiate();run_arena.run_seed=Game.visual_run_seed;run_arena.run.route_choices=route_choices;current=run_arena;add_child(current)
	current.exit_requested.connect(show_hub);current.map_requested.connect(show_map);current.restart_requested.connect(restart_room)
	current.visited_services={}
	for stage in Campaign.SERVICES:
		if stage<=target:current.visited_services[stage]="test"
	if replay_rewards:
		var replay=load("res://scripts/test_replay.gd").new();replay.arena=run_arena;replay.main=self;replay.target=target;run_arena.add_child(replay)
	else:current.begin_room(target)

func show_gallery():
	clear_current()
	current=load("res://scenes/test_gallery.tscn").instantiate();add_child(current)
	current.hub_requested.connect(show_hub)

func reload_profile_hub():
	if is_instance_valid(run_arena):return
	clear_current();current=null
	if not Game.profiles.selected:
		ProfileMenu.call_deferred("open_start");return
	current=load("res://scenes/hub.tscn").instantiate();current.arrival_reason="wake";add_child(current)
	current.start_requested.connect(request_run);current.gallery_requested.connect(show_gallery);current.sandbox_requested.connect(show_sandbox)

func request_run():
	if Game.run_checkpoint.is_empty():select_world();return
	var dialog=preload("res://scripts/ui/resume_run_dialog.gd").new();dialog.checkpoint=Game.run_checkpoint
	current.root.add_child(dialog);current.build_menu=dialog;current.phase="workshop";current.exit_queued=false
	dialog.cancelled.connect(current.close_station)
	dialog.new_run.connect(func():current.close_station();Game.clear_run_checkpoint();Game.progression.end_run();select_world())
	dialog.continued.connect(func():current.close_station();preload("res://scripts/ui/loading_veil.gd").run(self,resume_run))
func resume_run(restart:bool=false):
	var data=Game.run_checkpoint.duplicate(true)
	if data.is_empty():return
	Campaign.configure(int(data.world),data.endless);Campaign.cycle=int(data.cycle);Campaign.endless_strength=data.strength
	Game.selected_class=data.class;Game.visual_run_seed=int(data.seed)
	route_choices=preload("res://scripts/profile/run_checkpoint.gd").integer_keys(data.choices)
	clear_current()
	if not data.run.is_empty():
		run_arena=load("res://scenes/arena.tscn").instantiate();run_arena.resume_checkpoint=data;run_arena.run_seed=int(data.seed)
		run_arena.defer_room=not (restart and data.mode=="room") and not data.endless
		current=run_arena;add_child(current);run_arena.run.route_choices=route_choices
		current.exit_requested.connect(show_hub);current.map_requested.connect(show_map);current.restart_requested.connect(restart_room)
	# Battle state is never restored: a room checkpoint returns to the route map in front of that room.
	# Only the explicit «Заново» action restarts the same room immediately.
	if restart and data.mode=="room":Game.checkpoint_run(run_arena,int(data.index),"room",route_choices)
	else:show_map(int(data.index))

func restart_room():
	if Game.run_checkpoint.get("mode","")!="room" or Game.run_save_baseline.is_empty():return
	var checkpoint=Game.run_checkpoint.duplicate(true)
	var profile=Game.run_save_baseline.duplicate(true);profile.run_checkpoint=checkpoint
	Game.apply_profile(profile)
	Game.notifications.pending.clear();Game.notifications.dirty=false
	clear_current()
	if is_instance_valid(run_arena):run_arena.queue_free()
	run_arena=null;current=null
	resume_run(true)

func advance_endless(index:int):
	if is_instance_valid(run_arena) and index in Campaign.SERVICES and not run_arena.visited_services.has(index):
		Game.music_context("hub")
		clear_current()
		current=preload("res://scripts/ui/endless_service_choice.gd").new();current.index=index;add_child(current)
		current.selected.connect(func(branch):show_service(branch,index));current.hub_requested.connect(show_hub)
		Game.checkpoint_run(run_arena,index,"map",route_choices)
	else:enter_room(index)

## Sandbox: an isolated test field. The profile is snapshotted, writing is off, everything is unlocked;
## leaving restores the profile exactly (including an unfinished real run) and returns to the hub.
var sandbox_snapshot:Dictionary={}
var sandbox_restore:Dictionary={}
func show_sandbox():
	if is_instance_valid(run_arena):return
	sandbox_snapshot=Game.serialize_progress().duplicate(true)
	sandbox_restore={"save":Game.save_enabled,"settings":Settings.persistence_enabled,"lighting":Settings.values.world_lighting,"world":Campaign.world,"endless":Campaign.endless}
	Game.save_enabled=false;Settings.persistence_enabled=false
	Game.weapon_unlocks=Game.LOOT.WEAPONS.keys();Game.class_unlocks=Game.CLASSES.keys()
	Campaign.configure(1)
	clear_current()
	run_arena=load("res://scenes/arena.tscn").instantiate();run_arena.sandbox=true;run_arena.run_seed=randi();run_arena.auto_pause_enabled=false
	current=run_arena;add_child(current)
	current.exit_requested.connect(exit_sandbox)
	var admin=load("res://scripts/sandbox/admin_panel.gd").new();admin.name="SandboxAdmin";admin.arena=run_arena;run_arena.add_child(admin)
	admin.exit_requested.connect(exit_sandbox)
	Game.music_context("battle")
func exit_sandbox():
	if not is_instance_valid(run_arena) or not run_arena.sandbox:return
	get_tree().paused=false
	clear_current();run_arena.queue_free();run_arena=null;current=null
	Settings.values.world_lighting=sandbox_restore.lighting;Settings.apply()
	Game.apply_profile(sandbox_snapshot)
	Game.save_enabled=sandbox_restore.save;Settings.persistence_enabled=sandbox_restore.settings
	Campaign.configure(sandbox_restore.world,sandbox_restore.endless)
	ResourceStrip.track_run(null)
	show_hub()
