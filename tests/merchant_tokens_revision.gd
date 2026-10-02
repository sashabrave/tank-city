extends Node
# Tokens, merchant stop and world 1 service-row roads. Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	Campaign.configure(1)
	check(RoutePlan.lane_span(0,2,3)==[0,1] and RoutePlan.lane_span(1,2,3)==[1,2] and RoutePlan.lane_span(0,1,3)==[0,1,2],"service stops link to neighbouring lanes")
	check(Campaign.service_options(1,2)==["ability","merchant"],"world 1 rows: instructor and merchant")
	var plan=RoutePlan.build(11)
	for lane in range(3):
		var options=RoutePlan.service_options_from(plan,2,{1:plan[1][lane].id},["ability","merchant"])
		check(options==(["ability"] if lane==0 else ["merchant"] if lane==2 else ["ability","merchant"]),"lane %d reaches its service stops" % lane)
	check(RoutePlan.reachable(plan,2,{1:plan[1][0].id},"merchant")==[plan[2][1].id,plan[2][2].id],"merchant leads on to its lanes")
	Game.profiles.selected=true
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await settle()
	main.start_run();await settle()
	main.enter_room(0,RoutePlan.build(Game.visual_run_seed)[0][1].id);await settle()
	var arena=main.run_arena;arena.auto_pause_enabled=false;arena.set_physics_process(false)
	check(ResourceStrip.run_tokens()==0,"token counter tracks the run")
	var commander=arena.spawn_actor("soldier",arena.find_free_near(Vector2i(3,3)),false);commander.elite=true
	check(arena.reward.token_drop(commander)==Balance.CONFIG.economy.token_commander,"commander always drops tokens")
	arena.run.combat_rng.seed=5;var drops=0
	var grunt=arena.spawn_actor("soldier",arena.find_free_near(Vector2i(5,3)),false)
	for i in range(2000):drops+=arena.reward.token_drop(grunt)
	check(drops>60 and drops<200,"ordinary enemies drop tokens rarely (%d / 2000)" % drops)
	arena.run.tokens=30;arena.run.soldier_hp=1
	main.show_map(1);await settle();main.show_map(2);await settle()
	main.show_service("merchant",2);await settle()
	var shop=main.current
	check(shop.get_script()==load("res://scripts/merchant_room.gd"),"merchant stop opens")
	check(shop.stock.any(func(e):return e.kind=="card") and shop.find_child("SlotMachine",true,false)!=null,"stock has cards; the slot machine stands apart")
	var heal=shop.stock.map(func(e):return e.kind).find("heal")
	check(shop.purchase(heal) and arena.run.soldier_hp==arena.run.soldier_max_hp and arena.run.tokens==27,"heal bought for tokens")
	check(not shop.purchase(heal),"sold item cannot be bought twice")
	var card=shop.stock.map(func(e):return e.kind).find("card");var history=arena.run.upgrade_history.size();var price=shop.stock[card].price
	check(shop.purchase(card) and arena.run.upgrade_history.size()==history+1 and arena.run.tokens==27-price,"card bought and applied")
	var before=arena.run.tokens
	shop.avatar.position=Vector3(2,0,0);shop.interact();await settle()
	var reels=shop.find_child("SlotWindow",true,false)
	check(reels!=null and reels.find_child("Reel2",true,false)!=null,"E at the machine opens the reel window at once")
	var strip=reels.reels[0].strip.position.y
	await get_tree().create_timer(.25).timeout
	check(reels.reels[0].strip.position.y>strip,"reels spin")
	for i in range(30):
		if not is_instance_valid(reels):break
		await get_tree().create_timer(.1).timeout
	check(not is_instance_valid(reels) and shop.modal==null,"window closes by itself after the verdict")
	shop.interact();await settle();shop.modal.finish();await settle()
	check(arena.run.tokens-before in [-4,0,4],"each pull costs 2 or pays back double")
	arena.run.tokens=0
	check(not shop.pull_lever(),"no tokens, no play")
	shop.avatar.position=Vector3(0,0,3)
	shop.interact_button.disabled=false;shop.avatar.position=shop.COUNTER+Vector3(0,0,1);shop.interact();await settle()
	check(shop.find_child("MerchantShop",true,false)!=null,"shop window opens at the counter")
	shop.close_shop()
	var checkpoint=preload("res://scripts/profile/run_checkpoint.gd").capture(arena,2,"map",{})
	check(checkpoint.run.has("tokens"),"tokens stored in the run checkpoint")
	shop.completed.emit(2);await settle()
	var route=main.current
	check(route.get_script()==load("res://scripts/route_map.gd") and route.available==2 and not route.needs_service,"after the merchant the stage opens")
	check(route.reachable.all(func(id):return id in RoutePlan.reachable(route.plan,2,main.route_choices,"merchant")),"only lanes behind the merchant are reachable")
	if is_instance_valid(main.run_arena):main.run_arena.free()
	main.queue_free();await settle()
	print("MERCHANT: %d failures" % failures);get_tree().quit(1 if failures else 0)
