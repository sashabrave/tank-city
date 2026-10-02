extends Node3D
## All field bonuses in a row on a real field: shape, colour and glow. Window shot /tmp/r13-bonuses.png.
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=8;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.2).timeout;arena.set_physics_process(false)
	var ids=LootCatalog.BONUSES.keys();var row=int(arena.grid_size/2)
	for i in range(ids.size()):
		var holder=Node3D.new();arena.add_child(holder);holder.position=arena.world_pos(Vector2i(1+i,row))
		LootCatalog.visual(holder,ids[i])
	print("BONUSES ",ids)
	await get_tree().create_timer(.6).timeout
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-bonuses.png")
	get_tree().quit(0)
