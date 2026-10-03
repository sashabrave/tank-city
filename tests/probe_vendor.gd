extends Node3D
## Probe: merchant room with the ammo machine, and its result window. /tmp/r13-vendor-room.png, -result.png.
func _ready():call_deferred("run")
func shot(p):
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(p)
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	get_window().size=Vector2i(1280,720)
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.begin_room(1)
	await get_tree().process_frame;remove_child(arena)
	var room=load("res://scripts/merchant_room.gd").new();room.arena=arena;room.index=2;add_child(room)
	await get_tree().create_timer(1.4).timeout;await shot("/tmp/r13-vendor-room.png")
	arena.run.tokens=12;arena.run.combat_rng.seed=77
	room.vendor.open(room.root,func():pass)
	await get_tree().create_timer(.5).timeout;await shot("/tmp/r13-vendor-result.png")
	get_tree().quit()
