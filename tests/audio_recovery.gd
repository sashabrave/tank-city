extends Node
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=true
	Settings.values.fullscreen=false;Settings.apply()
	Game.music_context("hub")
	var c=Game.music_controller
	await get_tree().create_timer(2).timeout
	print("AUDIO DRIVER ",AudioServer.get_driver_name()," device ",AudioServer.output_device)
	for i in AudioServer.bus_count:print("BUS ",AudioServer.get_bus_name(i)," send=",AudioServer.get_bus_send(i)," db=",AudioServer.get_bus_volume_db(i)," mute=",AudioServer.is_bus_mute(i)," peak=",AudioServer.get_bus_peak_volume_left_db(i,0))
	print("TRACK ",c.current_track," format=",c.backgrounds[c.active].stream.format," length=",c.duration()," position=",c.position_seconds()," gain=",c.backgrounds[c.active].volume_db)
	check(c.backgrounds[c.active].playing and c.position_seconds()>0,"music playing and advances")
	for context in ["map","battle","miniboss","boss","hub"]:
		Game.music_context(context)
		await get_tree().create_timer(.8).timeout
		check(c.context==context and c.backgrounds[c.active].playing,"context plays: "+context)
	get_tree().paused=true
	var before=c.position_seconds()
	await get_tree().create_timer(.3).timeout
	check(c.position_seconds()>before,"music advances while tablet pauses gameplay")
	c.toggle_play();check(c.paused and c.backgrounds[c.active].stream_paused,"radio pause")
	c.toggle_play();check(not c.paused and not c.backgrounds[c.active].stream_paused,"radio resumes")
	get_tree().paused=false
	Game.sound_enabled=false;await get_tree().process_frame
	Game.sound_enabled=true;await get_tree().process_frame
	check(c.backgrounds[c.active].playing,"audio resumes after enable")
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(.4).timeout
		check(AudioServer.get_bus_peak_volume_left_db(0,0)>-75,"nonzero output signal")
	c.queue_free();await get_tree().process_frame
	print("AUDIO RECOVERY: ",failures," failures")
	get_tree().quit(failures)
