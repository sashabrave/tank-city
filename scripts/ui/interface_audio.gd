extends Node
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(bind_later)
	bind_tree(get_tree().root)
func bind_tree(node:Node):
	bind_later(node)
	for child in node.get_children():bind_tree(child)
func bind_later(node:Node):
	if node is BaseButton:call_deferred("bind_button",node)
	elif node is Slider:node.drag_ended.connect(func(changed):if changed:Game.sound("ui_confirm",self))
func bind_button(button):
	if not is_instance_valid(button) or button.has_meta("ui_audio_bound"):return
	button.set_meta("ui_audio_bound",true)
	button.mouse_entered.connect(func():Game.sound("ui_denied" if button.disabled else "ui_hover",self))
	button.focus_entered.connect(func():Game.sound("ui_hover",self))
	button.pressed.connect(func():Game.sound("ui_back" if button.text in ["×","Закрыть","Назад","Отмена"] else "ui_confirm",self))
