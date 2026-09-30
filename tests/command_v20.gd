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
	assert(hub.build_arrows.character.visible)
	var y=hub.command_alert.position.y;hub._physics_process(.5);assert(not is_equal_approx(y,hub.command_alert.position.y))
	Game.built_workshops.append("character");hub.update_bench_visuals();assert(not hub.build_arrows.has("character"))
	p.claimed=["institute_character","shield","supply"];hub._physics_process(.4);assert(hub.build_arrows.headquarters.visible)
	hub.phase="workshop"
	var command=load("res://scripts/progression/command_screen.gd").new();hub.root.add_child(command)
	assert(command.find_children("TelegramOffer","Panel",true,false).size()==1)
	assert(command.find_children("*","Button",true,false).filter(func(b):return b.text.begins_with("Принять ·")).size()==3)
	assert(not command.find_children("*","Button",true,false).any(func(b):return b.text.begins_with("Открыть телеграмму")))
	await shot("/tmp/tank-v20-telegram.png")
	assert(not p.operations_news())
	p.choose_telegram(1);assert(not p.telegram.is_empty());command.refresh()
	assert(command.find_children("TelegramOffer","Panel",true,false).is_empty())
	p.telegram.progress=p.telegram.goal;assert(p.operations_news())
	p.mark_seen();assert(not p.has_news())
	p.abandon_telegram();assert(p.order_wait==1 and p.telegram.is_empty() and p.telegram_options.is_empty())
	p.order_wait=0;p.prepare_telegrams();p.abandon_telegram();assert(p.order_wait==1)
	command.tab="fighter";command.refresh()
	var portrait=command.find_child("ClassPortrait",true,false)
	assert(portrait is TextureRect and portrait.texture is AtlasTexture and portrait.size.x<=110 and portrait.size.y<=116)
	await shot("/tmp/tank-v20-class-portrait.png")
	command.queue_free();hub.queue_free();await get_tree().process_frame
	print("PASS command: direct telegram choice/decline, red/yellow priority/readiness/read state, slow alerts/build arrows, generated class portrait")
	get_tree().quit()
