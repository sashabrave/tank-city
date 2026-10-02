extends Node3D
func _ready():call_deferred("run")
func shot(name):
	if DisplayServer.get_name()=="headless":return
	RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/command_center/"+name+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	assert(Game.progression.has_news());Game.progression.mark_seen();assert(not Game.progression.has_news())
	Game.progression.telegram_result="Оперштаб: приказ не выполнен.";assert(not Game.progression.has_news())
	# Quest progress counts only after the quest is taken (0.7).
	Game.progression.accept_quest("first_alloy");Game.progression.mark_seen();Game.progression.event("extracted",30);assert(Game.progression.has_news())
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(.3).timeout;shot("hub")
	hub.show_command();hub.build_menu.tab="quests";hub.build_menu.refresh()
	await get_tree().create_timer(.2).timeout;shot("quests")
	hub.queue_free();await get_tree().process_frame
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.phase="combat";arena.set_physics_process(false)
	arena.add_trench(arena.player.cell);arena.player.occupying_trench=true;arena.player.hidden_in_trench=true
	await get_tree().create_timer(.3).timeout;shot("trench")
	# Trench hint is one small fixed chip under the cell: «Выйти» and the crouch key while inside.
	var compact=false
	for hint in arena.find_children("*","Node3D",true,false):
		if hint.get_script()==preload("res://scripts/trench_hints.gd") and hint.cell==arena.player.cell:compact=hint.chip.visible and hint.crouch.visible and is_equal_approx(hint.chip.size.y,hint.HEIGHT) and hint.chip.size.x<260
	assert(compact)
	# The first lethal hit of a run leaves 1 HP once (mercy); the next one is a real death.
	arena.player.hidden_in_trench=false;arena.player.invulnerable=0;arena.player.take_damage(999)
	assert(arena.player!=null and is_equal_approx(arena.player.hp,1.0) and arena.run.mercy_used)
	arena.player.invulnerable=0;arena.player.take_damage(999)
	await get_tree().create_timer(.3).timeout
	assert(arena.phase=="result" and arena.player==null)
	print("HUB V11 PASS: notices, compact trench prompt, real death")
	get_tree().quit()
