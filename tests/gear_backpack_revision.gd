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
	cell(view,"bag:0").pressed.emit();await get_tree().process_frame
	check(Ammo.active(r)=="burn" and r.ammo_bag.size()==1,"second tap loads the ammo; standard does not go to the bag")
	# Equip another: the loaded one swaps back into the bag.
	GP.selected="";view.refresh();await get_tree().process_frame
	# Items keep their cells now (T-196): the cryo box is still in cell 1.
	cell(view,"bag:1").pressed.emit();cell(view,"bag:1").pressed.emit();await get_tree().process_frame
	check(Ammo.active(r)=="cryo" and r.ammo_bag.size()==1 and r.ammo_bag[0].type=="burn","equipping swaps with the loaded ammo")
	# Tap-tap on the slot unloads it.
	GP.selected="";view.refresh();await get_tree().process_frame
	cell(view,"slot:0").pressed.emit();cell(view,"slot:0").pressed.emit();await get_tree().process_frame
	check(Ammo.active(r)=="standard" and r.ammo_bag.size()==2,"tap-tap on the slot unloads to the backpack")
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
	# Full backpack: unloading is refused, nothing is lost.
	Backpack.equip(arena,0);r.pending_recipes.append({"id":"smg","category":"weapon"});r.ammo_bag.append(Ammo.roll("shock",0,1));r.ammo_bag.append(Ammo.roll("stun",0,2))
	check(Backpack.full(r) and not Backpack.unequip(arena,0) and Ammo.active(r)!="standard","full backpack keeps the loaded ammo")
	# Drop: right click / «Выбросить» → an army sack on the field; walking over it brings it back.
	var before=Backpack.used(r);var sacks=arena.room.pickups.filter(func(p):return p.kind=="sack").size()
	page.discard("bag:%d" % (r.pending_recipes.size()))
	var sack=arena.room.pickups.filter(func(p):return p.kind=="sack")
	check(Backpack.used(r)==before-1 and sack.size()==sacks+1,"discarded ammo lies on the field as a sack")
	page.discard("bag:0")
	check(r.pending_recipes.is_empty() and arena.room.pickups.filter(func(p):return p.kind=="sack").size()==sacks+2,"blueprints can be dropped too")
	arena.reward.collect_pickup(arena.room.pickups.filter(func(p):return p.kind=="sack")[0])
	check(Backpack.used(r)==before-1,"walking over a sack picks it back up")
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
