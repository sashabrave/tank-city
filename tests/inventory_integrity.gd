extends Node
## Items are never lost or hidden (audit 2026-10-03): every move between hands, slots, backpack and field keeps
## the count, except explicit gain/use/destroy. Two-slot → one-slot gun, holstering, full backpack in battle
## (the extra lies on the field) and outside battle (the action is refused), machines and ammo cards.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
## Items the run holds: the gun in hand, loaded ammo, the backpack, and items lying on the field.
func count(arena)->int:
	var r=arena.run;var n=0
	if LootCatalog.is_gun(str(r.weapon)):n+=1
	for s in r.ammo_slots:
		if s is Dictionary and not Ammo.is_empty_slot(s):n+=1
	n+=r.ammo_bag.size()+r.weapon_bag.size()+r.supplies.size()+r.pending_recipes.size()
	for p in arena.room.pickups:
		if p.kind in ["item","sack"]:
			var c=p.get("content",{})
			n+=c.get("ammo",[]).size()+c.get("weapons",[]).size()+c.get("supplies",[]).size()+c.get("recipes",[]).size()
	return n
func fill(r,to:int):
	while Backpack.used(r)<to:r.ammo_bag.append(Ammo.roll("burn",0,Backpack.used(r)))
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	Game.backpack_slots=1;Game.ammo_slot_weapons=["pistol"]
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=5;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(.8).timeout
	arena.set_physics_process(false);arena.phase="combat"
	var r=arena.run;r.weapon="pistol";Ammo.ensure(r,"pistol")
	check(r.ammo_slots.size()==2,"the pistol has two ammo slots")
	r.ammo_slots[1]=Ammo.roll("cryo",3,7)
	# 1. Two slots → one slot, backpack has room: the second slot's ammo goes to the backpack.
	r.weapon_bag=[{"id":"rifle","rarity":0}];var before=count(arena)
	check(Backpack.equip_weapon(arena,0) and str(r.weapon)=="rifle" and count(arena)==before and r.ammo_bag.any(func(a):return a.type=="cryo"),"swap 2→1 slots: the cryo ammo goes to the backpack")
	# 2. Back to the pistol and holster with a full backpack in battle: the extra lies on the field.
	r.ammo_bag.clear();r.weapon_bag.clear();r.weapon="pistol";r.weapon_rarity=0;Ammo.ensure(r,"pistol");r.ammo_slots[1]=Ammo.roll("cryo",3,7)
	fill(r,Backpack.capacity()-1);before=count(arena)
	check(Backpack.holster(arena) and str(r.weapon)=="paws" and count(arena)==before,"holster with one free cell in battle: the gun takes it, the cryo lies on the field")
	check(arena.room.pickups.any(func(p):return p.get("content",{}).get("ammo",[]).any(func(a):return a.type=="cryo")),"the cryo ammo is on the field")
	# 3. Outside battle with a full backpack the swap is refused, nothing changes.
	for p in arena.room.pickups.duplicate():arena.room.pickups.erase(p)
	r.ammo_bag.clear();r.weapon_bag=[];r.weapon="pistol";Ammo.ensure(r,"pistol");r.ammo_slots[1]=Ammo.roll("cryo",3,7)
	r.weapon_bag=[{"id":"rifle","rarity":0}];fill(r,Backpack.capacity());arena.phase="result"
	before=count(arena)
	check(not Backpack.equip_weapon(arena,0) and str(r.weapon)=="pistol" and count(arena)==before,"full backpack outside battle: the swap is refused, nothing lost")
	check(not Backpack.holster(arena) and count(arena)==before,"full backpack outside battle: holstering is refused")
	check(Backpack.used(r)<=Backpack.capacity(),"never more items than cells")
	# 4. An ammo card with a full backpack in battle: the replaced ammo lies on the field.
	arena.phase="upgrade";r.weapon_bag.clear();before=count(arena)
	RunUpgrades.apply(arena,"shock",1)
	check(count(arena)==before+1 and Backpack.used(r)<=Backpack.capacity(),"ammo card with a full backpack: the old ammo goes to the field, no ninth cell")
	# 5. Machines refuse a spin / a crate with a full backpack (the prize would have no place).
	var vendor=preload("res://scripts/ammo_vendor.gd").new();vendor.arena=arena;r.tokens=20
	check(vendor.buy("army").is_empty() and r.tokens==20,"ammo machine: no sale with a full backpack, tokens kept")
	vendor.free()
	print("INVENTORY INTEGRITY: %d failures" % failures);get_tree().quit(1 if failures else 0)
