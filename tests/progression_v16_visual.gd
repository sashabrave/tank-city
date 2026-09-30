extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	var gallery=load("res://scripts/ui/class_gallery.gd").new();add_child(gallery)
	await get_tree().create_timer(.35).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/v16_classes.png")
	gallery.detail("recruit")
	await get_tree().create_timer(.2).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/v16_class_detail.png")
	gallery.queue_free();await get_tree().process_frame
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	await get_tree().create_timer(4.5).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/v16_empty_hud.png")
	arena.queue_free();await get_tree().process_frame
	Game.credits=10000;Game.buy_first_class_skill("recruit");Game.class_levels.recruit=5;Game.buy_class_slot("recruit")
	Game.built_workshops=["character","headquarters"];assert(Game.unlock_or_equip_ability("barrier"));assert(Game.equip_hq("hq_medbay"))
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	await get_tree().create_timer(4.5).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/v16_four_hud.png")
	print("PASS visual fixtures: zero and four slots, class gallery")
	get_tree().quit()
