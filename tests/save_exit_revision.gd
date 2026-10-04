extends Node
# Map checkpoints instead of battle saves, hub saving after leaving the map, soft checkpoint validation,
# tablet quit action and changelog tab. Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	await get_tree().process_frame;await get_tree().process_frame;await get_tree().process_frame
func shot(path:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(path)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	var memory=preload("res://scripts/ui/tablet_memory.gd");memory.loaded=true;memory.state={}
	# An incompatible run snapshot drops only the unfinished run.
	var profile=Game.serialize_progress();profile.run_checkpoint={"version":1,"mode":"room","outdated":true}
	var result=preload("res://scripts/profile/schema.gd").validate(profile)
	check(result.ok and result.data.run_checkpoint.is_empty(),"outdated checkpoint does not block profile")
	Game.profiles.selected=true
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await settle()
	Campaign.configure(1,false);main.start_run();await settle()
	check(not Game.run_save_baseline.is_empty() and Game.run_checkpoint.mode=="map","map checkpoint freezes run baseline")
	main.show_hub();await settle()
	check(Game.run_save_baseline.is_empty() and not Game.run_checkpoint.is_empty(),"hub after map saves live profile, keeps run")
	main.select_world();main.current.build_menu.queue_free();main.current.close_station();await settle()
	main.start_run();await settle()
	main.enter_room(0);await settle()
	var arena=main.run_arena;arena.auto_pause_enabled=false;arena.set_physics_process(false)
	check(main.current==arena and Game.run_checkpoint.mode=="room","room checkpoint on entry")
	var checkpoint=Game.run_checkpoint.duplicate(true)
	var older=checkpoint.duplicate(true);older.run.weapon_mods.erase(Game.LOOT.gun_ids().back());older.run.erase("range_multiplier")
	var older_profile=Game.serialize_progress();older_profile.run_checkpoint=older
	var upgraded=preload("res://scripts/profile/schema.gd").validate(older_profile)
	check(upgraded.ok and not upgraded.data.run_checkpoint.is_empty() and upgraded.data.run_checkpoint.run.has("range_multiplier"),"older checkpoint is completed, not dropped")
	main.clear_current();arena.queue_free();main.run_arena=null;main.current=null;await settle()
	Game.run_checkpoint=checkpoint.duplicate(true)
	main.resume_run();await settle()
	check(main.current.get_script()==load("res://scripts/route_map.gd") and main.current.available==0,"interrupted battle resumes on route map at that room")
	check(Game.run_checkpoint.mode=="map" and int(Game.run_checkpoint.index)==0,"resumed map becomes the checkpoint")
	main.enter_room(0);await settle()
	arena=main.run_arena;arena.auto_pause_enabled=false;arena.set_physics_process(false)
	check(main.current==arena and arena.room_index==0,"room can be entered again from the map")
	main.restart_room();await settle()
	check(main.run_arena!=null and main.current==main.run_arena,"explicit restart still enters the room directly")
	main.run_arena.set_physics_process(false)
	# Tablet actions.
	var view=preload("res://scripts/ui/field_tablet.gd").new();view.tab="about";add_child(view);await settle()
	check(view.find_child("Nav_exit",true,false)!=null,"quit action in tablet")
	check(view.find_child("Nav_base",true,false)!=null,"hub action kept when leaving is possible")
	await shot("/tmp/r13-save-exit-tablet.png")
	view.confirm_quit();await settle();await shot("/tmp/r13-save-exit-confirm.png")
	check(view.find_child("QuitConfirm",true,false)!=null and view.find_child("QuitAccept",true,false)!=null,"quit asks for confirmation")
	view.cancel_quit();await settle()
	check(view.find_child("QuitConfirm",true,false)==null,"quit confirmation cancels")
	view.about_tab="changelog";view.refresh();await settle()
	var box=view.find_child("ChangelogBox",true,false)
	check(box!=null and box.get_child_count()>0,"changelog tab lists entries")
	await shot("/tmp/r13-save-exit-changelog.png")
	await settle();box=view.find_child("ChangelogBox",true,false)
	var first_title=box.get_child(1).text
	Texts.set_language("en");view.refresh();await settle()
	box=view.find_child("ChangelogBox",true,false)
	check(box.get_child(1).text!=first_title,"changelog follows language")
	check(view.find_child("ChangelogRail",true,false).get_child_count()>=2,"version rail lists releases")
	Texts.set_language("ru")
	view.queue_free();await settle()
	var hub_view=preload("res://scripts/ui/field_tablet.gd").new();hub_view.can_leave=false;add_child(hub_view);await settle()
	check(hub_view.find_child("Nav_base",true,false)==null and hub_view.find_child("Nav_exit",true,false)!=null,"hub tablet hides hub action, keeps quit")
	hub_view.queue_free()
	main.queue_free();await settle()
	await checkpoint_rollback()
	await resume_fast()
	await endless_chain()
	Game.save_enabled=false
	print("SAVE/EXIT: %d failures" % failures);get_tree().quit(1 if failures else 0)
func freeze(arena):
	arena.set_physics_process(false);arena.auto_pause_enabled=false
	for actor in arena.actors:actor.set_physics_process(false)
## from run_checkpoint_v20 (+ ui_checkpoint_v20): a room checkpoint on disk, rollback on restart without duplicated
## currency, rewards committed at the next map checkpoint, process loss → resume dialog → map in front of the room,
## a captured vehicle restored from a map checkpoint, death clears the checkpoint. Writes only into a fresh temp folder.
func checkpoint_rollback():
	Game.apply_profile(Game.fresh_profile.duplicate(true));Game.save_path="/tmp/war-cats-save-exit-%d/profile.json" % Time.get_ticks_usec();Game.profiles.selected=true;Game.save_blocked=false;Game.save_enabled=true
	Campaign.configure(1,false)
	var main=load("res://scripts/main.gd").new();add_child(main);await get_tree().process_frame;await get_tree().process_frame
	main.start_run();check(Game.run_checkpoint.mode=="map","run starts with a map checkpoint")
	# Stage 1 may hold a service or challenge point; follow a lane that is an ordinary battle on both stages.
	var lane=RoutePlan.build(Game.visual_run_seed)[1].filter(func(n):return n.type=="battle")[0].lane
	main.enter_room(0,"0:%d" % lane);var arena=main.run_arena;freeze(arena)
	check(Game.run_checkpoint.mode=="room","room checkpoint on entry")
	arena.run.damage_bonus=2.5;arena.run.behavior_cards=["opening_shot"]
	arena.run.pending_recipes=[{"category":"weapon","id":"smg"}]
	arena.abilities.select("grenade");arena.abilities.slots=["grenade"];arena.abilities.level.power=2.0
	arena.headquarters.levels["hq_medbay"]=3.0
	Game.credits=100;Game.checkpoint_run(arena,0,"room",main.route_choices)
	var expected_seed=arena.run_seed
	Game.earn(70);arena.run.damage_bonus=99;arena.run.pending_recipes.clear();arena.run.behavior_cards.append("last_stand")
	arena.run.soldier_hp=.2;arena.phase="combat";arena.start_wave(2);Game.save_progress()
	var disk=Game.ProfileStore.load_file(Game.save_path,Game.ProfileSchema.validate)
	check(disk.ok and disk.data.credits==100 and Game.credits==170,"mid-room the disk keeps the room-entry credits")
	check(disk.ok and disk.data.run_checkpoint.run.damage_bonus==2.5,"the checkpoint on disk keeps the room-entry run")
	main.restart_room();arena=main.run_arena;freeze(arena)
	check(Game.credits==100 and arena.run.damage_bonus==2.5 and arena.room.wave==0,"restart rolls back credits and run, no duplicated currency")
	check(arena.run.behavior_cards==["opening_shot"] and arena.run.pending_recipes.size()==1,"restart restores cards and blueprints")
	check(arena.abilities.selected=="grenade" and arena.abilities.level.power==2,"restart restores abilities")
	check(arena.headquarters.levels.hq_medbay==3 and arena.run_seed==expected_seed,"restart restores HQ levels and the seed")
	# A completed room's rewards are committed at the next map checkpoint.
	Game.earn(25);main.show_map(1);check(Game.run_checkpoint.mode=="map","map checkpoint after the room")
	main.enter_room(1,"1:%d" % lane);arena=main.run_arena;freeze(arena)
	check(Game.run_checkpoint.index==1 and arena.room_index==1,"second room checkpoint")
	Game.earn(50);Game.save_progress()
	disk=Game.ProfileStore.load_file(Game.save_path,Game.ProfileSchema.validate);check(disk.ok and disk.data.credits==125,"the map checkpoint committed the first room's reward only")
	# Simulate process loss: destroy nodes without going through hub/extraction.
	main.clear_current();main.run_arena.queue_free();main.run_arena=null;main.current=null;main.queue_free();await get_tree().process_frame
	Game.apply_profile(disk.data)
	main=load("res://scripts/main.gd").new();add_child(main);await get_tree().process_frame;await get_tree().process_frame
	check(not Game.run_checkpoint.is_empty() and Game.credits==125,"after process loss the profile holds the checkpoint")
	# from ui_checkpoint_v20: starting a run with a saved checkpoint opens the resume dialog.
	main.request_run()
	check(main.current.build_menu!=null and main.current.build_menu.get_script()==preload("res://scripts/ui/resume_run_dialog.gd") and main.current.build_menu.has_signal("continued"),"a saved run opens the resume dialog")
	main.current.close_station()
	main.resume_run();arena=main.run_arena
	check(arena.defer_room and main.current.get_script().resource_path.ends_with("route_map.gd") and main.current.available==1,"a room checkpoint resumes on the map in front of that room")
	main.enter_room(1,"1:%d" % lane);arena=main.run_arena;freeze(arena)
	check(arena.room_index==1 and arena.room.wave==0 and arena.run.damage_bonus==2.5,"the room is built on entry from the checkpoint")
	check(arena.run.route_choices.has(1) and arena.run.behavior_cards==["opening_shot"],"route choices and cards restored")
	check(arena.abilities.level.power==2 and arena.run.pending_recipes.size()==1,"abilities and blueprints restored")
	# Map checkpoints preserve service visits, a captured vehicle and its entry armor.
	var cp=Game.run_checkpoint.duplicate(true);cp.mode="map";cp.index=2
	cp.run.visited_services={2:"vehicle"};cp.hero={"kind":"tank","hp":4.5,"salvaged":true,"origin":"captured","zone":2}
	cp=JSON.parse_string(JSON.stringify(cp))
	check(preload("res://scripts/profile/run_checkpoint.gd").valid(cp),"a JSON round-tripped checkpoint is valid")
	var restored=load("res://scenes/arena.tscn").instantiate();restored.resume_checkpoint=cp;add_child(restored);freeze(restored)
	# Author, 4 Oct 2026: the hero hops out on foot, his vehicle drives in and parks next to the start cell.
	var parked=restored.wrecks.filter(func(w):return is_instance_valid(w) and w.kind=="tank" and w.vehicle_origin=="captured" and is_equal_approx(float(w.armor),4.5) and w.boardable)
	check(restored.player.kind=="soldier" and parked.size()==1 and absi(parked[0].cell.x-restored.player.cell.x)==1 and parked[0].cell.y==restored.player.cell.y,"a captured vehicle and its armor are restored next to the start")
	check(restored.run.visited_services.has(2),"service visits are restored")
	restored.queue_free()
	var invalid=cp.duplicate(true);invalid.abilities.levels.grenade.power=[]
	check(not preload("res://scripts/profile/run_checkpoint.gd").valid(invalid),"a malformed checkpoint is rejected")
	# Restart restores the same checkpoint; death clears it.
	check(main.run_arena!=null,"the run arena is alive before restart")
	main.restart_room();arena=main.run_arena;freeze(arena)
	check(arena.room.wave==0 and not get_tree().paused,"restart enters the room fresh")
	arena.phase="combat";arena.flow.finish_run(false,"test");check(Game.run_checkpoint.is_empty(),"death clears the checkpoint")
	Game.save_enabled=false;main.clear_current()
	if is_instance_valid(main.run_arena):main.run_arena.queue_free()
	main.run_arena=null;main.queue_free()
	await get_tree().process_frame
## from resume_fast_revision: continuing builds no hidden battle room, the saved vehicle survives the next map save,
## entering the room restores it.
func resume_fast():
	Game.save_enabled=false;Game.apply_profile(Game.fresh_profile.duplicate(true));Campaign.configure(1,false)
	var main=load("res://scripts/main.gd").new();add_child(main);await get_tree().process_frame;await get_tree().process_frame
	main.start_run();main.enter_room(0);await get_tree().process_frame
	main.show_map(1);await get_tree().process_frame
	var cp=Game.run_checkpoint.duplicate(true)
	cp.hero={"kind":"buggy","hp":3.0,"salvaged":false,"origin":"owned","zone":1}
	Game.run_checkpoint=cp.duplicate(true)
	main.resume_run();await get_tree().process_frame
	var arena=main.run_arena
	check(arena.defer_room and not is_instance_valid(arena.player) and arena.walls.is_empty(),"resume: no hidden battle room is built")
	check(main.current.get_script().resource_path.ends_with("route_map.gd") and main.current.hero_kind=="buggy","resume: the map shows the saved vehicle")
	check(Game.run_checkpoint.get("hero",{}).get("kind","")=="buggy","resume: the next map save keeps the hero")
	var plan=RoutePlan.build(arena.run_seed)
	var lanes=RoutePlan.reachable(plan,1,main.route_choices,"").filter(func(id):return RoutePlan.node_branch(RoutePlan.chosen(plan,1,{1:id}))=="")
	if lanes.is_empty():print("RESUME FAST: no battle lane on stage 1 for this seed, room check skipped")
	else:
		main.enter_room(1,lanes[0]);await get_tree().process_frame
		check(is_instance_valid(main.run_arena.player) and main.run_arena.player.kind=="soldier" and main.run_arena.wrecks.any(func(w):return is_instance_valid(w) and w.kind=="buggy" and w.boardable),"entering the room restores the vehicle (parked next to the start)")
	main.queue_free();await get_tree().process_frame
## from endless_tablet_revision: the endless chain runs without the route map, the service choice is a checkpoint
## that resumes without the map, a service exits straight into battle, a new cycle resets rooms.
func endless_chain():
	Game.save_enabled=false;Game.apply_profile(Game.fresh_profile.duplicate(true));Game.profiles.selected=true
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await settle()
	Campaign.configure(1,true);main.start_run();await settle()
	var arena=main.run_arena;arena.auto_pause_enabled=false;arena.set_physics_process(false)
	check(main.current==arena and arena.room_index==0,"endless starts in the first battle without the map")
	main.show_map(1);await settle();check(main.current==arena and arena.room_index==1,"endless: next battle without the map")
	main.show_map(2);await settle()
	check(main.current.get_script()==load("res://scripts/ui/endless_service_choice.gd") and Campaign.service_options(1,2).size()==3,"endless: three service rooms offered")
	var checkpoint=Game.run_checkpoint.duplicate(true)
	check(checkpoint.mode=="map" and checkpoint.index==2,"endless: service checkpoint saved")
	main.clear_current();arena.queue_free();main.run_arena=null;main.current=null;await settle()
	Game.run_checkpoint=checkpoint
	main.resume_run();await settle();arena=main.run_arena;arena.auto_pause_enabled=false;arena.set_physics_process(false)
	check(main.current.get_script()==load("res://scripts/ui/endless_service_choice.gd"),"endless: the service checkpoint resumes without the map")
	main.current.selected.emit("vehicle");await settle()
	check(main.current==arena and is_instance_valid(arena.playground) and arena.playground.get_script()==load("res://scripts/service_room.gd"),"endless: the selected service is entered on the run arena")
	arena.playground.completed.emit(2);await settle()
	check(main.current==arena and arena.room_index==2 and arena.visited_services.has(2),"endless: the service exits directly into battle")
	main.show_map(7);await settle()
	check(Campaign.cycle==1 and main.current==arena and arena.room_index==0 and arena.visited_services.is_empty(),"endless: a new cycle resets rooms and service visits")
	Campaign.cycle=0;Campaign.configure(1,false)
	main.queue_free();await settle()
