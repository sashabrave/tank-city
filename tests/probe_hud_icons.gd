extends Node
## Probe: battle HUD with abilities, run tokens and dropped alloy/tokens, /tmp/r13-hudicons.png.
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=31;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(4.0).timeout
	arena.run.tokens=7
	var at=arena.player.position+Vector3(1.2,0,0)
	preload("res://scripts/resource_drop.gd").spawn(arena,at,25,"alloy");preload("res://scripts/resource_drop.gd").spawn(arena,at+Vector3(0,0,1),3,"tokens")
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-hudicons.png")
	get_tree().quit()
