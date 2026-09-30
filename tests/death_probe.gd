extends Node
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=true
	var main=load("res://scripts/main.gd").new();add_child(main);await get_tree().process_frame
	main.start_run();main.enter_room(0);var arena=main.run_arena;arena.auto_pause_enabled=false;arena.phase="combat"
	arena.player.invulnerable=0;arena.player.take_damage(100000)
	await get_tree().create_timer(.5).timeout
	main.show_hub();await get_tree().create_timer(.3).timeout
	print("DEATH RETURN DONE");get_tree().quit()
