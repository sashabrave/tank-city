extends Node
func _ready():call_deferred("run_test")
func shot(path):
	if DisplayServer.get_name()=="headless":return
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func run_test():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.apply_profile(Game.fresh_profile.duplicate(true))
	var p=Game.progression;p.prepare_telegrams();assert(p.telegram_options.size()==3)
	assert(p.news_kind()=="general")
	p.view_quest_updates("general");p.view_quest_updates("institute");assert(p.news_kind()=="operations")
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(.6).timeout
	hub.phase="combat";hub._physics_process(.4)
	assert(hub.command_alert.visible and hub.command_alert.modulate==Color("f1cf55"))
	assert(hub.build_arrows.weapons.visible)
	var y=hub.command_alert.position.y;hub._physics_process(.5);assert(not is_equal_approx(y,hub.command_alert.position.y))
	Game.built_workshops.append("weapons");hub.update_bench_visuals();assert(not hub.build_arrows.has("weapons"))
	p.claimed=["institute_arsenal","shield","supply"];hub._physics_process(.4);assert(hub.build_arrows.headquarters.visible)
	hub.phase="workshop"
	# Command centre is the tablet in manage mode: the telegram offer sits on top of the quest feed.
	var command=load("res://scripts/progression/command_screen.gd").new();command.tab="quests";hub.root.add_child(command)
	command.quest_filter="operations";command.refresh()  # the offer sits on «Оперштаб» (T-160); the remembered filter comes from the player's own tablet memory
	var offer=command.find_children("TelegramOffer","Control",true,false)
	assert(offer.size()==1)
	assert(offer[0].find_children("*","Button",true,false).filter(func(b):return b.text==Texts.render("Принять")).size()==3)
	assert(not command.find_children("*","Button",true,false).any(func(b):return b.text.begins_with("Открыть телеграмму")))
	await shot("/tmp/tank-v20-telegram.png")
	assert(not p.operations_news())
	p.choose_telegram(1);assert(not p.telegram.is_empty());command.refresh()
	assert(command.find_children("TelegramOffer","Control",true,false).is_empty())
	p.telegram.progress=p.telegram.goal;assert(p.operations_news())
	p.mark_seen();assert(not p.has_news())
	p.abandon_telegram();assert(p.order_wait==1 and p.telegram.is_empty() and p.telegram_options.is_empty())
	p.order_wait=0;p.prepare_telegrams();p.abandon_telegram();assert(p.order_wait==1)
	command.tab="fighter";command.refresh()
	# Meta stage 2: the tab is the sortie report; outside a run it shows the last sortie or a hint.
	assert(command.content.find_children("*","Label",true,false).any(func(l):return l.text in ["Отчёт появится после первой вылазки","Последняя вылазка","Последняя вылазка · провал"]))
	# T-107: a seen call opens as a chat with avatars right in «Связь».
	if "call_intro" not in Game.progression.seen:Game.progression.seen.append("call_intro")
	command.tab="notifications";command.message_tab="calls";command.open_call="";command.refresh()
	var row=command.content.find_child("Call_intro",true,false);assert(row!=null,"the intro call is listed")
	row.pressed.emit();await get_tree().process_frame
	assert(command.content.find_child("CallChat",true,false)!=null and command.open_call=="intro","a tap unfolds the call as a chat")
	assert(not get_tree().root.find_children("*","Control",true,false).any(func(n):return n.get_script()==preload("res://scripts/ui/video_call.gd")),"no call window opens over the tablet")
	command.open_call=""
	command.queue_free();hub.queue_free();await get_tree().process_frame
	print("PASS command: direct telegram choice/decline, red/yellow priority/readiness/read state, slow alerts/build arrows")
	get_tree().quit()
