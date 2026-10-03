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
	print("SAVE/EXIT: %d failures" % failures);get_tree().quit(1 if failures else 0)
