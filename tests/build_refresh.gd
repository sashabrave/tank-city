extends Node
var missing_english:Dictionary={}
func _ready():call_deferred("run")
func shot(name):
	await get_tree().process_frame
	NumberDisplay.refresh()
	if "--english" in OS.get_cmdline_user_args():
		var regex=RegEx.new();regex.compile("[А-Яа-яЁё]")
		for node in get_tree().get_nodes_in_group("number_display"):
			if node.is_visible_in_tree() and regex.search(node.text):missing_english[node.get_meta("text_source",node.text)]=true
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(.25).timeout;RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/build-"+name+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	if "--english" in OS.get_cmdline_user_args():Settings.change("language","en")
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	var hub=main.current;hub.phase="combat";hub.root.show()
	for id in Game.BUILD_COST:
		if id not in Game.research_unlocks:Game.research_unlocks.append(id)
	var old_credits=Game.credits;var old_insurance=Game.progression.insurance;var old_level=Game.progression.level
	Game.credits=10000;Game.progression.level=1;Game.progression.insurance=0
	var insurance_price=Game.insurance_cost();assert(Game.buy_insurance());assert(Game.credits==10000-insurance_price);assert(is_equal_approx(Game.death_loss_fraction(),.35))
	assert(Game.buy_insurance());assert(not Game.buy_insurance())
	Game.credits=old_credits;Game.progression.insurance=old_insurance;Game.progression.level=old_level
	var sample=TextureRect.new();UiKit.locked_preview(sample,true);assert(sample.material is ShaderMaterial);UiKit.locked_preview(sample,false);assert(sample.material==null);sample.free()
	var catalog=preload("res://scripts/ui/build_catalog.gd")
	assert(catalog.image("garage") is AtlasTexture)
	Game.progression.seen.erase("build:weapons");assert(catalog.fresh("weapons"));catalog.mark("weapons");assert(not catalog.fresh("weapons"))
	for i in range(3):hub.build_tab=i;hub.show_build_menu();await shot("tab"+str(i))
	hub.close_station()
	for id in Game.BUILD_COST:
		if id not in Game.built_workshops:Game.built_workshops.append(id)
	hub.open_workshop(true);await shot("weapons");hub.close_station();hub.open_workshop(false,true);await shot("bonuses");hub.close_station()
	hub.close_station();hub.open_workshop(false)
	for i in range(5):hub.workshop_tab=i;hub.refresh();await shot("character"+str(i))
	hub.close_station();hub.show_classes();await shot("fighter-shell")
	hub.show_class_catalog();await shot("fighter-classes");hub.close_station()
	var layer=CanvasLayer.new();layer.layer=110;add_child(layer)
	var view=load("res://scripts/ui/field_tablet.gd").new();view.tab="inventory";layer.add_child(view)
	for tab in ["inventory","fighter","settings","quests","guide","about","notifications","music","base"]:
		for collapsed in [false,true]:
			view.tab=tab;view.nav_collapsed=collapsed;view.refresh();await get_tree().process_frame
			assert(view.content.size.x==(932 if collapsed else 775))
			if tab in ["inventory","settings","base"]:await shot(tab+str(collapsed))
	view.queue_free();main.queue_free();await get_tree().process_frame
	if "--english" in OS.get_cmdline_user_args():
		var file=FileAccess.open("/tmp/ui-missing-source.txt",FileAccess.WRITE);file.store_string("\n".join(missing_english.keys()))
	print("PASS build tabs, discovery read state, atlas mapping, workshops and all tablet widths")
	get_tree().quit()
