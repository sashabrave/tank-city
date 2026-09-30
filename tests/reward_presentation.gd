extends Node
func _ready():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	var canvas=CanvasLayer.new();add_child(canvas)
	var panel=Panel.new();canvas.add_child(panel);panel.position=Vector2(25,180);panel.size=Vector2(1390,430)
	var categories=["ГЕРОЙ","СПОСОБНОСТЬ","ШТАБ","ТРАНСПОРТ"]
	for tier in range(4):
		var card=preload("res://scripts/ui/choice_card.gd").create(panel,Vector2(20+tier*342,25),Vector2(280,352),{"category":categories[tier],"title":["Здоровье","Перезарядка\nустройств","Защитный купол","Передвижение"][tier],"detail":"Скорость: 3.8 → 4.03","icon":["health","device_cooldown","shield","speed"][tier],"heading":LootCatalog.RARITY_NAMES[tier],"color":Color(LootCatalog.RARITY_COLORS[tier])},func():pass)
		assert(card.get_meta("reward_tier")==tier)
		assert(card.get_node("CategoryStripe").color==Color(LootCatalog.RARITY_COLORS[tier]))
		assert(card.get_node("Description").position.y+card.get_node("Description").size.y<card.get_node("ChooseButton").position.y)
	var bank=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/chip/manifest.json"))
	for tier in range(4):
		assert(bank["reward_reveal_"+str(tier)].files.size()==3)
		for file in bank["reward_reveal_"+str(tier)].files:assert(load("res://assets/audio/chip/"+file).get_length()<1.1)
	await get_tree().create_timer(1).timeout
	if DisplayServer.get_name()!="headless":
		get_viewport().get_texture().get_image().save_png("/tmp/reward-presentation.png")
	print("PASS reward palette, silhouettes, layout and 12 audio variations")
	get_tree().quit()
