extends Node
var arena
var main
var target=7
var events:Array=[]
var cursor=0
var last_build:Array=[]
var service
func _ready():
	for room in range(target):
		if room not in Campaign.BOSSES:
			for wave in range(2):events.append({"type":"upgrade","room":room,"wave":wave})
		events.append({"type":"chest","room":room})
		if room not in Campaign.BOSSES:events.append({"type":"upgrade","room":room,"wave":2})
		if room+1 in Campaign.SERVICES:events.append({"type":"service","room":room+1})
	if arena.presentation.text_tween:arena.presentation.text_tween.kill()
	arena.presentation.heading.modulate.a=0;arena.presentation.caption.modulate.a=0
	arena.replay=self;arena.phase="paused";arena.spawn_queue.clear();next()
func next():
	if is_instance_valid(service):service.queue_free();service=null;arena.show();arena.hud.show()
	if cursor>=events.size():
		var progress=arena.hud.root.get_node_or_null("ReplayProgress")
		if progress:progress.queue_free()
		arena.replay=null;arena.hud.close_modal();arena.begin_room(target);queue_free();return
	var event=events[cursor];cursor+=1;arena.room_index=event.room;arena.boss_room=event.room in Campaign.BOSSES
	match event.type:
		"upgrade":
			arena.wave=event.wave;arena.next_is_room=event.wave==2;arena.reward_claimed=false;arena.upgrade_offers.clear();arena.phase="upgrade";arena.hud.show_upgrades()
		"chest":
			arena.phase="combat";arena.drop_recipe(arena.player.cell,{"elite":RoutePlan.chosen(RoutePlan.build(arena.run_seed),event.room,arena.run.route_choices).elite});arena.open_recipe_draft(arena.pickups.back())
		"service":
			arena.phase="paused"
			var panel=arena.hud.modal_base("Тест · повтор наград","Передышка после этапа %d" % event.room,"Выбери механику или способность, как на маршруте.",340)
			var choices=Campaign.service_options(arena.run_seed,event.room)
			for i in range(2):
				var branch=choices[i]
				UiKit.button(panel,{"vehicle":"Механик","ability":"Способность","headquarters":"Штаб"}[branch],Vector2(30+i*435,215),Vector2(410,60),func():open_service(branch,event.room),i==1)
	var root=arena.hud.root
	var old=root.get_node_or_null("ReplayProgress")
	if old:old.queue_free()
	var info=UiKit.label(root,"Тест: награда %d / %d · целевой этап %d" % [cursor,events.size(),target+1],Vector2(300,5),Vector2(850,35),18);info.name="ReplayProgress"
func open_service(branch:String,index:int):
	if branch=="ability" and arena.abilities.slots.is_empty():
		arena.abilities.slots.append("shield");arena.abilities.select("shield")
	arena.hud.close_modal();arena.hide();arena.hud.hide()
	service=load("res://scripts/service_room.gd").new();service.arena=arena;service.branch=branch;service.index=index;main.add_child(service)
	service.cell=Vector2i(0,0);service.destination=Vector3.ZERO;service.avatar.position=Vector3.ZERO;service.interact()
	service.completed.connect(func(_index):next());service.hub_requested.connect(func():arena.replay=null;service.queue_free();main.show_hub();queue_free())
