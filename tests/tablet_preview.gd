extends Node
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	var mode=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "editor"
	if mode=="card":
		var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena);arena.process_mode=Node.PROCESS_MODE_DISABLED
		var layer=CanvasLayer.new();layer.layer=200;add_child(layer)
		for i in range(2):
			var data=arena.reward.upgrade_card({"id":"intercept" if i==0 else "weapon_intercept","tier":1})
			preload("res://scripts/ui/choice_card.gd").create(layer,Vector2(390+i*310,250),Vector2(280,320),data,func():pass)
		await get_tree().create_timer(1.2).timeout;await RenderingServer.frame_post_draw
		if DisplayServer.get_name()!="headless":get_viewport().get_texture().get_image().save_png("/tmp/tablet-card.png")
		get_tree().quit();return
	var view=load("res://scripts/ui/field_tablet.gd").new();view.tab="guide" if mode in ["editor","tree","tree_compact"] else mode;add_child(view)
	if mode in ["tree","tree_compact"]:
		view.dev_edit=true;view.nav_collapsed=mode=="tree_compact";view.guide_expanded={"Бой":true,"Основы":true};view.guide_category="Бой";view.guide_section="Характеристики";view.refresh()
	if mode=="editor":
		view.dev_edit=true;view.refresh()
		var entry=Texts.document.articles.filter(func(e):return e.term=="pressure")[0]
		preload("res://scripts/ui/encyclopedia_editor.gd").open(view,entry.id)
	await get_tree().create_timer(.6).timeout
	if DisplayServer.get_name()!="headless":RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/tablet-"+mode+".png")
	print("PASS visual "+mode);get_tree().quit()
