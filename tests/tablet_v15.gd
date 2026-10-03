extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="paused"
	arena.pending_recipes=[{"category":"weapon","id":"smg"}]
	Game.music_controller=load("res://scripts/music_controller.gd").new();Game.add_child(Game.music_controller);Game.music_controller.context="battle"
	var layer=CanvasLayer.new();layer.layer=110;add_child(layer)
	await get_tree().create_timer(.7).timeout
	var view=load("res://scripts/ui/field_tablet.gd").new();view.arena=arena;view.tab="inventory";layer.add_child(view)
	for tab in ["inventory","fighter","quests","notifications","music","settings"]:
		view.tab=tab;view.refresh();await get_tree().create_timer(.12).timeout
		if DisplayServer.get_name()!="headless":RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/tablet_"+tab+".png")
	for filter in ["all","general","institute","operations","completed"]:
		view.tab="quests";view.quest_filter=filter;view.refresh()
	view.manage=true;view.quest_filter="operations";view.refresh()
	view.manage=false;view.tab="inventory";view.refresh()
	# Gear screen v2 (T-113): 8 backpack cells, 4 open at start, 4 locked; a tap selects a cell.
	var cells=view.find_children("*","Button",true,false).filter(func(b):return b is GearCell and b.key.begins_with("bag:"))
	assert(cells.size()==Backpack.CELLS and cells.filter(func(b):return b.disabled).size()==Backpack.CELLS-Backpack.capacity(),"Locked backpack cells at start")
	cells[0].pressed.emit();assert(preload("res://scripts/ui/gear_page.gd").selected=="bag:0","Tap selects a cell")
	view.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll=view.content.find_children("*","ScrollContainer",true,false)[0];scroll.scroll_vertical=350
	await get_tree().create_timer(.12).timeout
	assert(scroll.scroll_vertical>0,"Inventory scroll reaches second row and resources")
	if DisplayServer.get_name()!="headless":RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/tablet_bag.png")
	Game.backpack_slots=6;view.refresh();assert(view.find_children("*","Button",true,false).filter(func(b):return "Закрытая ячейка" in b.tooltip_text).is_empty())
	view.arena=null
	for tab in ["inventory","fighter","settings"]:view.tab=tab;view.refresh()
	print("TABLET V15 PASS");get_tree().quit()
