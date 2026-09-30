extends CanvasLayer
var button:Button
var modal:Control
var hub
func _ready():
	layer=115;process_mode=Node.PROCESS_MODE_ALWAYS
	button=UiKit.button(self,"",Vector2.ZERO,Vector2(46,40),open)
	button.tooltip_text="Профили / сохранения"
	UiKit.icon(button,"fighter",Vector2(7,4),Vector2(32,32))
func _process(_delta):
	button.position=Vector2(get_viewport().get_visible_rect().size.x-62,10)
	hub=get_tree().get_first_node_in_group("profile_hub")
	button.visible=is_instance_valid(hub)
	button.disabled=not is_instance_valid(hub) or hub.phase!="combat" or is_instance_valid(modal)
	button.tooltip_text="Профили / сохранения" if is_instance_valid(hub) else "Профили можно менять в хабе"
	if Game.save_error!="":button.tooltip_text+="\n"+Game.save_error
	button.modulate=Color("ffb88d") if Game.save_error!="" else Color.WHITE
func open():
	if not is_instance_valid(hub) or hub.phase!="combat":return
	hub.phase="profiles";show_picker(false)
func open_start():show_picker(true)
func show_picker(startup:bool):
	if is_instance_valid(modal):remove_child(modal);modal.queue_free()
	Game.reset_input();modal=preload("res://scripts/ui/profile_picker.gd").new();modal.startup=startup;add_child(modal)
	modal.closed.connect(close);modal.accepted.connect(close)
func close():
	if is_instance_valid(modal):modal.queue_free()
	modal=null
	if is_instance_valid(hub) and hub.phase=="profiles":hub.phase="combat"
	Game.reset_input()
