extends Node
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	await get_tree().process_frame;await get_tree().process_frame;await get_tree().process_frame
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	var memory=preload("res://scripts/ui/tablet_memory.gd");memory.loaded=true;memory.state={}
	var view=preload("res://scripts/ui/field_tablet.gd").new();view.tab="guide";add_child(view);await settle()
	view.guide_category="Все";view.guide_query="";view.guide_box.get_parent().scroll_vertical=200
	await settle();var scroll=view.guide_box.get_parent().scroll_vertical
	check(scroll>0,"encyclopedia can scroll")
	view.tab="settings";view.settings_tab="Звук";view.refresh();await settle()
	view.tab="guide";view.refresh();await settle()
	check(view.guide_box.get_parent().scroll_vertical==scroll,"encyclopedia position survives tab switch")
	view.queue_free();await settle()
	view=preload("res://scripts/ui/field_tablet.gd").new();add_child(view);await settle()
	# 0.8.0: the field tablet always opens on «Снаряжение»; scroll and sub-tabs are still remembered.
	check(view.tab=="inventory" and view.settings_tab=="Звук","tablet opens on equipment, remembers settings sub-tab")
	view.tab="guide";view.refresh();await settle()
	check(view.guide_box.get_parent().scroll_vertical==scroll,"encyclopedia scroll survives reopening")
	view.tab="tech";view.refresh();await settle()
	var reader=view.content.get_child(0);var path=reader.documents.back().path;reader.open_document(path);await settle();reader.body.get_v_scroll_bar().value=120;await settle()
	var doc_scroll=reader.body.get_v_scroll_bar().value
	reader.reload();await settle();check(absf(reader.body.get_v_scroll_bar().value-doc_scroll)<2,"refresh preserves document scroll")
	view.tab="inventory";view.refresh();await settle();view.tab="tech";view.refresh();await settle()
	reader=view.content.get_child(0)
	check(reader.selected_path==path and absf(reader.body.get_v_scroll_bar().value-doc_scroll)<2,"technical document and scroll remembered")
	view.queue_free();await settle()
	Game.profiles.selected=true
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await settle()
	Campaign.configure(1,true);main.start_run();await settle()
	var arena=main.run_arena;arena.auto_pause_enabled=false;arena.set_physics_process(false)
	check(main.current==arena and arena.room_index==0,"endless starts in first battle without map")
	main.show_map(1);await settle();check(main.current==arena and arena.room_index==1,"next battle without map")
	main.show_map(2);await settle()
	check(main.current.get_script()==load("res://scripts/ui/endless_service_choice.gd") and Campaign.service_options(1,2).size()==3,"three service rooms offered")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("res://screenshots/endless-services.png")
	var checkpoint=Game.run_checkpoint.duplicate(true)
	check(checkpoint.mode=="map" and checkpoint.index==2,"service checkpoint saved")
	main.clear_current();arena.queue_free();main.run_arena=null;main.current=null;await settle()
	Game.run_checkpoint=checkpoint
	main.resume_run();await settle();arena=main.run_arena;arena.auto_pause_enabled=false;arena.set_physics_process(false)
	check(main.current.get_script()==load("res://scripts/ui/endless_service_choice.gd"),"resume service checkpoint without map")
	main.current.selected.emit("vehicle");await settle()
	check(main.current.get_script()==load("res://scripts/service_room.gd"),"selected service entered")
	main.current.completed.emit(2);await settle()
	check(main.current==arena and arena.room_index==2 and arena.visited_services.has(2),"service exits directly into battle")
	var hp=Campaign.hp_scale(0);var damage=Campaign.damage_scale(0);var boss_hp=Campaign.boss_health()
	main.show_map(7);await settle()
	check(Campaign.cycle==1 and main.current==arena and arena.room_index==0 and arena.visited_services.is_empty(),"new cycle resets rooms and service visits")
	check(Campaign.hp_scale(0)>hp and Campaign.damage_scale(0)>damage and Campaign.boss_health()>boss_hp,"next cycle gets stronger")
	Campaign.cycle=30;hp=Campaign.hp_scale(0);Campaign.cycle=31
	check(Campaign.hp_scale(0)>hp and Campaign.active_cap(0)<=8,"late cycles grow with bounded simultaneous enemies")
	Campaign.cycle=1
	arena.room.wave=2;arena.room.room_boss_spawned=true;arena.phase="combat";arena.room.pickups.clear();arena.room.spawn_queue.clear();arena.flow.finish_wave()
	check(arena.phase=="upgrade" and arena.room.room_cleared,"miniboss clear opens reward automatically")
	arena.reward.skip_upgrade();check(arena.phase=="map","reward advances endless automatically")
	main.queue_free();await settle()
	print("ENDLESS/TABLET: ",failures," failures");get_tree().quit(failures)
