extends Node3D
func _ready():call_deferred("run")
func shot(name):
	if DisplayServer.get_name()=="headless":return
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/command_center/"+name+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	assert(Game.progression.has_news());Game.progression.mark_seen();assert(not Game.progression.has_news())
	Game.progression.telegram_result="Оперштаб: приказ не выполнен.";assert(not Game.progression.has_news())
	Game.progression.event("extracted",30);assert(Game.progression.has_news())
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(.3).timeout;shot("hub")
	hub.show_command();hub.build_menu.tab=1;hub.build_menu.refresh()
	await get_tree().create_timer(.2).timeout;shot("quests")
	hub.queue_free();await get_tree().process_frame
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.phase="combat";arena.set_physics_process(false)
	arena.add_trench(arena.player.cell);arena.player.occupying_trench=true;arena.player.hidden_in_trench=true
	await get_tree().create_timer(.3).timeout;shot("trench")
	var compact=false
	for prompt in get_tree().get_nodes_in_group("world_interaction_prompts"):
		if prompt.context==arena and prompt.panel.visible and prompt.panel.scale.x<.5:compact=true
	assert(compact)
	arena.player.hidden_in_trench=false;arena.player.invulnerable=0;arena.player.take_damage(999)
	await get_tree().create_timer(.3).timeout
	assert(arena.phase=="result" and arena.player==null)
	print("HUB V11 PASS: notices, compact trench prompt, real death")
	get_tree().quit()
