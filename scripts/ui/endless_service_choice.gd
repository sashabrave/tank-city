extends Control
signal selected(branch:String)
signal hub_requested
var index=2
var picked=false
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_to_group("selection_scope")
	var background=ColorRect.new();add_child(background);background.color=Color("17231f");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel=UiKit.panel(self,(get_viewport_rect().size-Vector2(1060,550))*.5,Vector2(1060,550))
	UiKit.label(panel,"Передышка между боями",Vector2(30,24),Vector2(980,45),30)
	UiKit.label(panel,"Выбери одну комнату. После улучшения — сразу в следующий бой.",Vector2(30,79),Vector2(980,58),20)
	var options=Campaign.service_options(Game.visual_run_seed,index)
	var names={"vehicle":"Полевой механик","ability":"Подготовка бойца","headquarters":"Мастерская штаба"}
	var details={"vehicle":"Улучши транспорт для следующих боёв.","ability":"Усиль способность своего бойца.","headquarters":"Выбери модуль или усиление штаба."}
	for i in options.size():
		var key=options[i]
		var card=UiKit.panel(panel,Vector2(30+i*337,150),Vector2(326,295))
		UiKit.icon(card,{"vehicle":"vehicle","ability":"shield","headquarters":"headquarters"}[key],Vector2(119,20),Vector2(88,88))
		var title=UiKit.label(card,names[key],Vector2(18,123),Vector2(290,55),22);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var detail=UiKit.label(card,details[key],Vector2(18,180),Vector2(290,50),16,UiKit.MUTED);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		UiKit.button(card,"Войти",Vector2(18,240),Vector2(290,42),func():
			if picked:return
			picked=true;selected.emit(key),true)
	UiKit.button(panel,"В хаб с наградами",Vector2(30,477),Vector2(350,46),func():hub_requested.emit())
