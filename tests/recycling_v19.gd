extends Node3D
func _ready():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	var pending=[{"category":"weapon","id":"smg"},{"category":"weapon","id":"smg"},{"category":"weapon","id":"pistol"}]
	Game.bank_recipes(pending)
	assert(pending.is_empty() and "smg" in Game.weapon_unlocks)
	assert(Game.duplicate_recipes.size()==2 and Game.new_recipes.size()==1)
	var price=Game.duplicate_price(Game.duplicate_recipes[0]);assert(Game.sell_duplicate(0))
	assert(Game.credits==price and Game.duplicate_recipes.size()==1 and "smg" in Game.weapon_unlocks)
	assert(not Game.sell_duplicate(10))
	var total=Game.sell_all_duplicates();assert(total>0 and Game.duplicate_recipes.is_empty() and "pistol" in Game.weapon_unlocks)
	assert(Game.sell_all_duplicates()==0)
	Game.duplicate_recipes=[{"category":"weapon","id":"pistol"}]
	var snapshot=Game.serialize_progress().duplicate(true);Game.duplicate_recipes=[];Game.apply_profile(snapshot);assert(Game.duplicate_recipes.size()==1)
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);hub.set_physics_process(false)
	hub.phase="combat";hub.avatar.position=Vector3(5,0,3);hub.moving=false;hub.interact()
	assert(is_instance_valid(hub.build_menu) and hub.phase=="workshop")
	assert(not hub.root.get_node("SettingsButton").visible)
	hub.close_station();hub.queue_free()
	print("PASS recycling: duplicates on extraction, single/all sale, no repeat sale, unlock preservation, save roundtrip, hub interaction/settings hidden")
	get_tree().quit()
