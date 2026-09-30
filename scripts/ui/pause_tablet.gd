extends CanvasLayer
static var opening=false
var paused_before=false
var resume:Callable
var leave:Callable
var context_arena
var initial_tab=""
static func open(context:Node,on_resume:Callable=Callable(),on_leave:Callable=Callable(),first_tab:String=""):
	if opening or not context.get_tree().get_nodes_in_group("field_tablet").is_empty():return
	opening=true
	var tablet=load("res://scripts/ui/pause_tablet.gd").new();tablet.resume=on_resume;tablet.leave=on_leave;tablet.initial_tab=first_tab
	if context.get("run")!=null:tablet.context_arena=context
	elif context.get("arena")!=null:tablet.context_arena=context.arena
	elif context.get("run_context")!=null:tablet.context_arena=context.run_context
	context.get_tree().root.add_child.call_deferred(tablet)
func _ready():
	opening=false
	layer=110;process_mode=Node.PROCESS_MODE_ALWAYS;add_to_group("field_tablet")
	paused_before=get_tree().paused;get_tree().paused=true;Game.reset_input()
	var view=preload("res://scripts/ui/field_tablet.gd").new();view.arena=context_arena;view.tab=initial_tab;view.can_leave=leave.is_valid();view.can_restart=is_instance_valid(context_arena) and context_arena.is_inside_tree() and context_arena.phase=="paused" and Game.run_checkpoint.get("mode","")=="room";add_child(view);view.closed.connect(close)
	view.restart_requested.connect(func():close(false);context_arena.restart_requested.emit())
	view.exit_requested.connect(func():
		if leave.is_valid():close(false);leave.call()
		else:close())
func _input(event):
	if get_tree().get_nodes_in_group("guide_confirmation").any(func(d):return d.visible):return
	for child in get_children():
		if child.get("waiting_key")!=null and child.waiting_key!="":return
	if event.is_action_pressed("pause") and not event.is_echo():get_viewport().set_input_as_handled();close()
func close(with_resume:bool=true):
	get_tree().paused=paused_before;Game.reset_input();queue_free()
	if with_resume and resume.is_valid():resume.call()
