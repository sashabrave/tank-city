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
	# from room_layout_revision: room machines are deterministic, the merchant always has the slot machine, all kinds appear.
	check(RoomLayout.plan(7,2,false)==RoomLayout.plan(7,2,false),"same room, same machines")
	check(RoomLayout.plan(7,2,true).fortune=="slot","merchant fortune is the slot machine")
	var kinds={}
	for seed in range(200):kinds[RoomLayout.plan(seed,2,false).fortune]=true;kinds["m_"+RoomLayout.plan(seed,2,false).machine]=true
	check(kinds.has("slot") and kinds.has("lootbox") and kinds.has("closed") and kinds.has("m_medkit") and kinds.has("m_lootbox"),"fortune and machine kinds all appear (%s)" % [kinds.keys()])
	# T-234: the slot machine is the usual fortune (about 65% of rooms), a closed booth about one room in five.
	var counts={"slot":0,"lootbox":0,"closed":0};var doubled=0
	for seed in range(1000):
		var layout=RoomLayout.plan(seed,3,false);counts[layout.fortune]+=1
		if layout.fortune=="lootbox" and layout.machine=="lootbox":doubled+=1
	check(counts.slot>550 and counts.slot<750 and counts.closed>140 and counts.closed<260 and doubled==0,"fortune shares: %s, no double ammo box" % [counts])
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
	# from take_vehicle_revision: on foot at the mechanic, buying the parked vehicle costs alloy and waits for the next field.
	arena.pending_vehicle="";main.show_service("vehicle",2);await get_tree().create_timer(.5).timeout
	var garage_room=main.run_arena.playground;Game.credits=500
	check(garage_room.vehicle_for_sale and garage_room.vehicle_prompt!=null,"on foot the parked vehicle is offered")
	var vehicle_price=int(garage_room.VEHICLE_PRICES.get(garage_room.vehicle,80))
	garage_room.place_hero(garage_room.PARKED+Vector3(-.2,0,.95));garage_room.interact();await settle()
	for b in garage_room.modal.find_children("*","Button",true,false):
		if b.text.contains("Купить"):b.pressed.emit()
	await settle()
	check(arena.pending_vehicle==garage_room.vehicle and Game.credits==500-vehicle_price,"taking the vehicle costs alloy and waits at the next field")
	arena.pending_vehicle=""
	main.show_service("merchant",2);await settle()
	var shop=main.run_arena.playground
	# from room_layout_revision: the common room layout keeps crate, machine and «Фортуна» in place, off the floor.
	check(shop.spots.has("crate") and is_instance_valid(shop.spots.crate) and shop.spots.crate.position==RoomLayout.WEAPON_CRATE and is_instance_valid(shop.spots.machine) and shop.spots.machine.position==RoomLayout.MACHINE and is_instance_valid(shop.spots.fortune) and shop.spots.fortune.position==RoomLayout.FORTUNE,"merchant: crate, machine and fortune spot in their places")
	check(arena.walls.has(arena.grid_pos(RoomLayout.WEAPON_CRATE)) and arena.walls.has(arena.grid_pos(RoomLayout.FORTUNE)) and not arena.can_stand(RoomLayout.WEAPON_CRATE,arena.player),"merchant: spots stand on solid cells of the field")
	# from room_layout_revision: the weapon crate sells three rolled guns into the backpack for alloy, each once.
	var crate=shop.spots.crate
	check(crate.offers.size()==3 and crate.offers.all(func(o):return o.id in Game.LOOT.WEAPONS and o.stats.has("damage")),"three rolled guns with stats")
	Game.credits=1000;var bag_before=arena.run.weapon_bag.size()
	check(crate.buy(0)=="" and arena.run.weapon_bag.size()==bag_before+1 and Game.credits==1000-int(crate.offers[0].price),"bought gun goes to the backpack for alloy")
	check(crate.buy(0)=="Уже куплено","an offer sells once")
	# from room_layout_revision: the medkit machine heals for tokens.
	var medkit=preload("res://scripts/medkit_vendor.gd").place(Node3D.new(),arena,Vector3.ZERO)
	arena.run.soldier_hp=1;arena.run.tokens=10
	check(medkit.buy() and arena.run.soldier_hp==arena.run.soldier_max_hp and arena.run.tokens==10-medkit.PRICE,"medkit machine heals for tokens")
	medkit.get_parent().free()
	arena.run.tokens=30;arena.run.soldier_hp=1
	check(shop.get_script()==load("res://scripts/merchant_room.gd"),"merchant stop opens")
	# The room hero holds and fires the run's gun, not the hub's choice (2026-10-03).
	var room_gun="shotgun" if Game.selected_weapon!="shotgun" else "smg"
	arena.run.weapon=room_gun;await get_tree().physics_frame;await get_tree().physics_frame
	RunUpgrades.refresh_player(arena)
	check(shop.avatar==arena.player and Gun.weapon_id(arena)==room_gun and arena.player.model.weapon_id==room_gun,"the room hero is the arena's hero and holds the run's gun")
	arena.run.weapon=Game.selected_weapon if Game.selected_weapon in Game.LOOT.WEAPONS else "pistol"
	check(shop.stock.any(func(e):return e.kind=="card") and shop.find_child("SlotMachine",true,false)!=null,"stock has cards; the slot machine stands apart")
	var heal=shop.stock.map(func(e):return e.kind).find("heal")
	check(shop.purchase(heal) and arena.run.soldier_hp==arena.run.soldier_max_hp and arena.run.tokens==27,"heal bought for tokens")
	check(not shop.purchase(heal),"sold item cannot be bought twice")
	var card=shop.stock.map(func(e):return e.kind).find("card");var history=arena.run.upgrade_history.size();var price=shop.stock[card].price
	check(shop.purchase(card) and arena.run.upgrade_history.size()==history+1 and arena.run.tokens==27-price,"card bought and applied")
	var before=arena.run.tokens
	shop.place_hero(RoomLayout.FORTUNE-Vector3(1.15,0,0));shop.interact();await settle()  # the slot machine stands on the «Фортуна» spot
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
	shop.place_hero(Vector3(0,0,3))
	shop.interact_button.disabled=false;shop.place_hero(shop.COUNTER+Vector3(0,0,1));shop.interact();await settle()
	# The window itself, not the «MerchantShop» mesh inside the truck model (it matched this check before T-264).
	check(is_instance_valid(shop.modal) and shop.modal.name=="MerchantShop","shop window opens at the counter")
	# T-264: offers are big cards with a buy button each; «Перебросить» spends a run reroll on the unsold cards.
	var shop_window=shop.modal
	check(shop_window.find_children("Offer*","Panel",true,false).size()==shop.stock.size() and shop_window.find_child("Buy0",true,false) is Button,"T-264: every offer is a card with a buy button")
	check(shop_window.find_child("Buy%d" % heal,true,false).disabled,"T-264: a sold offer's button is locked")
	arena.run.rerolls_left=2
	var unsold=func():return shop.stock.filter(func(e):return e.kind=="card" and not e.sold).map(func(e):return e.id)
	var before_offers=unsold.call();var sold_card=shop.stock[card].duplicate()
	check(shop_window.find_child("Reroll",true,false) is Button and not shop_window.find_child("Reroll",true,false).disabled,"T-264: reroll button is active with rerolls left")
	check(shop.reroll_offers() and arena.run.rerolls_left==1,"T-264: reroll spends one run reroll")
	var after_offers=unsold.call()
	check(after_offers.size()==before_offers.size() and after_offers!=before_offers and shop.stock[card].id==sold_card.id and shop.stock[card].sold,"T-264: unsold cards change, the sold one stays")
	check(shop.stock.filter(func(e):return e.kind=="card").all(func(e):return e.price==shop.CARD_PRICES[e.tier]),"T-264: rerolled cards keep the rarity prices")
	arena.run.rerolls_left=0;shop.close_shop(false);shop.open_shop()
	check(not shop.reroll_offers() and shop.find_child("Reroll",true,false).disabled,"T-264: no rerolls, no reroll")
	shop.close_shop()
	var checkpoint=preload("res://scripts/profile/run_checkpoint.gd").capture(arena,2,"map",{})
	check(checkpoint.run.has("tokens"),"tokens stored in the run checkpoint")
	shop.completed.emit(2);await settle()
	var route=main.current
	check(route.get_script()==load("res://scripts/route_map.gd") and route.available==2 and not route.needs_service,"after the merchant the stage opens")
	check(route.reachable.all(func(id):return id in RoutePlan.reachable(route.plan,2,main.route_choices,"merchant")),"only lanes behind the merchant are reachable")
	if is_instance_valid(main.run_arena):main.run_arena.free()
	main.queue_free();await settle()
	# from recycling_v19: duplicate recipes on extraction, single/all sale, unlocks kept, profile round trip.
	Game.reset_upgrades()
	var pending=[{"category":"weapon","id":"smg"},{"category":"weapon","id":"smg"},{"category":"weapon","id":"pistol"}]
	Game.bank_recipes(pending)
	check(pending.is_empty() and "smg" in Game.weapon_unlocks and Game.duplicate_recipes.size()==2 and Game.new_recipes.size()==1,"extraction banks one recipe and two duplicates")
	var dup_price=Game.duplicate_price(Game.duplicate_recipes[0])
	check(Game.sell_duplicate(0) and Game.credits==dup_price and Game.duplicate_recipes.size()==1 and "smg" in Game.weapon_unlocks,"a duplicate sells for alloy, the unlock stays")
	check(not Game.sell_duplicate(10),"no sale of a missing duplicate")
	check(Game.sell_all_duplicates()>0 and Game.duplicate_recipes.is_empty() and "pistol" in Game.weapon_unlocks and Game.sell_all_duplicates()==0,"sell all, no repeat sale")
	Game.duplicate_recipes=[{"category":"weapon","id":"pistol"}]
	var snapshot=Game.serialize_progress().duplicate(true);Game.duplicate_recipes=[];Game.apply_profile(snapshot)
	check(Game.duplicate_recipes.size()==1,"duplicates survive the profile round trip")
	# from garage_progression: garage gates (research, yard, workshop, blueprint, level), single purchase, upgrades,
	# armor formula and the owned fleet in the profile round trip.
	Game.reset_upgrades();Game.credits=50000
	check(Game.garage.starting_vehicle()=="" and not Game.garage.buy("buggy"),"no vehicle and no purchase without the garage")
	Game.research_unlocks.append("garage")
	check(not Game.build_workshop("garage") and Game.build_workshop("yard") and Game.build_workshop("garage") and not Game.garage.buy("buggy"),"garage needs the yard, a vehicle needs its blueprint")
	Game.garage.unlocks.append("vehicle_buggy")
	check(Game.garage.buy("buggy") and Game.garage.starting_vehicle()=="buggy","bought buggy becomes the starting vehicle")
	var money=Game.credits;check(not Game.garage.buy("buggy") and Game.credits==money,"a vehicle is bought once")
	Game.garage.unlocks.append("vehicle_tank");Game.progression.level=5
	check(not Game.garage.buy("tank"),"tank needs the APC first")
	Game.garage.unlocks.append("vehicle_apc");check(Game.garage.buy("apc") and Game.garage.buy("tank"),"APC then tank")
	Game.garage.choose("buggy");check(not Game.garage.upgrade("buggy","armor"),"upgrade needs its blueprint")
	Game.garage.unlocks.append("buggy_armor");check(Game.garage.upgrade("buggy","armor"),"armor upgrade bought")
	check(is_equal_approx(GarageCatalog.stats("buggy").hp,Balance.CONFIG.enemy("buggy").health*GarageCatalog.PLAYER_ARMOR.buggy*1.03),"armor upgrade adds 3% hp")
	var garage_snapshot=Game.serialize_progress().duplicate(true);Game.garage=load("res://scripts/garage/state.gd").new();Game.apply_profile(garage_snapshot)
	check(Game.garage.owned.size()==3 and Game.garage.selected=="buggy" and Game.garage.level("buggy","armor")==1,"garage survives the profile round trip")
	check(Game.garage.choose("") and Game.garage.starting_vehicle()=="","going on foot is a choice")
	print("MERCHANT: %d failures" % failures);get_tree().quit(1 if failures else 0)
