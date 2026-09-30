extends Node
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var main=load("res://scenes/main.tscn").instantiate();add_child(main)
	for target in [7,16]:
		main.test_jump(target,true)
		var arena=main.run_arena;arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.player.set_physics_process(false)
		var replay=arena.replay;var count=0
		while is_instance_valid(replay) and not replay.is_queued_for_deletion() and count<100:
			count+=1
			var event=replay.events[replay.cursor-1]
			match event.type:
				"upgrade":arena.apply_upgrade("health")
				"chest":arena.choose_recipe_card(2)
				"service":replay.open_service("vehicle",event.room);replay.service.claim(0);replay.service.completed.emit(event.room)
			await get_tree().process_frame
			await get_tree().process_frame
		if arena.room_index!=target or arena.replay!=null:push_error("Replay failed target "+str(target));get_tree().quit(1);return
		print("REPLAY09 target=",target," rewards=",count," passed")
	main.queue_free();await get_tree().process_frame;get_tree().quit()
