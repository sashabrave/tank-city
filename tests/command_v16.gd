extends Node
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	# Saved tablet memory (tab, quest filter) must not hide the quest feed.
	var memory=preload("res://scripts/ui/tablet_memory.gd");memory.loaded=true;memory.state={}
	var view=load("res://scripts/progression/command_screen.gd").new();view.tab="quests";add_child(view)
	await get_tree().create_timer(.3).timeout
	assert(view.find_children("*","Button",true,false).any(func(b):return b.text=="Принять задание"))
	if DisplayServer.get_name()!="headless":get_viewport().get_texture().get_image().save_png("/tmp/v16_command.png")
	Game.progression.accept_quest("first_alloy");view.manage=false;view.refresh()
	assert(not view.find_children("*","Button",true,false).any(func(b):return b.text=="Принять задание"))
	for tab in ["inventory","fighter","settings"]:view.tab=tab;view.refresh()
	print("PASS command acceptance and tablet readonly")
	get_tree().quit()
