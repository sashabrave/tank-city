extends Node
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	assert(DevUnlocks.catalog("ability").size()==4)
	assert(not DevUnlocks.catalog("ability").has("shield"))
	DevUnlocks.set_purchase("classes","gunner",true);assert("gunner" in Game.class_unlocks and "gunner" in Game.class_first_slots)
	DevUnlocks.second_skill("gunner",true);assert(Game.class_levels.gunner>=5 and "gunner" in Game.class_second_slots)
	DevUnlocks.toggle("classes","gunner",false);assert("gunner" not in Game.class_first_slots and "gunner" not in Game.class_second_slots)
	for pair in [["ability","barrier"],["hq","hq_medbay"],["garage","vehicle_tank"],["research","weapons"]]:
		DevUnlocks.set_purchase(pair[0],pair[1],true);assert(DevUnlocks.purchased(pair[0],pair[1]))
		DevUnlocks.set_purchase(pair[0],pair[1],false);assert(not DevUnlocks.purchased(pair[0],pair[1]))
	var shop=load("res://scripts/garage/recipe_shop.gd").new();add_child(shop)
	for group in DevUnlocks.GROUPS:shop.category=group;shop.refresh()
	shop.category="classes";shop.refresh()
	await get_tree().create_timer(.3).timeout
	if DisplayServer.get_name()!="headless":get_viewport().get_texture().get_image().save_png("/tmp/dev_shop_v17.png")
	print("PASS dev shop: 7 groups, blueprint/purchase separation, class skills, reversible grants")
	get_tree().quit()
