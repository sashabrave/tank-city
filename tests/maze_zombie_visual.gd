extends Node3D
## A maze zombie lit next to the soldier. /tmp/r13-zombie.png
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.sandbox=true;arena.sandbox_mode="maze";arena.sandbox_difficulty=1;arena.run_seed=11;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.2).timeout
	var z=arena.challenges.zombies[0];z.position=arena.room.player.position+Vector3(1.2,0,-.8)
	for i in range(20):arena.challenges.tick_zombies(.03);await get_tree().process_frame
	arena.set_physics_process(false)
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-zombie.png")
	get_tree().quit(0)
