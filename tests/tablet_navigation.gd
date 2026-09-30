extends Node
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	var view=load("res://scripts/ui/field_tablet.gd").new();view.tab="inventory";add_child(view)
	await get_tree().process_frame
	var button=view.nav_buttons[0];var icon=button.get_node("FixedIcon");var origin=icon.global_position;var dimensions=icon.size;var content_id=view.content.get_instance_id()
	view.toggle_navigation();var previous=view.content.size.x
	for i in range(14):
		await get_tree().create_timer(.02).timeout
		assert(icon.global_position.is_equal_approx(origin) and icon.size==dimensions)
		assert(view.content.size.x>=previous-.01);previous=view.content.size.x
		assert(view.content.get_instance_id()==content_id)
	assert(is_equal_approx(view.content.size.x,932) and is_equal_approx(button.size.x,60))
	view.toggle_navigation();await get_tree().create_timer(.055).timeout
	var before=view.content.size.x;view.toggle_navigation();assert(is_equal_approx(before,view.content.size.x))
	await get_tree().create_timer(.3).timeout
	view.toggle_navigation();await get_tree().create_timer(.3).timeout
	assert(icon.global_position.is_equal_approx(origin) and is_equal_approx(button.size.x,221))
	for tab in ["settings","guide","music","fighter","quests"]:
		view.tab=tab;view.refresh();view.toggle_navigation();await get_tree().create_timer(.25).timeout
		view.toggle_navigation();await get_tree().create_timer(.25).timeout
		assert(is_equal_approx(view.content.size.x,775))
	view.tab="quests";view.refresh()
	for collapsed in [true,false]:
		if view.nav_collapsed!=collapsed:view.toggle_navigation()
		await get_tree().create_timer(.25).timeout
		var width=-1.0
		for child in view.content.get_children():
			if child is Button and child.text in ["Все","Генштаб","Институт","Оперштаб","Выполненные"]:
				if width<0:width=child.size.x
				assert(is_equal_approx(width,child.size.x))
		if DisplayServer.get_name()!="headless":RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("/tmp/quest-filter-"+str(collapsed)+".png")
	Game.notifications.post("Задание выполнено\nПроверка неподвижности текста", "Командование", "important")
	view.tab="notifications";view.refresh();await get_tree().process_frame;await get_tree().process_frame
	var cards=view.content.find_children("*","Button",true,false).filter(func(b):return b.get_script()==load("res://scripts/ui/message_card.gd"))
	assert(not cards.is_empty())
	var card=cards[0];var margin=card.get_child(0);var card_origin=margin.global_position
	card.mouse_entered.emit();card.grab_focus();await get_tree().process_frame
	assert(margin.global_position.is_equal_approx(card_origin))
	for state in ["normal","hover","pressed","disabled"]:assert(card.get_theme_stylebox(state).content_margin_left==0)
	print("PASS fixed icon geometry, continuous animation, rapid reversal and page transitions")
	get_tree().quit()
