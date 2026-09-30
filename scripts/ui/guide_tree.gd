extends RefCounted
var view
var box:VBoxContainer
var save_path=Texts.PATH
func _init(owner):view=owner
func build():
	box=view.scroller(Vector2(16,120),Vector2(223,403 if view.dev_edit else 443))
	box.get_parent().set_deferred("scroll_vertical",view.guide_scroll)
	box.get_parent().get_v_scroll_bar().value_changed.connect(func(value):view.guide_scroll=value)
	row("Все","",false,true)
	for category in preload("res://scripts/ui/encyclopedia_catalog.gd").all_categories():
		row(category.name,"",true,category.builtin)
		if view.guide_expanded.get(category.name,false):
			for section in category.sections:row(section.name,category.name,false,section.builtin)
			if view.dev_edit:
				var add=small_button(box,"+ Подраздел")
				add.pressed.connect(func():inline_name(add,category.name,"",true))
	if view.dev_edit:
		var add=UiKit.button(view.content,"+ Категория",Vector2(22,535),Vector2(211,30),func():inline_name(null,"","",true))
		add.add_theme_font_size_override("font_size",14)
		if view.guide_status!="":add.tooltip_text=view.guide_status
func small_button(parent,title:String)->Button:
	var button=Button.new();parent.add_child(button);Texts.set_text(button,title);button.custom_minimum_size=Vector2(0,33);button.add_theme_font_size_override("font_size",13);button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	return button
func row(title:String,parent:String,header:bool,builtin:bool):
	var line=HBoxContainer.new();box.add_child(line);line.add_theme_constant_override("separation",2)
	var button=small_button(line,title);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.clip_text=true;button.tooltip_text=title+(" · двойной клик для переименования" if view.dev_edit and title!="Все" else "")
	var active=view.guide_category==(title if parent=="" else parent) and view.guide_section==("Все подразделы" if parent=="" else title)
	button.toggle_mode=not header;button.button_pressed=active
	for state in ["normal","hover","pressed"]:
		var style=UiKit.style(Color.TRANSPARENT if header else Color("584a2c") if active else Color("242d27"),4);style.set_border_width_all(0);style.content_margin_left=3 if parent=="" else 16;style.content_margin_right=24 if header else 4;button.add_theme_stylebox_override(state,style)
	button.add_theme_color_override("font_color",UiKit.ORANGE if active else UiKit.INK)
	if header:
		var arrow=TextureRect.new();button.add_child(arrow);arrow.texture=UiKit.interface_icon("down" if view.guide_expanded.get(title,false) else "right");arrow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT);arrow.offset_left=-22;arrow.offset_right=-6;arrow.offset_top=-8;arrow.offset_bottom=8;arrow.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.pressed.connect(func():
		if button.get_meta("editing",false):return
		view.guide_category=title if parent=="" else parent;view.guide_section="Все подразделы" if parent=="" else title
		if header:view.guide_expanded[title]=not view.guide_expanded.get(title,false)
		view.refresh())
	if view.dev_edit and title!="Все":
		button.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
				button.set_meta("editing",true);button.accept_event();inline_name(line,parent,title,false))
		if not builtin:
			var remove=small_button(line,"");remove.icon=UiKit.interface_icon("delete");remove.expand_icon=true;remove.add_theme_constant_override("icon_max_width",14);remove.custom_minimum_size.x=24;remove.tooltip_text="Удалить «"+title+"»"
			remove.pressed.connect(func():confirm_delete(title,parent))
func inline_name(target,parent:String,name:String,adding:bool):
	var line=target if target is HBoxContainer else HBoxContainer.new()
	if not target is HBoxContainer:
		box.add_child(line)
		if target!=null:target.hide();box.move_child(line,target.get_index()+1)
	else:
		for child in line.get_children():line.remove_child(child);child.queue_free()
	var input=LineEdit.new();line.add_child(input);input.size_flags_horizontal=Control.SIZE_EXPAND_FILL;input.custom_minimum_size=Vector2(100,34);input.max_length=36;Texts.set_text(input,name);input.placeholder_text="Название";input.set_meta("text_editor",true)
	var ok=small_button(line,"OK");ok.custom_minimum_size.x=36
	var message=Label.new();box.add_child(message);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.add_theme_font_size_override("font_size",12);message.add_theme_color_override("font_color",Color("ef9d76"));message.hide();box.move_child(message,line.get_index()+1)
	var commit=func():
		var error=preload("res://scripts/ui/guide_categories.gd").edit("add" if adding else "rename",name,parent,input.text,save_path)
		if error!="":Texts.set_text(message,error);message.show();input.tooltip_text=error;view.guide_status=error;input.placeholder_text=error;input.add_theme_color_override("font_color",Color("ef9d76"));return
		view.guide_status=""
		if parent=="":
			if view.guide_expanded.has(name):view.guide_expanded.erase(name)
			view.guide_category=input.text.strip_edges();view.guide_section="Все подразделы";view.guide_expanded[view.guide_category]=true
		else:view.guide_category=parent;view.guide_section=input.text.strip_edges();view.guide_expanded[parent]=true
		view.refresh()
	ok.pressed.connect(commit);input.text_submitted.connect(func(_value):commit.call())
	input.grab_focus();input.select_all()
	box.get_parent().set_deferred("scroll_vertical",100000 if adding else box.get_parent().scroll_vertical)
func confirm_delete(name:String,parent:String):
	var dialog=ConfirmationDialog.new();view.add_child(dialog);dialog.title="Удалить категорию?";dialog.dialog_text="Удалить «%s»?\nСтатьи сохранятся в «%s / Без подраздела»." % [name,preload("res://scripts/ui/guide_categories.gd").fallback_category() if parent=="" else parent];dialog.ok_button_text="Удалить категорию";dialog.cancel_button_text="Отмена"
	dialog.confirmed.connect(func():
		var error=preload("res://scripts/ui/guide_categories.gd").edit("delete",name,parent,"",save_path)
		view.guide_status=error
		if error=="":view.guide_category="Все";view.guide_section="Все подразделы";view.refresh())
	dialog.add_to_group("guide_confirmation");dialog.visibility_changed.connect(func():
		if not dialog.visible:dialog.queue_free())
	dialog.popup_centered(Vector2i(480,180))
