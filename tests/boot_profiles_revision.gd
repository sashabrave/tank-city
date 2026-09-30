extends Node
var errors=0
func check(value:bool,message:String):
	if not value:errors+=1;push_error(message)
func _ready():call_deferred("run")
func shot(name:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/"+name+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.values.language="ru";Settings.apply()
	Game.profiles.directory="/tmp/tank-startup-%d" % Time.get_ticks_usec();Game.profiles.active=1;Game.profiles.selected=false;Game.save_path=Game.profiles.path(1)
	Game.apply_profile(Game.fresh_profile.duplicate(true));Game.save_blocked=false;Game.save_enabled=true
	var main=load("res://scenes/main.tscn").instantiate();add_child(main)
	await get_tree().create_timer(.2).timeout
	check(is_instance_valid(ProfileMenu.modal) and ProfileMenu.modal.startup,"Empty boot opens picker")
	Game.save_progress();check(not Game.profiles.exists(1),"No implicit save on empty boot")
	await shot("profiles-first-launch")
	ProfileMenu.modal.choose_slot(2,true)
	await get_tree().create_timer(.8).timeout
	check(Game.profiles.selected and Game.profiles.active==2 and Game.profiles.exists(2),"Explicit creation saved selected slot")
	check(Game.progression.telegram_options.size()==3,"Fresh profile generates orders without crash")
	check(is_instance_valid(main.current) and main.current.arrival_reason=="","New profile enters hub")
	var arrival=main.current.find_children("*","Control",true,false).filter(func(n):return n.get_script()==load("res://scripts/ui/arrival_dialog.gd"))
	if not arrival.is_empty():arrival[0].dismiss()
	await get_tree().process_frame;ProfileMenu.open();await get_tree().process_frame;await shot("profiles-cards")
	check(Game.profiles.choose(1,true),"Create another profile")
	await get_tree().process_frame
	check(Game.profiles.remove(2),"Delete inactive profile")
	check(Game.profiles.remove(1),"Delete final profile")
	await get_tree().create_timer(.2).timeout
	check(not Game.profiles.selected and is_instance_valid(ProfileMenu.modal) and ProfileMenu.modal.startup,"Last deletion returns to picker")
	Game.save_progress();check(not Game.profiles.exists(1) and not Game.profiles.exists(2),"Deleted slots stay deleted")
	var slots=load("res://scripts/profile/slots.gd").new();slots.directory=Game.profiles.directory;slots.initialize();check(not slots.selected,"Empty state survives restart")
	ProfileMenu.modal.choose_slot(3,true);await get_tree().create_timer(.7).timeout
	check(Game.profiles.active==3 and Game.profiles.exists(3),"Create after deleting all")
	Game.save_enabled=false;main.queue_free();ProfileMenu.close();await get_tree().process_frame
	print("BOOT/PROFILES failures: ",errors);get_tree().quit(1 if errors else 0)
