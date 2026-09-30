extends Node
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.new_recipes.clear()
	Game.health_level=0;Game.damage_level=0;Game.mobility_level=0;Game.pressure_level=0
	Game.credits=10000;Game.class_levels={"recruit":2};Game.camp_level=2
	for branch in ["health","health","damage","mobility","pressure"]:assert(Game.purchase(branch))
	assert(Game.character_level()==5)
	assert(Game.shell_refund()==10000-Game.credits)
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(.6).timeout
	hub.show_classes()
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/shell-level.png")
	var returned=Game.reset_shell()
	assert(returned>0 and Game.credits==10000 and Game.character_level()==0)
	assert(Game.class_levels=={"recruit":2} and Game.camp_level==2)
	assert(Game.reset_shell()==0 and Game.credits==10000)
	assert(Game.purchase("health") and Game.character_level()==1 and Game.credits==9971)
	print("PASS shell total, full refund, repeat reset, preserved upgrades, repurchase")
	get_tree().quit()
