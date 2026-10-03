extends Node
## Common room layout (RoomLayout): every upgrade room and the merchant have the weapon crate, a vending machine and
## the «Фортуна» spot in the same places; the fortune spot holds a slot machine / ammo loot box by chance; the weapon
## crate sells three rolled guns into the backpack; the medkit machine heals for tokens. Window shots
## /tmp/r13-layout-<branch>.png. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func settle():
	for i in range(3):await get_tree().process_frame
func shot(path):
	if DisplayServer.get_name()=="headless":return
	# A stray pause press (focus change of the test window) may open the field tablet: keep the shot clean.
	for tablet in get_tree().get_nodes_in_group("field_tablet"):tablet.get_parent().remove_child(tablet);tablet.queue_free()
	get_tree().paused=false;await get_tree().process_frame
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(path)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	get_window().size=Vector2i(1600,900)
	Campaign.configure(1);Game.profiles.selected=true
	# Plan: deterministic, the merchant always has its slot machine, the chance gives every kind over many rooms.
	check(RoomLayout.plan(7,2,false)==RoomLayout.plan(7,2,false),"same room, same machines")
	check(RoomLayout.plan(7,2,true).fortune=="slot","merchant fortune is the slot machine")
	var kinds={}
	for seed in range(200):kinds[RoomLayout.plan(seed,2,false).fortune]=true;kinds["m_"+RoomLayout.plan(seed,2,false).machine]=true
	check(kinds.has("slot") and kinds.has("lootbox") and kinds.has("closed") and kinds.has("m_medkit") and kinds.has("m_lootbox"),"fortune and machine kinds all appear (%s)" % [kinds.keys()])
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await settle();await settle()
	main.start_run();await settle()
	main.enter_room(0,RoutePlan.build(Game.visual_run_seed)[0][1].id);await settle()
	for branch in ["vehicle","ability","headquarters","merchant"]:
		main.show_service(branch,2);await get_tree().create_timer(.8).timeout
		var room=main.current
		check(room.spots.has("crate") and is_instance_valid(room.spots.crate) and room.spots.crate.position==RoomLayout.WEAPON_CRATE,branch+": weapon crate in its place")
		check(is_instance_valid(room.spots.machine) and room.spots.machine.position==RoomLayout.MACHINE,branch+": vending machine in its place")
		check(is_instance_valid(room.spots.fortune) and room.spots.fortune.position==RoomLayout.FORTUNE and room.spots.fortune.get_meta("fortune",false),branch+": fortune spot in its place")
		check(not room.stand(RoomLayout.WEAPON_CRATE) and not room.stand(RoomLayout.FORTUNE),branch+": spots are outside the walking floor")
		await shot("/tmp/r13-layout-%s.png" % branch)
	# Weapon crate at the merchant: three offers, buying puts a weapon item into the backpack and costs alloy.
	var shop=main.current;var crate=shop.spots.crate
	check(crate.offers.size()==3 and crate.offers.all(func(o):return o.id in Game.LOOT.WEAPONS and o.stats.has("damage")),"three rolled guns with stats")
	Game.credits=1000;var before=shop.arena.run.weapon_bag.size()
	check(crate.buy(0)=="" and shop.arena.run.weapon_bag.size()==before+1 and Game.credits==1000-int(crate.offers[0].price),"bought gun goes to the backpack for alloy")
	check(crate.buy(0)=="Уже куплено","an offer sells once")
	shop.avatar.position=RoomLayout.WEAPON_CRATE+Vector3(.8,0,0);shop.interact();await get_tree().create_timer(.4).timeout
	check(shop.find_child("WeaponLockerMenu",true,false)!=null,"E at the crate opens it")
	await shot("/tmp/r13-layout-crate.png")
	# Medkit machine.
	var medkit=preload("res://scripts/medkit_vendor.gd").place(Node3D.new(),shop.arena,Vector3.ZERO)
	var run=shop.arena.run;run.soldier_hp=1;run.tokens=10
	check(medkit.buy() and run.soldier_hp==run.soldier_max_hp and run.tokens==10-medkit.PRICE,"medkit machine heals for tokens")
	print("ROOM LAYOUT: %d failures" % failures);get_tree().quit(1 if failures else 0)
