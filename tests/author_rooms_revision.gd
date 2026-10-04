extends Node3D
## Author's board, 3 Oct (T-206/207/213–217/219): the medkit machine says why it can't heal, a closed fortune
## booth says «сегодня закрыто», the stash explains itself and its exit, the HQ depot is a walk-in room with the
## supply fallback, leaving a card choice asks first, the class page refreshes on a level purchase, a newly
## available class carries a green lamp, and reward alloy flies into the strip. Profile/settings writes are off.
var errors=0
func check(value:bool,message:String):
	if value:print("PASS ",message)
	else:errors+=1;push_error("FAIL: "+message)
func _ready():call_deferred("run")
## One field engine: an upgrade room is the run's arena in service mode with the room as its playground.
func open_room(arena,branch:String,index:int):
	var room=load("res://scripts/service_room.gd").new();room.branch=branch
	arena.begin_service(index,room);return room
func ground(main):
	var node=main.current.get("playground") if is_instance_valid(main.current) else null
	return node if node!=null and is_instance_valid(node) else null
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	Engine.set_meta("hub_calls_off",true)
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.begin_room(1)
	await get_tree().process_frame
	# T-214: the stash window says what is left behind, not «поле зачищено».
	arena.room.mode="cache";arena.challenges.rewarded=false;arena.challenges.opened=false
	arena.hud.show_departure();await get_tree().process_frame
	var texts=arena.hud.modal.find_children("*","Label",true,false).map(func(l):return l.text)
	check(texts.any(func(t):return str(t).to_lower()=="тайник не открыт"),"stash departure says the stash is still closed")
	check(arena.hud.modal.find_children("*","Button",true,false).any(func(b):return b.text=="Вернуться к тайнику"),"stash departure offers to go back")
	arena.hud.close_modal();arena.room.mode="battle"
	# T-215: the depot is the service room with branch headquarters; without HQ technologies it refuels.
	var room=open_room(arena,"headquarters",2)
	await get_tree().process_frame
	check(room.modal==null,"depot: no cards before walking to the HQ")
	if room.offers.is_empty() or room.supplies:
		room.supplies=true;room.offers=room.DEPOT_SUPPLIES.duplicate(true)
	room.place_hero(Vector3(0,0,0));room.interact();await get_tree().process_frame
	check(is_instance_valid(room.modal),"depot: E at the HQ opens the cards")
	# T-217: «Отказаться» asks first; «stay» keeps the choice open.
	room.ask_skip();await get_tree().process_frame
	var confirm=room.modal.get_node_or_null("SkipConfirm")
	check(confirm!=null,"skip asks for confirmation")
	if confirm:confirm.close(false)
	await get_tree().process_frame
	check(not room.claimed and is_instance_valid(room.modal),"«Выбрать карточку» keeps the cards")
	if room.supplies:
		var hp=arena.headquarters.basic_hp;room.claim(0)
		check(arena.headquarters.basic_hp==hp+1 and room.claimed,"depot supply «Ремонт штаба» applies")
	else:
		room.claim(0);check(room.claimed,"depot HQ card claimed")
	var second=open_room(arena,"vehicle",3)
	await get_tree().process_frame
	second.place_hero(Vector3(0,0,0));second.interact();await get_tree().process_frame
	second.ask_skip();await get_tree().process_frame
	second.modal.get_node("SkipConfirm").close(true);await get_tree().process_frame
	check(second.claimed and second.dressing.open,"«Уйти без улучшения» opens the exit")
	# T-213: the medkit machine says what a press does, and answers a refused press on the prompt.
	var vendor=preload("res://scripts/medkit_vendor.gd").place(second,arena,Vector3(-3.4,0,2.4))
	await get_tree().process_frame
	arena.run.soldier_hp=arena.run.soldier_max_hp
	check("здоровье полное" in vendor.status().to_lower(),"medkit: full health is shown before the press")
	check(not vendor.buy() and vendor.prompt.flash_time>0,"medkit: a refused press flashes the reason")
	arena.run.soldier_hp=1.0;arena.run.tokens=0
	check("нужно 3 жетона" in vendor.status().to_lower(),"medkit: missing tokens are shown")
	arena.run.tokens=5
	check("полное лечение" in vendor.status().to_lower(),"medkit: what it does when usable")
	check(vendor.buy() and arena.run.tokens==2,"medkit: heals for 3 tokens")
	# T-216 / T-226: a closed booth says so on its prompt; no standing sign over any room spot.
	var booth=RoomLayout.place_machine(second,arena,"closed",RoomLayout.FORTUNE,true)
	check(booth.prompt.caption.contains("закрыто"),"closed fortune prompt says «сегодня закрыто»")
	var signs=[]
	for spot in second.spots.values()+[booth,vendor]:
		if spot is Node:signs+=spot.find_children("*","Label3D",true,false).filter(func(l):return l.text.strip_edges()!="")
	check(signs.is_empty(),"T-226: no standing signs over the crate and the machines (%d)" % signs.size())
	check(not second.find_children("*","Label3D",false,false).any(func(l):return "· E" in l.text),"T-226: no «· E» signs over the station or the vehicle")
	# T-226: green arrow to the exit once the upgrade is taken; yellow over the station before.
	await get_tree().physics_frame;await get_tree().physics_frame
	check(second.guide.visible and second.guide.kind=="ready" and absf(second.guide.position.x-float(second.dressing.EXIT_CELL.x))<.5,"T-226: green arrow over the exit after the choice")
	var third=open_room(arena,"ability",3)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(third.guide.visible and third.guide.kind=="goal" and third.guide.position==Vector3(0,0,-1),"T-226: yellow arrow over the instructor before the choice")
	# T-233: the weapon crate window — three cards with bars against the gun in hand; T-232: it stays the room's
	# window after a purchase, and the world prompts stay hidden while it is open.
	Game.credits=1000
	var crate=third.spots.crate
	crate.offers=[{"id":"pistol","rarity":2,"stats":{"damage":.15,"fire":.1},"price":40,"sold":false},{"id":"pistol","rarity":0,"stats":{"damage":0.0,"fire":0.0},"price":40,"sold":false},{"id":"rifle","rarity":1,"stats":{"damage":.06,"fire":.05},"price":70,"sold":false}]
	crate.refresh_prompt()
	check(crate.prompt.caption.contains("40"),"crate prompt shows the cheapest price")
	third.place_hero(RoomLayout.WEAPON_CRATE+Vector3(.9,0,0));third.interact();await get_tree().process_frame
	var window=third.modal
	check(is_instance_valid(window) and window.name=="WeaponLockerMenu","E at the crate opens its window")
	if is_instance_valid(window):
		var cards=window.find_children("Offer*","Panel",true,false)
		check(cards.size()==3,"three offer cards")
		var bars=cards[0].find_children("*","Panel",true,false).size() if not cards.is_empty() else 0
		check(bars>=8,"each card has bars (%d)" % bars)
		var verdicts=window.find_children("*","Label",true,false).map(func(l):return l.text)
		check(verdicts.any(func(t):return "Сильнее на" in t or "Stronger by" in t),"the better gun says how much stronger")
		await get_tree().process_frame
		check(not crate.prompt.panel.visible,"T-232: no E prompt over the open crate window")
		for b in window.find_children("Buy0","Button",true,false):b.pressed.emit()
		await get_tree().process_frame;await get_tree().process_frame
		check(is_instance_valid(third.modal) and third.modal==window and crate.offers[0].sold,"after a purchase the same window stays open")
		check(not crate.prompt.panel.visible,"T-232: still no E prompt after the purchase")
	arena.queue_free()
	await get_tree().process_frame
	# T-206 / T-219 in the Barracks.
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);await get_tree().create_timer(1.0).timeout
	hub.phase="combat"
	Game.credits=100000;Game.selected_class="recruit";Game.class_unlocks=["recruit"];Game.class_levels["recruit"]=1
	Game.progression.counters["field_reached"]=3
	hub.open_station("fighter");await get_tree().create_timer(.3).timeout
	var page=hub.build_menu.find_child("Page",true,false)
	check(page.find_child("Class_heavy",true,false).get_node_or_null("Badge")!=null,"new available class has a green lamp")
	check(page.find_child("Class_recruit",true,false).get_node_or_null("Badge")==null,"owned class has no lamp")
	check(page.get_node("SlotTitle_0").text!=Texts.render("Граната") and ClassCatalog.level("recruit")==2,"level 2: ability slot still locked")
	page.open_path();await get_tree().process_frame
	var buy=page.find_child("Buy_3",true,false)
	check(buy!=null,"level 3 buy button in the path")
	if buy:buy.pressed.emit()
	await get_tree().process_frame;await get_tree().process_frame
	# The rebuilt page's nodes (the old ones are freed by now): no «С 3 уровня» cell left.
	var locked=page.get_children().any(func(n):return n is Label and n.text.begins_with("С 3"))
	check(ClassCatalog.level("recruit")==3 and not locked,"level 3 purchase unlocks the ability cell at once")
	check(page.get_node_or_null("ClassPathView")!=null,"the path stays open after the purchase")
	# T-207: claiming roadmap/quest alloy launches flights into the strip.
	var flights=ResourceStrip.pickup_flights.filter(is_instance_valid).size()
	ResourceStrip.fly_reward("alloy",Vector2(400,400),80)
	await get_tree().create_timer(.4).timeout
	check(ResourceStrip.pickup_flights.filter(is_instance_valid).size()>flights,"reward alloy flies to the strip")
	hub.queue_free();await get_tree().process_frame
	# Dev map: every route node jumps into its room through the normal entry (main.show_node_service/show_service).
	var main=load("res://scripts/main.gd").new();add_child(main);await get_tree().process_frame;await get_tree().process_frame
	var plan=RoutePlan.build(Game.visual_run_seed)
	var special={}
	for stage in plan:
		for node in stage:
			var branch=RoutePlan.node_branch(node)
			if branch!="" and not special.has(branch):special[branch]=node
	for branch in special:
		var node=special[branch]
		main.test_jump(int(node.stage),false,str(node.id));await get_tree().process_frame
		check(ground(main)!=null and ground(main).get_script()==preload("res://scripts/service_room.gd") and ground(main).branch==branch and main.current==main.run_arena,"dev jump: %s node opens its room (the captured post too)" % branch)
		if branch=="legend":
			ground(main).place_hero(Vector3(0,0,-.2));ground(main).interact();await get_tree().process_frame
			var post=ground(main).root.get_children().filter(func(c):return c.get_script()==preload("res://scripts/legend_stop.gd"))
			check(not post.is_empty(),"captured post: E at the safe opens the legendary cards")
			if not post.is_empty():post[0].finish();await get_tree().process_frame
			check(ground(main).claimed and ground(main).dressing.open,"captured post: after the choice the exit opens")
	var stop=Campaign.SERVICES[0];var stop_branch=Campaign.service_options(Game.visual_run_seed,stop)[0]
	main.test_jump_service(stop,false,stop_branch);await get_tree().process_frame
	var expected=preload("res://scripts/merchant_room.gd") if stop_branch=="merchant" else preload("res://scripts/service_room.gd")
	check(ground(main)!=null and ground(main).get_script()==expected and ground(main).index==stop,"dev jump: the stop between stages opens its room")
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=42;add_child(route);await get_tree().process_frame
	var events=[];route.dev_service_requested.connect(func(stage,progress,branch):events.append([stage,progress,branch]))
	for i in range(200):
		if not route.travelling:break
		await get_tree().process_frame
	route.dev_stop=route.service_nodes[0].get_meta("stop");route.dev_entry(false)
	for i in range(80):
		if not events.is_empty():break
		await get_tree().process_frame
	check(events.size()==1 and events[0][2]==route.dev_stop.branch,"dev map: a stop between stages emits its jump")
	route.queue_free();main.queue_free();await get_tree().process_frame
	print("DONE errors=",errors)
	get_tree().quit(1 if errors>0 else 0)
