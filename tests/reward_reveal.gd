extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena)
	arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="upgrade"
	arena.upgrade_offers=[{"id":"health","tier":0},{"id":"device_cooldown","tier":1},{"id":"speed","tier":2}]
	arena.hud._show_upgrades_now()
	var panel=arena.hud.modal.get_node("Panel")
	assert(CardNavigation.transition_locked)
	assert(panel.get_node("Card1/ChooseButton").disabled)
	await get_tree().create_timer(.25).timeout
	assert(panel.get_node("Card1").modulate.a>panel.get_node("Card3").modulate.a)
	assert(panel.get_node("Card1/ChooseButton").modulate.a==0)
	await get_tree().create_timer(.85).timeout
	assert(not CardNavigation.transition_locked)
	assert(not panel.get_node("Card1/ChooseButton").disabled)
	assert(panel.get_node("Card3/ChooseButton").modulate.a==1)
	if DisplayServer.get_name()!="headless":get_viewport().get_texture().get_image().save_png("/tmp/reward-reveal.png")
	arena.hud._show_upgrades_now();arena.hud.close_modal()
	assert(not CardNavigation.transition_locked)
	print("PASS staggered reveal, delayed buttons, input lock and cancellation")
	get_tree().quit()
