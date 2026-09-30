extends Node3D
var failures=0
func check(ok,message):
	if not ok:failures+=1;push_error(message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	check(Game.research_unlocks==["character"],"starter bench recipe")
	Game.set_recipe_unlocked("research","character",false)
	check("character" in Game.research_unlocks,"starter recipe cannot be closed")
	Game.credits=10000;Game.build_workshop("character")
	var price=Game.cost("health");var before=Game.credits
	Game.purchase("health")
	check(Game.health_upgrade_bonus()==2 and Game.credits==before-price,"health purchase doubles HP contribution")
	check(price==ceili(2*Balance.CONFIG.economy.upgrade_base_cost*1.2),"health price includes economy increase")
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	check(arena.soldier_max_hp==Balance.CONFIG.combat.hero_health+2,"combat receives purchased health")
	arena.queue_free();await get_tree().process_frame
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);hub.set_physics_process(false)
	Game.built_workshops.append("weapons");hub.open_workshop(true)
	for card in hub.weapon_station.get_children():
		if card.has_meta("weapon_card") and card.get_node("Title").text!="Пистолет":
			check(not card.tooltip_text.contains("урона"),"locked weapon hides stat tooltip")
			for child in card.get_children():check(not child.get_script()==load("res://scripts/ui/stat_bars.gd"),"locked weapon hides bars")
	hub.close_station();hub.avatar.position=Vector3(0,0,0)
	await get_tree().create_timer(.4).timeout
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/environment_v7/interaction_prompt.png")
	print("ONBOARDING: %d failures" % failures);get_tree().quit(failures)
