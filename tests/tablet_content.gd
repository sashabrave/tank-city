extends Node
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.values.language="ru";Settings.apply()
	var catalog=preload("res://scripts/ui/encyclopedia_catalog.gd")
	assert(catalog.entries().size()>=50)
	assert(catalog.search("ЛЕД").size()>0 and catalog.search("напор столкновение").size()>0)
	assert(catalog.search("несуществующаястрока").is_empty())
	assert(catalog.search("","Враги","Пехота").size()==4)
	var original=Texts.document.duplicate(true);var draft=original.duplicate(true)
	draft.terms.pressure.name="Импульс";draft.terms.pressure.description="Тестовое общее описание."
	var label=Label.new();add_child(label);label.text="Напор 40%";Texts.update_widget(label)
	assert(Texts.save_document(draft,"/tmp/tank-city-texts-test.json")=="")
	Texts.update_widget(label);assert(label.text=="Импульс 40%")
	label.text="Напор 55%";Texts.update_widget(label);assert(label.text=="Импульс 55%")
	assert(Texts.render("НАПОР / напор / напористый")=="Импульс / импульс / напористый")
	assert(Texts.render("{{pressure.description}}") == "Тестовое общее описание.")
	assert(JSON.parse_string(FileAccess.get_file_as_string("/tmp/tank-city-texts-test.json")).terms.pressure.name=="Импульс")
	Texts.document=original;Texts.rebuild();Texts.update_widget(label);assert(label.text=="Напор 55%")
	var bad=original.duplicate(true);bad.terms.pressure.name="";assert(Texts.validate(bad)!="")
	label.queue_free()
	var view=load("res://scripts/ui/field_tablet.gd").new();view.tab="guide";view.can_restart=true;add_child(view)
	await get_tree().process_frame
	view.guide_query="напор";view.render_guide();assert(view.guide_box.get_child_count()>0)
	var search=view.content.get_node("GuideSearch");search.grab_focus()
	for key in [KEY_W,KEY_SPACE,KEY_E]:
		var event=InputEventKey.new();event.physical_keycode=key;event.keycode=key;event.unicode=key;event.pressed=true
		CardNavigation._input(event);assert(search.has_focus())
	view.guide_query="";view.refresh()
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(.3).timeout;RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png("/tmp/tablet-guide.png")
	for tab in ["Видео","Звук","Управление","Интерфейс"]:
		view.tab="settings";view.settings_tab=tab;view.refresh();await get_tree().process_frame
		assert(view.content.get_child_count()>5)
		if DisplayServer.get_name()!="headless" and tab=="Видео":
			await get_tree().create_timer(.3).timeout;RenderingServer.force_draw()
			get_viewport().get_texture().get_image().save_png("/tmp/tablet-settings.png")
	view.tab="about";view.refresh();await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(.3).timeout;RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png("/tmp/tablet-about.png")
	view.tab="guide";view.dev_edit=true;view.refresh()
	var entry=catalog.entries().filter(func(e):return e.term=="pressure")[0]
	preload("res://scripts/ui/encyclopedia_editor.gd").open(view,entry.id)
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(.3).timeout;RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png("/tmp/tablet-editor.png")
	var editor=view.get_child(view.get_child_count()-1)
	editor.save_path="/tmp/tank-city-editor-test.json"
	editor.fields.term_name.text="Импульс";editor.fields.description.text="Новое описание из редактора.";editor.save()
	assert(Texts.term_name("pressure")=="Импульс")
	assert(JSON.parse_string(FileAccess.get_file_as_string(editor.save_path)).terms.pressure.name=="Импульс")
	Texts.document=original;Texts.rebuild()
	print("PASS encyclopedia search/categories, shared term live rename and restore, disk save/read, validation, typing focus, all settings tabs, about and editor")
	get_tree().quit()
