extends Node
## Gear screen and backpack (T-113): every everyday gesture — tap selects, tap again / double tap / E uses,
## drag moves, right click / «Выбросить» drops an army sack that comes back when walked over; full backpack,
## outside-battle and wrong-class cases; W/S walk the tablet tabs; Tab toggles the tablet.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func gear(view)->Object:
	var page=preload("res://scripts/ui/gear_page.gd").new(view);return page
func cell(view,key)->GearCell:
	for c in view.find_children("*","Button",true,false):
		if c is GearCell and c.key==key:return c
	return null
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	Game.backpack_slots=1;Game.ammo_slot_weapons=[]
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=12;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.0).timeout
	var r=arena.run;Ammo.ensure(r,arena.weapon)
	check(Backpack.capacity()==4,"backpack starts with 4 open cells")
	r.ammo_bag.append(Ammo.roll("burn",1,3));r.ammo_bag.append(Ammo.roll("cryo",2,4))
	arena.pause_battle();await get_tree().create_timer(.4).timeout
	var view=get_tree().root.find_children("*","Control",true,false).filter(func(n):return n.get_script()==preload("res://scripts/ui/field_tablet.gd"))[0]
	view.tab="inventory";view.refresh();await get_tree().process_frame
	var GP=preload("res://scripts/ui/gear_page.gd");GP.selected=""
	# Tap selects, a second tap equips (also what E and a double tap do).
	cell(view,"bag:0").pressed.emit()
	check(GP.selected=="bag:0" and Ammo.active(r)=="standard","first tap only selects")
	# A second tap closes the menu; a double tap (on_activate) uses the item (2026-10-03).
	cell(view,"bag:0").pressed.emit();check(GP.selected=="","second tap closes the action menu")
	cell(view,"bag:0").on_activate.call("bag:0");await get_tree().process_frame
	check(Ammo.active(r)=="burn" and r.ammo_bag.size()==1,"double tap loads the ammo; standard does not go to the bag")
	# Equip another: the loaded one swaps back into the bag.
	GP.selected="";view.refresh();await get_tree().process_frame
	# Items keep their cells now (T-196): the cryo box is still in cell 1.
	cell(view,"bag:1").on_activate.call("bag:1");await get_tree().process_frame
	check(Ammo.active(r)=="cryo" and r.ammo_bag.size()==1 and r.ammo_bag[0].type=="burn","equipping swaps with the loaded ammo")
	# Tap-tap on the slot unloads it.
	GP.selected="";view.refresh();await get_tree().process_frame
	cell(view,"slot:0").on_activate.call("slot:0");await get_tree().process_frame
	check(Ammo.active(r)=="standard" and r.ammo_bag.size()==2,"double tap on the slot unloads to the backpack")
	# Drag: bag → slot and slot → bag.
	var page=gear(view);page.body=Control.new()
	var cryo_cell=-1
	for c in range(Backpack.CELLS):
		var e=Backpack.layout(r)[c]
		if e!=null and e.kind=="ammo" and str(e.item.type)=="cryo":cryo_cell=c
	page.move("bag:%d" % cryo_cell,"slot:0")
	check(Ammo.active(r)=="cryo","drag from the backpack onto the slot loads")
	page.move("slot:0","bag:3")
	check(Ammo.active(r)=="standard" and r.ammo_bag.size()==2,"drag from the slot into the backpack unloads")
	# T-168: dragging inside the backpack swaps items of the same kind.
	var first_type="";var second_type=""
	for c in range(Backpack.CELLS):
		var e=Backpack.layout(r)[c]
		if e!=null and e.kind=="ammo":
			if first_type=="":first_type=str(e.item.type)
			elif second_type=="":second_type=str(e.item.type)
	var ammo_cells=[]
	for c in range(Backpack.CELLS):
		if Backpack.layout(r)[c]!=null and Backpack.layout(r)[c].kind=="ammo":ammo_cells.append(c)
	page.move("bag:%d" % ammo_cells[0],"bag:%d" % ammo_cells[1])
	check(str(Backpack.layout(r)[ammo_cells[0]].item.type)==second_type and str(Backpack.layout(r)[ammo_cells[1]].item.type)==first_type,"drag inside the backpack swaps two ammo boxes")
	check(not Backpack.swap(r,0,99),"no swap with an empty cell")
	# T-196: free layout — a blueprint and an ammo box trade cells; an item moves into an empty open cell;
	# locked cells refuse; the first «Сейф» cells keep their blueprint on a knock-out.
	r.pending_recipes.append({"id":"smg","category":"weapon"})
	var cells=Backpack.layout(r);var bp=-1;var box=-1;var empty=-1
	for c in range(Backpack.capacity()):
		if cells[c]==null and empty<0:empty=c
		elif cells[c]!=null and cells[c].kind=="recipe" and bp<0:bp=c
		elif cells[c]!=null and cells[c].kind=="ammo" and box<0:box=c
	page.move("bag:%d" % bp,"bag:%d" % box)
	cells=Backpack.layout(r)
	check(cells[box].kind=="recipe" and cells[bp].kind=="ammo","a blueprint and an ammo box trade cells")
	if empty>=0:
		page.move("bag:%d" % box,"bag:%d" % empty)
		check(Backpack.layout(r)[empty]!=null and Backpack.layout(r)[empty].kind=="recipe" and Backpack.layout(r)[box]==null,"an item moves into an empty cell")
	check(not Backpack.place(r,0,Backpack.capacity()),"locked cells refuse items")
	r.safe_slots=1
	var at=-1
	for c in range(Backpack.CELLS):
		if Backpack.layout(r)[c]!=null and Backpack.layout(r)[c].kind=="recipe":at=c
	if at!=0:Backpack.place(r,at,0)
	var order=Backpack.safe_order(r)
	check(order[1]==1 and order[0][0].id=="smg","the blueprint in the safe cell is the insured one")
	view.refresh();await get_tree().process_frame
	check(cell(view,"bag:0").get_node_or_null("Safe")!=null and cell(view,"bag:1").get_node_or_null("Safe")==null,"the safe cell shows a shield badge")
	r.safe_slots=0;r.pending_recipes.clear()
	# Weapons as backpack items (2026-10-03): a spare gun lands in a cell; dragging it onto the weapon cell
	# swaps it with the gun in hand; the gun in hand cannot leave for an empty cell (no weapon at all).
	var in_hand=str(r.weapon);var spare="shotgun" if in_hand!="shotgun" else "smg"
	while Backpack.full(r) and not r.ammo_bag.is_empty():r.ammo_bag.pop_back()
	check(Backpack.add_weapon(arena,{"id":spare,"rarity":1}),"a spare weapon goes into the backpack")
	var gun_cell=-1;var free_cell=-1
	for c in range(Backpack.capacity()):
		var e=Backpack.layout(r)[c]
		if e!=null and e.kind=="weapon":gun_cell=c
		elif e==null and free_cell<0:free_cell=c
	page.move("bag:%d" % gun_cell,"weapon")
	check(str(r.weapon)==spare and r.weapon_bag.size()==1 and str(r.weapon_bag[0].id)==in_hand and Backpack.layout(r)[gun_cell].kind=="weapon","dragging the spare onto the weapon cell swaps the guns in place")
	if free_cell>=0:
		# Empty hands (2026-10-03): the gun in hand goes into a free cell; taking it back restores the hands.
		page.move("weapon","bag:%d" % free_cell)
		check(Backpack.holstered(r) and Backpack.layout(r)[free_cell].kind=="weapon" and Backpack.layout(r)[free_cell].index==-1,"the gun in hand goes into an empty cell: hands empty")
		page.move("bag:%d" % free_cell,"weapon")
		check(not Backpack.holstered(r) and str(r.weapon)==spare,"taking it back fills the hands")
	page.move("weapon","bag:%d" % gun_cell)
	check(str(r.weapon)==in_hand,"dragging the gun in hand onto the spare swaps back")
	var data=preload("res://scripts/profile/run_checkpoint.gd").upgrade({"run":{"weapon_bag":[{"id":"shotgun"},{"id":"nope"}]}})
	check(data.run.weapon_bag.size()==1,"a saved run keeps valid spare weapons only")
	# Rolled crate stats count while that gun is in hand.
	var plain=CombatStats.weapon(arena,"rifle")
	Backpack.add_weapon(arena,{"id":"rifle","rarity":2,"stats":{"damage":.2,"fire":.1}})
	Backpack.equip_weapon(arena,r.weapon_bag.size()-1)
	var rolled=CombatStats.weapon(arena,"rifle")
	check(absf(rolled.damage/plain.damage-1.2)<.01 and rolled.interval<plain.interval,"a crate gun's rolled damage and fire rate apply in hand")
	r.weapon=in_hand;r.weapon_stats={};r.weapon_rarity=0
	r.weapon_bag.clear()
	# Full backpack: unloading is refused, nothing is lost.
	Backpack.equip(arena,0);r.pending_recipes.append({"id":"smg","category":"weapon"});r.ammo_bag.append(Ammo.roll("shock",0,1));r.ammo_bag.append(Ammo.roll("stun",0,2))
	check(Backpack.full(r) and not Backpack.unequip(arena,0) and Ammo.active(r)!="standard","full backpack keeps the loaded ammo")
	# Drop: right click / «Выбросить» → the item itself lies on the field (one item: its model with a rarity glow
	# and a card «E use / C to backpack»; several at once: a sack picked up by walking over it).
	var before=Backpack.used(r);var items=arena.room.pickups.filter(func(p):return p.kind=="item").size()
	var cell_of=func(kind:String)->int:
		for c in range(Backpack.CELLS):
			var e=Backpack.layout(r)[c]
			if e!=null and e.kind==kind:return c
		return -1
	page.discard("bag:%d" % cell_of.call("ammo"))
	check(Backpack.used(r)==before-1 and arena.room.pickups.filter(func(p):return p.kind=="item").size()==items+1,"discarded ammo lies on the field as itself")
	page.discard("bag:%d" % cell_of.call("recipe"))
	check(r.pending_recipes.is_empty() and arena.room.pickups.filter(func(p):return p.kind=="item").size()==items+2,"blueprints can be dropped too")
	var dropped=arena.room.pickups.filter(func(p):return p.kind=="item")[0]
	arena.reward.collect_pickup(dropped)
	check(dropped in arena.room.pickups,"walking over a single item does not pick it up")
	for card in get_tree().get_nodes_in_group("drop_prompts"):
		if card.pickup==dropped:card.stash()
	check(Backpack.used(r)==before-1 and dropped not in arena.room.pickups,"«C» puts it back into the backpack")
	# Last weapon / last rounds (2026-10-03): never thrown away; a run without a gun gets the HQ's choice.
	var gun_before=str(r.weapon)
	page.discard("weapon")
	check(str(r.weapon)==gun_before,"the gun in hand cannot be thrown away")
	var std_slot=-1
	for i in range(r.ammo_slots.size()):
		if str(r.ammo_slots[i].type)==Ammo.STANDARD:std_slot=i
	if std_slot>=0:
		var count=arena.room.pickups.size();page.discard("slot:%d" % std_slot)
		check(arena.room.pickups.size()==count and str(r.ammo_slots[std_slot].type)==Ammo.STANDARD,"the plain rounds cannot be thrown away")
	r.weapon="";check(arena.ensure_armed() and str(r.weapon)==Game.selected_weapon,"no gun in hand: the HQ issues the chosen one")
	r.weapon=gun_before;Ammo.ensure(r,gun_before)
	# Empty hands and the tablet: closing is refused (the gear page stays and explains), the put-away gun cannot be
	# thrown away, another spare taken in hand leaves the old one as an ordinary spare in its cell.
	while Backpack.free_cells(r)<2 and not r.ammo_bag.is_empty():r.ammo_bag.pop_back()
	var tablet=get_tree().get_nodes_in_group("field_tablet")[0]
	check(Backpack.holster(arena),"the gun can be put away any time")
	var hand_cell=r.holster_cell
	page.discard("bag:%d" % hand_cell)
	check(Backpack.holstered(r) and str(r.weapon)==gun_before,"the put-away gun is the last one: it cannot be thrown away")
	view.tab="fighter";tablet.close();await get_tree().process_frame
	check(is_instance_valid(tablet) and not tablet.is_queued_for_deletion() and view.tab=="inventory","with empty hands the tablet does not close and shows the gear page")
	check(cell(view,"weapon")!=null and cell(view,"weapon").get_node_or_null("EmptyHands")!=null,"the weapon cell says the hands are empty")
	Backpack.add_weapon(arena,{"id":"smg" if gun_before!="smg" else "shotgun"})
	Backpack.equip_weapon(arena,r.weapon_bag.size()-1)
	check(not Backpack.holstered(r) and Backpack.layout(r)[hand_cell].kind=="weapon" and str(Backpack.layout(r)[hand_cell].item.id)==gun_before,"taking another spare leaves the old gun in its cell")
	Backpack.holster(arena);tablet.close(false)
	check(not Backpack.holstered(r),"leaving for the hub puts the gun back in hand")
	r.weapon=gun_before;r.weapon_bag.clear();Ammo.ensure(r,gun_before)
	await get_tree().process_frame;preload("res://scripts/ui/pause_tablet.gd").open(arena);await get_tree().create_timer(.4).timeout
	view=get_tree().root.find_children("*","Control",true,false).filter(func(n):return n.get_script()==preload("res://scripts/ui/field_tablet.gd"))[0]
	view.tab="inventory";view.refresh();await get_tree().process_frame
	# Wrong class: charges-only ammo cannot go into a pistol (RPG ammo doesn't exist yet: fire fits both).
	check(not Ammo.fits("explosive","rpg") and Ammo.fits("burn","rpg"),"ammo class rules")
	# Outside battle nothing can be dropped.
	arena.phase="result"
	check(not Backpack.can_drop(arena),"no dropping outside battle")
	arena.phase="paused"
	# W/S walk through tabs; Tab is bound to the tablet.
	var first=view.tab
	var press=InputEventKey.new();press.physical_keycode=Settings.keys.south;press.pressed=true
	view._input(press)
	check(view.tab!=first,"S moves to the next tab (%s → %s)" % [first,view.tab])
	check(InputMap.action_get_events("pause").any(func(e):return e is InputEventKey and e.physical_keycode==KEY_TAB),"Tab opens and closes the tablet")
	# Aid kits (T-115): at full health a heart goes into the backpack; H heals from it later.
	get_tree().paused=false
	r.supplies.clear();while Backpack.full(r) and not r.ammo_bag.is_empty():r.ammo_bag.pop_back()
	r.soldier_hp=r.soldier_max_hp;arena.player.hp=r.soldier_hp
	arena.reward.place_pickup(arena.grid_pos(arena.player.position),"heart",0.0)
	var heart=arena.room.pickups.filter(func(p):return p.kind=="heart")[0]
	arena.reward.collect_pickup(heart)
	check(Backpack.medkits(r)==1,"full health: the aid kit goes into the backpack")
	check(not Backpack.use_medkit(arena),"no use at full health")
	r.soldier_hp=1.0;arena.player.hp=1.0
	check(Backpack.use_medkit(arena) and r.soldier_hp>1.0 and Backpack.medkits(r)==0,"H heals from the backpack")
	print("GEAR: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
