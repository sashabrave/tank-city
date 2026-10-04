extends Control
## Reminder before leaving a card choice empty-handed (T-217): «Не взял улучшение — уйти?» with «stay» as the
## default. Used by the upgrade rooms (scripts/service_room.gd) and the captured command post (legend_stop.gd).
signal answered(leave:bool)
var heading:="Не взял улучшение"
var body:="Карточку можно взять только здесь: после отказа выбор пропадёт."
var stay_text:="Выбрать карточку"
var leave_text:="Уйти без улучшения"
static func open(parent:Control,on_leave:Callable,options:={})->Control:
	var dialog=load("res://scripts/ui/skip_confirm.gd").new();dialog.name="SkipConfirm"
	for key in options:dialog.set(key,options[key])
	parent.add_child(dialog)
	dialog.answered.connect(func(leave):if leave:on_leave.call())
	return dialog
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_to_group("selection_scope")
	var shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.55)
	var screen=get_viewport_rect().size;var width=minf(600,screen.x-32);var height=220.0
	var box=UiKit.glass(self,((screen-Vector2(width,height))*.5).round(),Vector2(width,height));box.name="Box"
	UiKit.accent(UiKit.label(box,heading,Vector2(26,22),Vector2(width-52,38),26))
	var text=UiKit.label(box,body,Vector2(26,68),Vector2(width-52,48),16,UiKit.MUTED);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var half=(width-26*2-14)*.5
	var leave=UiKit.button(box,leave_text,Vector2(26,height-26-54),Vector2(half,54),func():close(true));leave.name="Leave"
	var stay=UiKit.button(box,stay_text,Vector2(26+half+14,height-26-54),Vector2(half,54),func():close(false),true);stay.name="Stay"
	stay.focus_mode=Control.FOCUS_ALL;stay.set_meta("default_choice",true)
	(func():if is_instance_valid(stay) and stay.is_inside_tree():stay.grab_focus()).call_deferred()
func _unhandled_input(event:InputEvent):
	if event.is_action_pressed("pause"):get_viewport().set_input_as_handled();close(false)
func close(leave:bool):
	if is_queued_for_deletion():return
	Game.reset_input();queue_free();answered.emit(leave)
