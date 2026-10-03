extends Node3D
## Service room: themed dressing per branch, exit gate closed until the choice, walking out completes the room.
var errors=0
func check(value:bool,message:String):
	if value:print("PASS ",message)
	else:errors+=1;push_error("FAIL: "+message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.begin_room(1)
	await get_tree().process_frame;remove_child(arena)
	for branch in ["vehicle","ability","headquarters"]:
		var room=load("res://scripts/service_room.gd").new();room.arena=arena;room.branch=branch;room.index=2;add_child(room)
		await get_tree().process_frame
		check(is_instance_valid(room.dressing) and room.dressing.get_child_count()>20,branch+": themed dressing built")
		check(not room.dressing.open,branch+": exit closed before the choice")
		var done=[false];room.completed.connect(func(_i):done[0]=true)
		room.cell=room.dressing.EXIT_CELL+Vector2i.LEFT;room.avatar.position=Vector3(room.cell.x,0,room.cell.y);room.destination=room.avatar.position
		Game.touch_direction=Vector2i.RIGHT;await get_tree().physics_frame;await get_tree().physics_frame;Game.touch_direction=Vector2i.ZERO
		check(room.cell!=room.dressing.EXIT_CELL,branch+": gate blocks before the choice")
		room.skip_choice();check(room.dressing.open,branch+": gate opens after the choice")
		# T-083: leaving takes E in the exit zone; E anywhere else does nothing.
		room.avatar.position=Vector3(0,0,3);room.interact()
		check(not done[0],branch+": E away from the exit keeps the room")
		room.avatar.position=Vector3(room.dressing.EXIT_CELL.x-1,0,room.dressing.EXIT_CELL.y)
		Game.touch_direction=Vector2i.RIGHT
		for i in range(30):await get_tree().physics_frame
		Game.touch_direction=Vector2i.ZERO
		check(room.avatar.position.x>room.dressing.EXIT_CELL.x-.6,branch+": the hero walks into the open gate")
		room.interact()
		check(done[0],branch+": E at the gate completes the room")
		if branch=="vehicle" and room.has_node("TakeVehicleLabel"):
			# T-119: after the choice the parked vehicle can still be bought, through a purchase window.
			Game.credits=500;var was_done=done[0]
			room.avatar.position=room.PARKED+Vector3(-.9,0,.6);room.interact()
			check(is_instance_valid(room.modal) and room.modal.name=="VehicleOffer","E at the parked vehicle opens the purchase window")
			for b in room.modal.find_children("*","Button",true,false):
				if b.text.contains("Купить"):b.pressed.emit()
			check(arena.pending_vehicle==room.vehicle and Game.credits==500-int(room.VEHICLE_PRICES[room.vehicle]),"buying delivers the vehicle to the next field")
		# T-158/T-185: the hero shoots here like in the hub; abilities use the same bar.
		var combat=room.get_node_or_null("RoomCombat")
		check(combat!=null and is_instance_valid(combat.skills),branch+": room has hub-style controls")
		if combat:
			combat.shoot();check(combat.projectiles.size()>=1,branch+": a shot flies")
		room.queue_free();await get_tree().process_frame
	# T-184: five vehicle cards, three per visit; over a few visits every kind shows up.
	var kinds={}
	for k in range(14):
		var o=arena.reward.service_offers("vehicle");check(o.size()==3 or k>0,"three vehicle cards per stop")
		for offer in o:kinds[offer.id]=true
	check(kinds.size()==5,"all five vehicle cards appear across stops "+str(kinds.keys()))
	arena.vehicle.upgrade_at_service("buggy",2,{"id":"rate","tier":1});arena.vehicle.upgrade_at_service("buggy",2,{"id":"overhaul","tier":1})
	check(float(arena.run.vehicle_mods.buggy.rate)<1.0 and float(arena.run.vehicle_mods.buggy.damage)>0,"fire rate and overhaul cards change the vehicle")
	# T-186: no class ability yet — the instructor gives alloy instead of cards.
	Game.selected_class="recruit";Game.class_unlocks=["recruit"];Game.class_levels={}
	var early=load("res://scripts/service_room.gd").new();early.arena=arena;early.branch="ability";early.index=2;add_child(early)
	await get_tree().process_frame
	early.avatar.position=Vector3(0,0,0);var before=Game.credits
	early.interact()
	check(is_instance_valid(early.modal) and early.modal.name=="EarlyReward","no abilities: a short dialog with alloy instead of cards")
	var ok=early.modal.find_child("Ok",true,false);ok.pressed.emit()
	check(Game.credits>before and early.claimed and early.dressing.open,"«Ок» pays the alloy and opens the exit")
	early.queue_free();await get_tree().process_frame
	arena.queue_free()
	print("SERVICE ROOM: %d failures" % errors);get_tree().quit(1 if errors else 0)
