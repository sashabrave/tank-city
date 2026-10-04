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
static func used(run)->int:return run.pending_recipes.size()+run.ammo_bag.size()+run.supplies.size()+run.weapon_bag.size() if run!=null else 0
static func free_cells(run)->int:return capacity()-used(run)
static func full(run)->bool:return free_cells(run)<=0
## Items in cell order: blueprints, then ammo. Each entry {kind:"recipe"|"ammo", item}.
static func items(run)->Array:
	if run==null:return []
	return run.pending_recipes.map(func(r):return {"kind":"recipe","item":r})+run.ammo_bag.map(func(a):return {"kind":"ammo","item":a})+run.supplies.map(func(x):return {"kind":"supply","item":x})

## Free layout (T-196): every item remembers its cell (item["cell"]); new items take the first free cell.
## Returns CELLS entries — null or {kind, index (in its own list), item}. Cells past capacity() are locked.
static func layout(run)->Array:
	var cells=[];cells.resize(CELLS)
	if run==null:return cells
	var entries=[]
	for pair in [["recipe",run.pending_recipes],["ammo",run.ammo_bag],["supply",run.supplies],["weapon",run.weapon_bag]]:
		for k in range(pair[1].size()):entries.append({"kind":pair[0],"index":k,"item":pair[1][k]})
	var waiting=[]
	for e in entries:
		var c=int(e.item.get("cell",-1)) if e.item is Dictionary else -1
		if c>=0 and c<CELLS and cells[c]==null:cells[c]=e
		else:waiting.append(e)
	for e in waiting:
		for c in range(CELLS):
			if cells[c]==null:
				cells[c]=e
				if e.item is Dictionary:e.item["cell"]=c
				break
	return cells
## Moves the item in one cell to another open cell; an item already there takes the first cell (swap).
static func place(run,from:int,to:int)->bool:
	if run==null or from==to or to<0 or to>=capacity() or from<0 or from>=CELLS:return false
	var cells=layout(run);var a=cells[from]
	if a==null:return false
	var b=cells[to]
	a.item["cell"]=to
	if b!=null:b.item["cell"]=from
	return true
static func swap(run,a:int,b:int)->bool:return place(run,a,b)
## Cells whose blueprints survive a knock-out (card «Сейф рюкзака»): the first N open cells.
static func safe_cells(run)->int:return mini(capacity(),int(run.safe_slots)) if run!=null else 0
## Blueprints in safe cells first, and how many of the non-building ones are in safe cells.
static func safe_order(run)->Array:
	var safe=safe_cells(run);var cells=layout(run);var first=[];var rest=[];var count=0
	for c in range(CELLS):
		var e=cells[c]
		if e==null or e.kind!="recipe":continue
		if c<safe:
			first.append(e.item)
			if str(e.item.get("category",""))!="research":count+=1
		else:rest.append(e.item)
	return [first+rest,count]

## Empty hands (2026-10-03): the gun goes into a backpack cell and the cat fights with its paws (the hidden
## «paws» weapon: Space and V scratch, damage grows with «Сила»). Any time, anywhere a run is on; the tablet
## closes as usual — the gear page only reminds to take a gun.
## One rule for every item that has to go somewhere (audit 2026-10-03): the backpack if a cell is free, else a
## sack at the soldier's feet when there is a field; otherwise false and nothing changes — the caller must not
## have taken the item yet (check room() first). Never a hidden ninth cell, never a silent loss.
static func stow(arena,item:Dictionary,kind:="ammo")->bool:
	var run=arena.run
	if not full(run):
		match kind:
			"weapon":run.weapon_bag.append(item)
			"supply":run.supplies.append(item)
			"recipe":run.pending_recipes.append(item)
			_:run.ammo_bag.append(item)
		return true
	if can_drop(arena):
		var content={"recipes":[],"ammo":[]}
		match kind:
			"weapon":content["weapons"]=[item]
			"supply":content["supplies"]=[item]
			"recipe":content.recipes.append(item)
			_:content.ammo.append(item)
		arena.reward.place_sack(arena.grid_pos(arena.room.player.position),content);arena.toast(Texts.render("Рюкзак полон — предмет лежит рядом"))
		return true
	return false
static func stow_all(arena,items:Array,kind:="ammo"):
	for item in items:stow(arena,item,kind)
## Can `count` items be put away right now (free cells, or a field to drop them on)?
static func room_for(arena,count:int)->bool:return count<=0 or free_cells(arena.run)>=count or can_drop(arena)
static func holstered(run)->bool:return run!=null and str(run.weapon)==LootCatalog.PAWS
static func holster(arena,cell:=-1)->bool:
	var run=arena.run
	if run==null or holstered(run) or full(run):return false
	# The gun takes a cell; ammo the paws cannot hold must fit too (or drop on the field).
	if not (free_cells(run)>=1+Ammo.overflow(run,LootCatalog.PAWS) or can_drop(arena)):
		arena.toast(Texts.render("Рюкзак полон — некуда убрать боеприпасы второго слота"));return false
	var item={"id":str(run.weapon),"rarity":int(run.weapon_rarity),"stats":run.weapon_stats.duplicate()}
	if cell>=0 and cell<capacity() and layout(run)[cell]==null:item["cell"]=cell
	run.weapon_bag.append(item)
	run.weapon=LootCatalog.PAWS;run.weapon_rarity=0;run.weapon_stats={}
	stow_all(arena,Ammo.ensure(run,run.weapon));RunUpgrades.refresh_player(arena);refresh(arena);return true
## A gun waiting in the backpack while the paws fight (the reminder on the gear page and after the tablet).
static func spare_gun(run)->bool:return run!=null and not run.weapon_bag.is_empty()
## A spare weapon into the backpack (weapon crates, the gun in hand dragged out); false when it is full.
static func add_weapon(arena,item:Dictionary,cell:=-1)->bool:
	var run=arena.run
	if full(run) or not Game.LOOT.is_gun(str(item.get("id",""))):return false
	var copy=item.duplicate(true)
	if cell>=0 and cell<capacity() and layout(run)[cell]==null:copy["cell"]=cell
	run.weapon_bag.append(copy);refresh(arena);return true
## Takes a backpack weapon in hand: the one in hand goes to that cell (a swap, so nothing is lost).
static func equip_weapon(arena,index:int)->bool:
	var run=arena.run
	if index<0 or index>=run.weapon_bag.size():return false
	var item:Dictionary=run.weapon_bag[index]
	# A one-slot gun cannot hold the second slot's ammo: it goes to the backpack (or the field) — check first.
	var spill=Ammo.overflow(run,str(item.id));var freed=1 if holstered(run) else 0
	if not (free_cells(run)+freed>=spill or can_drop(arena)):
		arena.toast(Texts.render("Рюкзак полон — некуда убрать боеприпасы второго слота"));return false
	var old={"id":str(run.weapon),"rarity":int(run.weapon_rarity),"stats":run.weapon_stats.duplicate()}
	if item.has("cell"):old["cell"]=item.cell
	# Bare paws are not an item: the taken gun simply leaves its cell.
	if holstered(run):run.weapon_bag.remove_at(index)
	else:run.weapon_bag[index]=old
	run.weapon=str(item.id);run.weapon_rarity=int(item.get("rarity",0));run.weapon_stats=item.get("stats",{}).duplicate()
	stow_all(arena,Ammo.ensure(run,run.weapon))
	RunUpgrades.refresh_player(arena);refresh(arena);return true

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
	# The ammo coming out of the slot takes the cell of the one going in.
	if old is Dictionary and item.has("cell"):old["cell"]=item.cell
	run.ammo_bag.remove_at(bag_index)
	run.ammo_slots[slot]=item;run.ammo_active=slot
	# Every loaded item is an item, plain rounds too (author, T-197): the replaced one goes to the backpack
	# (the swap always has room — the new one just left it). An empty slot gives nothing back.
	if old is Dictionary and old.type!=Ammo.EMPTY:run.ammo_bag.insert(mini(bag_index,run.ammo_bag.size()),old)
	refresh(arena);return true
## A loaded special ammo → the backpack; the slot falls back to standard. Needs a free cell.
static func unequip(arena,slot:int)->bool:
	var run=arena.run
	if slot<0 or slot>=run.ammo_slots.size():return false
	var item=run.ammo_slots[slot]
	if not item is Dictionary or item.type==Ammo.EMPTY or full(run):return false
	run.ammo_bag.append(item);run.ammo_slots[slot]=Ammo.empty()
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
		"weapon":
			if index<0 or index>=run.weapon_bag.size():return false
			content["weapons"]=[run.weapon_bag[index]];run.weapon_bag.remove_at(index)
		"slot":
			var item=run.ammo_slots[index] if index>=0 and index<run.ammo_slots.size() else null
			if not item is Dictionary or item.type==Ammo.EMPTY:return false
			content.ammo.append(item);run.ammo_slots[index]=Ammo.empty()
		_:return false
	arena.reward.place_sack(arena.grid_pos(arena.room.player.position),content)
	refresh(arena);return true
## Picks a sack up when everything fits; otherwise it stays and says so.
static func pick_sack(arena,content:Dictionary)->bool:
	var run=arena.run;var count=content.recipes.size()+content.ammo.size()+content.get("supplies",[]).size()+content.get("weapons",[]).size()
	if free_cells(run)<count:arena.toast(Texts.render("Рюкзак полон"));return false
	run.pending_recipes.append_array(content.recipes);run.ammo_bag.append_array(content.ammo);run.supplies.append_array(content.get("supplies",[]));run.weapon_bag.append_array(content.get("weapons",[]))
	refresh(arena);return true
static func refresh(arena):
	if arena.has_method("ensure_armed") and arena.ensure_armed():RunUpgrades.refresh_player(arena)
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
