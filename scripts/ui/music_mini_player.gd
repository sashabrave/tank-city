extends PanelContainer
var play:Button
var repeat_button:Button
var shuffle_button:Button
var row_node:HBoxContainer
var seek_bar:HSlider
var dragging=false
var time_label:Label
var controller
func _ready():
	row_node=$Row
	process_mode=Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel",UiKit.style(Color("e6e8dc"),12,Color("b1b9a7")))
	controller=Game.music_controller
	play=control("▶",func():controller.toggle_play());row_node.move_child(play,1)
	repeat_button=control("↻",func():controller.cycle_repeat())
	shuffle_button=control("⇄",func():controller.toggle_shuffle())
	# Transport together on the left (previous · play · next), the title in the middle, modes on the right.
	row_node.move_child(row_node.get_node("Next"),2)
	for button in [row_node.get_node("Previous"),row_node.get_node("Next"),play,repeat_button,shuffle_button]:
		button.add_theme_color_override("font_color",UiKit.INK)
		button.add_theme_stylebox_override("normal",UiKit.style(UiKit.CREAM,10,Color("adb6a4")))
		button.add_theme_stylebox_override("hover",UiKit.style(Color("ffd080"),10,UiKit.ORANGE))
		button.add_theme_stylebox_override("pressed",UiKit.style(UiKit.ORANGE,10))
	row_node.get_node("Previous").pressed.connect(func():move_track(-1))
	row_node.get_node("Next").pressed.connect(func():move_track(1))
	if is_instance_valid(controller):controller.track_changed.connect(refresh)
	var column=VBoxContainer.new();var row=$Row;remove_child(row);add_child(column);column.add_child(row)
	var seek_row=HBoxContainer.new();column.add_child(seek_row)
	seek_bar=HSlider.new();seek_row.add_child(seek_bar);seek_bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;seek_bar.step=.1;seek_bar.tooltip_text="Перемотка"
	time_label=Label.new();seek_row.add_child(time_label);time_label.custom_minimum_size.x=95;time_label.add_theme_font_size_override("font_size",12)
	seek_bar.drag_started.connect(func():dragging=true)
	seek_bar.drag_ended.connect(func(changed):dragging=false;if changed:controller.seek(seek_bar.value))
	seek_bar.value_changed.connect(func(value):if not dragging and seek_bar.has_focus():controller.seek(value))
	refresh()
func _process(_delta):
	if seek_bar==null or not is_instance_valid(controller):return
	seek_bar.max_value=maxf(1,controller.duration())
	if not dragging:seek_bar.set_value_no_signal(controller.position_seconds())
	var current=int(seek_bar.value);var total=int(controller.duration())
	Texts.set_text(time_label,"%d:%02d / %d:%02d" % [current/60,current%60,total/60,total%60])
func control(text:String,callback:Callable)->Button:
	var button=Button.new();Texts.set_text(button,text);button.custom_minimum_size=Vector2(44,44);button.focus_mode=Control.FOCUS_NONE;button.pressed.connect(callback);row_node.add_child(button);return button
func move_track(direction:int):
	if is_instance_valid(controller):controller.skip(direction)
func set_icon(button:Button,id:String):
	Texts.set_text(button,"");button.icon=UiKit.interface_icon(id);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",20)
func refresh():
	var available=is_instance_valid(controller) and controller.context!=""
	row_node.get_node("Previous").disabled=not available;play.disabled=not available;repeat_button.disabled=not available;shuffle_button.disabled=not available;row_node.get_node("Next").disabled=not available
	set_icon(row_node.get_node("Previous"),"previous");set_icon(row_node.get_node("Next"),"next");set_icon(play,"play");set_icon(repeat_button,"repeat");set_icon(shuffle_button,"shuffle")
	if available:
		set_icon(play,"play" if controller.paused else "pause");play.tooltip_text="Воспроизвести" if controller.paused else "Пауза"
		Texts.set_text(repeat_button,"1" if controller.repeat_mode==1 else "");repeat_button.modulate=UiKit.ORANGE if controller.repeat_mode>0 else Color.WHITE;repeat_button.tooltip_text=["Без повтора","Повторять один","Повторять все"][controller.repeat_mode]
		shuffle_button.modulate=UiKit.ORANGE if controller.shuffle else Color.WHITE;shuffle_button.tooltip_text="Перемешивание включено" if controller.shuffle else "По порядку"
	row_node.get_node("Info/Title").text=controller.title() if available else "Музыка"
	row_node.get_node("Info/Context").text=controller.subtitle() if available else "Подборка появится в игре"
