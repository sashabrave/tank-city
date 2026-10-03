class_name Backpack
extends RefCounted
## The run backpack (T-113): blueprints and ammo items share its cells. Bought backpack levels (Game.backpack_slots,
## 1…5) plus BASE_EXTRA give the open cells; the gear screen always shows CELLS cells, the rest locked.
## Ammo moves between the backpack and the weapon's slots; anything can be dropped as an army sack on the field,
## which brings it back when the soldier walks over it again (nothing is lost).
const CELLS=8
const BASE_EXTRA=3
const MAX_BOUGHT=5

static func capacity()->int:return mini(CELLS,Game.backpack_slots+BASE_EXTRA)
static func used(run)->int:return run.pending_recipes.size()+run.ammo_bag.size()+run.supplies.size() if run!=null else 0
static func free_cells(run)->int:return capacity()-used(run)
static func full(run)->bool:return free_cells(run)<=0
## Items in cell order: blueprints, then ammo. Each entry {kind:"recipe"|"ammo", item}.
static func items(run)->Array:
	if run==null:return []
	return run.pending_recipes.map(func(r):return {"kind":"recipe","item":r})+run.ammo_bag.map(func(a):return {"kind":"ammo","item":a})+run.supplies.map(func(x):return {"kind":"supply","item":x})

## Swap two backpack cells (drag inside the backpack, T-168). Cells are grouped by kind (blueprints, ammo,
## aid kits), so only items of the same kind trade places. False when the cells hold different kinds.
static func swap(run,a:int,b:int)->bool:
	if run==null or a==b:return false
	var lists=[run.pending_recipes,run.ammo_bag,run.supplies];var start=0
	for list in lists:
		var end=start+list.size()
		if a>=start and a<end and b>=start and b<end:
			var keep=list[a-start];list[a-start]=list[b-start];list[b-start]=keep;return true
		start=end
	return false

## Bag ammo → the active slot (or a given one); the slot's special ammo comes back to the bag. Standard ammo
## is not an item and simply disappears from the slot.
static func equip(arena,bag_index:int,slot:=-1)->bool:
	var run=arena.run
	if bag_index<0 or bag_index>=run.ammo_bag.size():return false
	var item:Dictionary=run.ammo_bag[bag_index]
	if not Ammo.fits(str(item.type),str(arena.weapon)):return false
	Ammo.ensure(run,str(arena.weapon))
	if slot<0:slot=run.ammo_active
	slot=clampi(slot,0,run.ammo_slots.size()-1)
	# The same type already in the other slot: swap places instead of loading it twice.
	var old=run.ammo_slots[slot]
	run.ammo_bag.remove_at(bag_index)
	run.ammo_slots[slot]=item;run.ammo_active=slot
	if old is Dictionary and old.type!=Ammo.STANDARD:run.ammo_bag.insert(mini(bag_index,run.ammo_bag.size()),old)
	refresh(arena);return true
## A loaded special ammo → the backpack; the slot falls back to standard. Needs a free cell.
static func unequip(arena,slot:int)->bool:
	var run=arena.run
	if slot<0 or slot>=run.ammo_slots.size():return false
	var item=run.ammo_slots[slot]
	if not item is Dictionary or item.type==Ammo.STANDARD or full(run):return false
	run.ammo_bag.append(item);run.ammo_slots[slot]=Ammo.standard()
	refresh(arena);return true
## Can a drop happen right now: only in a battle with a soldier on the field.
static func can_drop(arena)->bool:
	return is_instance_valid(arena) and arena.get("phase") in ["combat","countdown","paused","upgrade"] and is_instance_valid(arena.room.player) and arena.is_inside_tree()
## Drops a bag entry (or a loaded ammo slot) as an army sack next to the soldier.
static func drop(arena,kind:String,index:int)->bool:
	if not can_drop(arena):return false
	var run=arena.run;var content={"recipes":[],"ammo":[]}
	match kind:
		"recipe":
			if index<0 or index>=run.pending_recipes.size():return false
			content.recipes.append(run.pending_recipes[index]);run.pending_recipes.remove_at(index)
		"ammo":
			if index<0 or index>=run.ammo_bag.size():return false
			content.ammo.append(run.ammo_bag[index]);run.ammo_bag.remove_at(index)
		"supply":
			if index<0 or index>=run.supplies.size():return false
			content["supplies"]=[run.supplies[index]];run.supplies.remove_at(index)
		"slot":
			var item=run.ammo_slots[index] if index>=0 and index<run.ammo_slots.size() else null
			if not item is Dictionary or item.type==Ammo.STANDARD:return false
			content.ammo.append(item);run.ammo_slots[index]=Ammo.standard()
		_:return false
	arena.reward.place_sack(arena.grid_pos(arena.room.player.position),content)
	refresh(arena);return true
## Picks a sack up when everything fits; otherwise it stays and says so.
static func pick_sack(arena,content:Dictionary)->bool:
	var run=arena.run;var count=content.recipes.size()+content.ammo.size()+content.get("supplies",[]).size()
	if free_cells(run)<count:arena.toast(Texts.render("Рюкзак полон"));return false
	run.pending_recipes.append_array(content.recipes);run.ammo_bag.append_array(content.ammo);run.supplies.append_array(content.get("supplies",[]))
	refresh(arena);return true
static func refresh(arena):
	if is_instance_valid(arena.hud):arena.hud.refresh_ammo()
## Uses the first aid kit from the backpack (H, a tap in the gear screen). Does nothing at full health.
static func use_medkit(arena,index:=0)->bool:
	var run=arena.run
	var kits=[]
	for i in range(run.supplies.size()):
		if str(run.supplies[i].get("type",""))=="medkit":kits.append(i)
	if kits.is_empty():arena.toast(Texts.render("В рюкзаке нет аптечек"));return false
	if run.soldier_hp>=run.soldier_max_hp-.01:arena.toast(Texts.render("Здоровье и так полное"));return false
	var at=index if index in kits else kits[0]
	var kit=run.supplies[at];run.supplies.remove_at(at)
	var healed=minf(float(kit.get("heal",1.0))*run.healing_multiplier,run.soldier_max_hp-run.soldier_hp)
	run.soldier_hp+=healed
	var player=arena.room.player
	if is_instance_valid(player) and player.kind=="soldier":player.hp=run.soldier_hp;player.refresh_health();arena.burst(player.position+Vector3.UP*.5,Color("ff6b6b"),.6)
	Game.sound("heal",arena);arena.toast(Texts.render("Аптечка: +%s здоровья") % str(snappedf(healed,.1)))
	refresh(arena);return true
static func medkits(run)->int:return run.supplies.filter(func(x):return str(x.get("type",""))=="medkit").size() if run!=null else 0
