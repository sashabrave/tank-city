extends Node3D
## Probe: window shot of a service room (arg: branch), /tmp/r13-service-<branch>.png.
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	var branch=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "vehicle"
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.begin_room(1)
	await get_tree().process_frame;remove_child(arena)
	var room=load("res://scripts/service_room.gd").new();room.arena=arena;room.branch=branch;add_child(room)
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-service-%s.png" % branch)
	get_tree().quit()
