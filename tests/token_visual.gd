extends Node3D
## Tokens: bright paw coins, slow fall, sparkle. Window shot /tmp/r13-tokens.png.
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=8;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.2).timeout
	for i in range(4):preload("res://scripts/resource_drop.gd").spawn(arena,arena.world_pos(arena.player.cell+Vector2i(i-1,-3)),1,"tokens")
	await get_tree().create_timer(.45).timeout
	arena.set_physics_process(false)
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-tokens.png")
	get_tree().quit(0)
