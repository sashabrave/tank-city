extends CanvasLayer
var previous:Dictionary={}
var messages:Array=[]
var delay=0.0
var showing=false
func _ready():layer=105;process_mode=Node.PROCESS_MODE_ALWAYS
func _process(delta):
	delay-=delta
	if delay>0:return
	delay=.25
	var p=Game.progression;var ready={};var assigned={}
	for q in p.quests():
		assigned[q.id]=q.text
		if p.count(q)>=q.goal:ready[q.id]=q.text
	var state={"id":p.get_instance_id(),"serial":p.outcome_serial,"ready":ready,"assigned":assigned,"telegram":p.telegram_result,"done":not p.telegram.is_empty() and p.telegram.progress>=p.telegram.goal}
	if not previous.is_empty() and previous.id==state.id:
		for id in assigned:
			if id not in previous.assigned:messages.append("Новое задание\n"+assigned[id])
		for id in ready:
			if id not in previous.ready:messages.append("Задание выполнено\n"+ready[id])
		if state.serial!=previous.serial and "не выполнен" in state.telegram:messages.append("Приказ не выполнен")
	previous=state
	if not showing and not messages.is_empty():show_message(messages.pop_front())
func show_message(text:String):
	Game.notifications.post(text,"Командование","important")
