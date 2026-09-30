extends Control
signal cancelled
signal new_run
signal continued
var checkpoint:Dictionary={}
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_to_group("selection_scope")
	var dim=ColorRect.new();add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,0,0,.6)
	var panel=UiKit.panel(self,(get_viewport_rect().size-Vector2(900,310))*.5,Vector2(900,310))
	UiKit.label(panel,"Продолжить забег?",Vector2(28,22),Vector2(780,48),30)
	UiKit.button(panel,"×",Vector2(817,20),Vector2(52,44),func():cancelled.emit())
	var place="Гигабосс" if int(checkpoint.index)==7 else "босс" if int(checkpoint.index)==6 else "поле %d / 6" % (int(checkpoint.index)+1)
	var status=("Бесконечный · сектор %d" % (int(checkpoint.cycle)+1)) if checkpoint.endless else "Мир %d · %s" % [int(checkpoint.world),Campaign.WORLDS[int(checkpoint.world)].name]
	status+="\n"+place.capitalize()+" · усилений: %d" % checkpoint.run.get("upgrade_history",[]).size()
	status+="\nКомната начнётся заново." if checkpoint.endless else "\nПродолжение с карты маршрута."
	UiKit.label(panel,status,Vector2(28,90),Vector2(844,100),20).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	UiKit.button(panel,"Нет, новый забег",Vector2(28,222),Vector2(410,58),func():new_run.emit())
	UiKit.button(panel,"Да, продолжить",Vector2(458,222),Vector2(414,58),func():continued.emit(),true)
func _unhandled_input(event):
	if event.is_action_pressed("pause"):get_viewport().set_input_as_handled();cancelled.emit()
