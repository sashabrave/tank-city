extends Node
## Tester hotkeys, everywhere in the game: F8 — new task with a screenshot of this moment, F9 — the board.
## The screenshot is taken before the form appears, so it shows the game, not the form.
func _ready():process_mode=Node.PROCESS_MODE_ALWAYS
func _input(event):
	if not (event is InputEventKey and event.pressed and not event.echo):return
	if event.keycode not in [KEY_F8,KEY_F9] or get_tree().root.has_node("TaskBoardView"):return
	get_viewport().set_input_as_handled()
	var shot:Image=null
	if event.keycode==KEY_F8 and DisplayServer.get_name()!="headless":shot=get_viewport().get_texture().get_image()
	preload("res://scripts/ui/task_board_view.gd").open(get_tree(),"add" if event.keycode==KEY_F8 else "board",shot)
