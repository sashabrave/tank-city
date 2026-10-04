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
	arena.queue_free();await get_tree().process_frame
	await gear_rules()
	await ammo_rules()
	print("INVENTORY INTEGRITY: %d failures" % failures);get_tree().quit(1 if failures else 0)
func fresh_arena(seed:int)->Node:
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=seed;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(.8).timeout
	arena.set_physics_process(false)
	return arena
func cell_of(r,kind:String)->int:
	for c in range(Backpack.CELLS):
		var e=Backpack.layout(r)[c]
		if e!=null and e.kind==kind:return c
	return -1
## from gear_backpack_revision + tablet_v15: backpack rules through the Backpack API (what the gear page's taps and
## drags call), without clicking the tablet.
func gear_rules():
	Game.backpack_slots=1;Game.ammo_slot_weapons=[]
	# from tablet_v15: 8 cells, the first ones open at start; bought backpack levels open the rest.
	check(Backpack.CELLS==8 and Backpack.capacity()==4,"backpack: %d cells, 4 open at start" % Backpack.CELLS)
	Game.backpack_slots=6;check(Backpack.capacity()==Backpack.CELLS,"backpack level 6 opens every cell")
	Game.backpack_slots=1
	var arena=await fresh_arena(12);arena.phase="paused"
	var r=arena.run;Ammo.ensure(r,arena.weapon)
	r.ammo_bag.append(Ammo.roll("burn",1,3));r.ammo_bag.append(Ammo.roll("cryo",2,4))
	# Use = Backpack.equip: the bag ammo goes in, the plain rounds come out as an item.
	check(Ammo.active(r)=="standard" and Backpack.equip(arena,0) and Ammo.active(r)=="burn" and r.ammo_bag.size()==2 and r.ammo_bag.any(func(a):return a.type=="standard"),"loading bag ammo: the plain rounds go to the bag")
	r.ammo_bag=r.ammo_bag.filter(func(a):return a.type!="standard")
	var ci=r.ammo_bag.find_custom(func(a):return a.type=="cryo")
	check(Backpack.equip(arena,ci) and Ammo.active(r)=="cryo" and r.ammo_bag.size()==1 and r.ammo_bag[0].type=="burn","equipping swaps with the loaded ammo")
	check(Backpack.unequip(arena,0) and Ammo.is_empty_slot(r.ammo_slots[0]) and r.ammo_bag.size()==2,"unloading a slot: ammo to the backpack, the slot is empty")
	ci=r.ammo_bag.find_custom(func(a):return a.type=="cryo")
	check(Backpack.equip(arena,ci,0) and Ammo.active(r)=="cryo","bag → slot loads")
	check(Backpack.unequip(arena,0) and Ammo.is_empty_slot(r.ammo_slots[0]) and r.ammo_bag.size()==2,"slot → bag unloads")
	# T-168/T-196: free layout — two items trade cells; an item moves into an empty open cell; locked cells refuse.
	var ammo_cells=[]
	for c in range(Backpack.CELLS):
		if Backpack.layout(r)[c]!=null and Backpack.layout(r)[c].kind=="ammo":ammo_cells.append(c)
	var first_type=str(Backpack.layout(r)[ammo_cells[0]].item.type);var second_type=str(Backpack.layout(r)[ammo_cells[1]].item.type)
	Backpack.place(r,ammo_cells[0],ammo_cells[1])
	check(str(Backpack.layout(r)[ammo_cells[0]].item.type)==second_type and str(Backpack.layout(r)[ammo_cells[1]].item.type)==first_type,"moving inside the backpack swaps two ammo boxes")
	check(not Backpack.swap(r,0,99),"no swap with a cell that does not exist")
	r.pending_recipes.append({"id":"smg","category":"weapon"})
	var cells=Backpack.layout(r);var bp=-1;var box=-1;var empty=-1
	for c in range(Backpack.capacity()):
		if cells[c]==null and empty<0:empty=c
		elif cells[c]!=null and cells[c].kind=="recipe" and bp<0:bp=c
		elif cells[c]!=null and cells[c].kind=="ammo" and box<0:box=c
	Backpack.place(r,bp,box);cells=Backpack.layout(r)
	check(cells[box].kind=="recipe" and cells[bp].kind=="ammo","a blueprint and an ammo box trade cells")
	if empty>=0:
		Backpack.place(r,box,empty)
		check(Backpack.layout(r)[empty]!=null and Backpack.layout(r)[empty].kind=="recipe" and Backpack.layout(r)[box]==null,"an item moves into an empty cell")
	check(not Backpack.place(r,0,Backpack.capacity()),"locked cells refuse items")
	# «Сейф»: the blueprint in the first safe cell is the insured one.
	r.safe_slots=1
	var at=cell_of(r,"recipe")
	if at!=0:Backpack.place(r,at,0)
	var order=Backpack.safe_order(r)
	check(order[1]==1 and order[0][0].id=="smg","the blueprint in the safe cell is the insured one")
	r.safe_slots=0;r.pending_recipes.clear()
	# Weapons as backpack items: a spare gun swaps with the gun in hand; the gun in hand can go into a free cell.
	var in_hand=str(r.weapon);var spare="shotgun" if in_hand!="shotgun" else "smg"
	while Backpack.full(r) and not r.ammo_bag.is_empty():r.ammo_bag.pop_back()
	check(Backpack.add_weapon(arena,{"id":spare,"rarity":1}),"a spare weapon goes into the backpack")
	var gun_cell=cell_of(r,"weapon");var free_cell=-1
	for c in range(Backpack.capacity()):
		if Backpack.layout(r)[c]==null and free_cell<0:free_cell=c
	Backpack.equip_weapon(arena,Backpack.layout(r)[gun_cell].index)
	check(str(r.weapon)==spare and r.weapon_bag.size()==1 and str(r.weapon_bag[0].id)==in_hand and Backpack.layout(r)[gun_cell].kind=="weapon","equipping the spare swaps the guns in place")
	if free_cell>=0:
		check(Backpack.holster(arena,free_cell) and Backpack.holstered(r) and str(r.weapon)=="paws" and Backpack.layout(r)[free_cell].kind=="weapon" and str(Backpack.layout(r)[free_cell].item.id)==spare,"the gun in hand goes into an empty cell: paws in hand")
		Backpack.equip_weapon(arena,Backpack.layout(r)[free_cell].index)
		check(not Backpack.holstered(r) and str(r.weapon)==spare and Backpack.layout(r)[free_cell]==null,"taking it back fills the hands and frees the cell")
	Backpack.equip_weapon(arena,Backpack.layout(r)[gun_cell].index)
	check(str(r.weapon)==in_hand,"swapping back returns the first gun")
	var data=preload("res://scripts/profile/run_checkpoint.gd").upgrade({"run":{"weapon_bag":[{"id":"shotgun"},{"id":"nope"}]}})
	check(data.run.weapon_bag.size()==1,"a saved run keeps valid spare weapons only")
	# Rolled crate stats count while that gun is in hand.
	var plain=CombatStats.weapon(arena,"rifle")
	Backpack.add_weapon(arena,{"id":"rifle","rarity":2,"stats":{"damage":.2,"fire":.1}})
	Backpack.equip_weapon(arena,r.weapon_bag.size()-1)
	var rolled=CombatStats.weapon(arena,"rifle")
	check(absf(rolled.damage/plain.damage-1.2)<.01 and rolled.interval<plain.interval,"a crate gun's rolled damage and fire rate apply in hand")
	r.weapon=in_hand;r.weapon_stats={};r.weapon_rarity=0;r.weapon_bag.clear()
	# Full backpack: unloading is refused, nothing is lost.
	Backpack.equip(arena,0);r.pending_recipes.append({"id":"smg","category":"weapon"});r.ammo_bag.append(Ammo.roll("shock",0,1));r.ammo_bag.append(Ammo.roll("stun",0,2))
	check(Backpack.full(r) and not Backpack.unequip(arena,0) and Ammo.active(r)!="standard","full backpack keeps the loaded ammo")
	# Drop: the item itself lies on the field; walking over a single item does not take it; «C» stashes it back.
	var before=Backpack.used(r);var items=arena.room.pickups.filter(func(p):return p.kind=="item").size()
	check(Backpack.drop(arena,"ammo",Backpack.layout(r)[cell_of(r,"ammo")].index) and Backpack.used(r)==before-1 and arena.room.pickups.filter(func(p):return p.kind=="item").size()==items+1,"dropped ammo lies on the field as itself")
	check(Backpack.drop(arena,"recipe",0) and r.pending_recipes.is_empty() and arena.room.pickups.filter(func(p):return p.kind=="item").size()==items+2,"blueprints can be dropped too")
	var dropped=arena.room.pickups.filter(func(p):return p.kind=="item")[0]
	arena.reward.collect_pickup(dropped)
	check(dropped in arena.room.pickups,"walking over a single item does not pick it up")
	var stashed=false
	for card in get_tree().get_nodes_in_group("drop_prompts"):
		if card.pickup==dropped:card.stash();stashed=true
	if not stashed:stashed=Backpack.pick_sack(arena,dropped.content)
	check(stashed and Backpack.used(r)==before-1,"stashing puts it back into the backpack")
	# Plain rounds are an item too (T-197): dropped, the slot is empty.
	var gun_before=str(r.weapon);var std_slot=-1
	for i in range(r.ammo_slots.size()):
		if str(r.ammo_slots[i].type)==Ammo.STANDARD:std_slot=i
	if std_slot>=0:
		check(Backpack.drop(arena,"slot",std_slot) and Ammo.is_empty_slot(r.ammo_slots[std_slot]),"the plain rounds can be thrown away: the slot is empty")
		r.ammo_slots[std_slot]=Ammo.standard()
	r.weapon="";check(arena.ensure_armed() and str(r.weapon)==Game.selected_weapon,"no gun in hand: the HQ issues the chosen one")
	# Entering a battle: no gun anywhere → the hub's one; a gun in the backpack → the paws stay; no rounds → plain ones.
	var keep_gun=str(r.weapon);var keep_bag=r.weapon_bag.duplicate(true)
	r.weapon="paws";r.weapon_bag.clear()
	check(arena.ensure_armed(true) and str(r.weapon)==Game.selected_weapon,"battle start without any gun: the hub's one is issued")
	r.weapon="paws";r.weapon_bag=[{"id":"smg"}]
	arena.ensure_armed(true);check(str(r.weapon)=="paws","a gun in the backpack: empty hands stay the player's choice")
	r.weapon=keep_gun;r.weapon_bag=keep_bag;Ammo.ensure(r,keep_gun)
	var keep_slots=r.ammo_slots.duplicate(true);var keep_ammo=r.ammo_bag.duplicate(true)
	for i in range(r.ammo_slots.size()):r.ammo_slots[i]=Ammo.empty()
	r.ammo_bag.clear()
	check(arena.ensure_armed(true) and not Ammo.dry(r),"battle start without any rounds: plain ones are loaded")
	r.ammo_slots=keep_slots;r.ammo_bag=keep_ammo
	r.weapon=gun_before;Ammo.ensure(r,gun_before)
	# Empty hands: paws deal the bare-hand damage grown by «Сила»; Space and V scratch.
	while Backpack.free_cells(r)<2 and not r.ammo_bag.is_empty():r.ammo_bag.pop_back()
	check(Backpack.holster(arena) and str(r.weapon)=="paws","the gun can be put away any time")
	var level=Game.damage_level;Game.damage_level=0;var bare=Melee.damage(arena);Game.damage_level=4
	check(absf(Melee.damage(arena)/bare-1.2)<.01,"«Сила» grows the bare-hand damage (+5% per level)")
	Game.damage_level=level
	arena.phase="combat"
	var foe=arena.spawn_actor("soldier",arena.find_free_near(arena.player.cell+arena.player.facing),false,false,1)
	foe.position=arena.player.position+Vector3(arena.player.facing.x,0,arena.player.facing.y)*1.0;var hp=foe.hp
	arena.player.fire_cooldown=0;arena.player.shoot()
	check(foe.hp<hp,"Space with empty hands scratches the enemy in front")
	hp=foe.hp;arena.player.set_meta("melee_ready_at",0.0)
	check(Melee.try(arena) and foe.hp<hp,"V strikes too")
	check(not Melee.try(arena),"V has its own short cooldown")
	foe.dead=true;arena.room.actors.erase(foe);foe.queue_free()
	Backpack.equip_weapon(arena,r.weapon_bag.size()-1)
	check(str(r.weapon)==gun_before and r.weapon_bag.is_empty(),"taking the gun back leaves no paws item behind")
	# A gun in hand: V is a butt strike (×BUTT of the bare hand), Space stays an ordinary shot.
	foe=arena.spawn_actor("soldier",arena.find_free_near(arena.player.cell+arena.player.facing),false,false,1)
	foe.position=arena.player.position+Vector3(arena.player.facing.x,0,arena.player.facing.y)*1.0;foe.hp=99.0;foe.max_hp=99.0;foe.invulnerable=0
	arena.player.set_meta("melee_ready_at",0.0);RunUpgrades.refresh_player(arena)
	Melee.try(arena)
	check(absf((99.0-foe.hp)-Melee.damage(arena)*Melee.BUTT)<.05,"with a gun V hits with the butt (%.2f)" % (99.0-foe.hp))
	var bullets=arena.room.projectiles.size() if arena.room.get("projectiles")!=null else -1
	foe.hp=99.0;arena.player.fire_cooldown=0;arena.player.shoot()
	check(foe.hp==99.0 and (bullets<0 or arena.room.projectiles.size()>bullets),"with a gun Space shoots, it does not scratch")
	foe.dead=true;arena.room.actors.erase(foe);foe.queue_free()
	check(not "paws" in Game.LOOT.gun_ids() and not "paws" in Game.recipe_catalog("weapon"),"the paws are never listed, found or unlocked")
	r.weapon=gun_before;r.weapon_bag.clear();Ammo.ensure(r,gun_before)
	arena.phase="result";check(not Backpack.can_drop(arena),"no dropping outside battle")
	check(InputMap.action_get_events("pause").any(func(e):return e is InputEventKey and e.physical_keycode==KEY_TAB),"Tab opens and closes the tablet")
	# Aid kits (T-115): at full health a heart goes into the backpack; H heals from it later.
	arena.phase="combat"
	r.supplies.clear();while Backpack.full(r) and not r.ammo_bag.is_empty():r.ammo_bag.pop_back()
	r.soldier_hp=r.soldier_max_hp;arena.player.hp=r.soldier_hp
	arena.reward.place_pickup(arena.grid_pos(arena.player.position),"heart",0.0)
	var heart=arena.room.pickups.filter(func(p):return p.kind=="heart")[0]
	arena.reward.collect_pickup(heart)
	check(Backpack.medkits(r)==1,"full health: the aid kit goes into the backpack")
	check(not Backpack.use_medkit(arena),"no use at full health")
	r.soldier_hp=1.0;arena.player.hp=1.0
	check(Backpack.use_medkit(arena) and r.soldier_hp>1.0 and Backpack.medkits(r)==0,"H heals from the backpack")
	arena.queue_free();await get_tree().process_frame
## from ammo_slots_revision: ammo items, rolls, classes, cards, slots, the vending machine price and odds, combat effects.
func ammo_rules():
	Game.ammo_slot_weapons=[]
	var arena=await fresh_arena(12)
	var run=arena.run;Ammo.ensure(run,arena.weapon)
	check(Ammo.active(run)=="standard" and run.ammo_slots.size()==1,"starts with standard ammo")
	var low=Ammo.roll("burn",0,7);var high=Ammo.roll("burn",3,7)
	check(high.stats.chance>low.stats.chance and high.twist and not low.twist and high.damage>0,"rarer ammo rolls higher values, epic+ adds damage, legendary a twist")
	check(Ammo.roll("cryo",1,99)==Ammo.roll("cryo",1,99),"same seed, same item")
	check(Ammo.fits("explosive","pistol") and not Ammo.fits("explosive","rpg") and Ammo.fits("burn","rpg"),"bullets and charges classes")
	var heat=UpgradeRegistry.get_def("burn_heat")
	check(RunUpgrades.eligible(arena,UpgradeRegistry.get_def("burn")) and not RunUpgrades.eligible(arena,heat),"ammo card offered, its improvement not yet")
	var card=RunUpgrades.card(arena,{"id":"burn","tier":2})
	check(str(card.short).contains("Зарядит") and card.rows.size()>=2 and str(card.rows[0][0]).begins_with("↑"),"card loads it and shows rolled values as gains")
	RunUpgrades.apply(arena,"burn",2)
	check(Ammo.active(run)=="burn" and Ammo.item(run).rarity==2,"incendiary item loaded with its rarity")
	check(RunUpgrades.eligible(arena,heat),"improvements of loaded ammo are offered")
	card=RunUpgrades.card(arena,{"id":"cryo","tier":0})
	check(str(card.short).contains("Заменит"),"card shows the replacement")
	RunUpgrades.apply(arena,"cryo",0)
	check(Ammo.active(run)=="cryo" and run.ammo_bag.any(func(a):return a.type=="burn"),"cryo replaces fire; the old ammo goes to the bag")
	run.ammo_bag=run.ammo_bag.filter(func(a):return a.type!="standard")
	check(not RunUpgrades.eligible(arena,heat),"fire improvements stop dropping")
	var enemy=arena.spawn_actor("soldier",Vector2i(4,3),false)
	var bullet=load("res://scenes/projectile.tscn").instantiate();bullet.arena=arena;bullet.owner_actor=arena.player;bullet.friendly=true;bullet.damage=1.0;add_child(bullet)
	CombatMods.outgoing(arena,bullet,enemy)
	check(enemy.slow_time>0 and enemy.slow_factor>=.2,"cryo hit slows the enemy (%.2f)" % enemy.slow_factor)
	bullet.queue_free()
	Game.ammo_slot_weapons.append(arena.weapon);Ammo.ensure(run,arena.weapon)
	check(run.ammo_slots.size()==2,"Arsenal second slot gives two cells")
	RunUpgrades.apply(arena,"stun",1)
	check(Ammo.types_loaded(run).has("cryo") and Ammo.active(run)=="stun","two ammo types loaded, the new one active")
	Ammo.switch(arena);check(Ammo.active(run)=="cryo","switching makes the other type active")
	# T-243: a card for the ammo already loaded is an upgrade — one rarity higher, no value goes down.
	var loaded_shock={"type":"shock","rarity":0,"stats":{"bonus":.27,"jolt":.07},"damage":0.0,"twist":false}
	run.ammo_slots[0]=loaded_shock.duplicate(true)
	var upgrade_card=RunUpgrades.card(arena,{"id":"shock","tier":0})
	check(int(upgrade_card.tier)==1 and str(upgrade_card.swap.action).contains("→") and not str(upgrade_card.swap.action).ends_with(Texts.render("обычные")),"loaded EMP: the card offers a rarer box (%s)" % upgrade_card.swap.action)
	var never_lower=true
	for row in upgrade_card.rows:never_lower=never_lower and float(str(row[3]).to_float())>=float(str(row[2]).to_float())
	check(never_lower and not upgrade_card.rows.is_empty(),"upgrade card: every value after ≥ before")
	RunUpgrades.apply(arena,"shock",0)
	var shock_now=Ammo.loaded_item(run,"shock")
	check(int(shock_now.rarity)==1 and float(shock_now.stats.jolt)>=.07 and float(shock_now.stats.bonus)>=.27,"taken: the loaded EMP is rare and kept its better values")
	shock_now.rarity=3
	check(not RunUpgrades.eligible(arena,UpgradeRegistry.get_def("shock")),"legendary EMP loaded: the EMP box card is no longer offered")
	run.ammo_bag=run.ammo_bag.filter(func(a):return a.type!="standard")
	# Ammo vending machine (T-116/T-159): tokens → a fitting rolled item at the crate price; odds add up, officer is richer.
	Game.ammo_slot_weapons=[];Ammo.ensure(run,arena.weapon)
	var holder=Node3D.new()
	var vendor=preload("res://scripts/ammo_vendor.gd").place(holder,arena,Vector3.ZERO)
	run.tokens=2;check(vendor.buy().is_empty() and run.tokens==2,"machine needs tokens")
	while Backpack.full(run) and not run.ammo_bag.is_empty():run.ammo_bag.pop_back()
	run.tokens=10;var got=vendor.buy()
	check(run.tokens==10-vendor.PRICE and Ammo.fits(str(got.type),arena.weapon) and got.has("stats"),"machine sells a fitting rolled item (%s)" % got.get("type",""))
	var deep=vendor.odds("officer");var near=vendor.odds("army")
	check(absf(deep.reduce(func(a,x):return a+x,0.0)-1.0)<.001 and deep[3]>near[3],"odds add up to 100% and the officer crate is richer")
	holder.free()
	# Charges (T-114): the grenade launcher takes charge ammo; napalm leaves a burning patch.
	check(Game.LOOT.WEAPONS.has("grenade_launcher") and Ammo.fits("napalm","grenade_launcher") and not Ammo.fits("napalm","pistol"),"grenade launcher with charge ammo")
	arena.run.weapon="grenade_launcher";arena.weapon="grenade_launcher";Ammo.ensure(run,"grenade_launcher")
	Ammo.load_item(run,Ammo.roll("napalm",1,5))
	var rocket=load("res://scenes/projectile.tscn").instantiate();rocket.arena=arena;rocket.owner_actor=arena.player;rocket.friendly=true;rocket.damage=2.0;rocket.rocket_radius=1.1;rocket.position=arena.world_pos(Vector2i(5,5));add_child(rocket)
	arena.combat.rocket_impact(rocket)
	check(arena.get_children().any(func(n):return n.get_script()==preload("res://scripts/combat/napalm_patch.gd")),"napalm charge leaves a burning patch")
	rocket.queue_free()
	# T-156: armor-piercing rounds break a raised riot shield with a chance that grows with rarity.
	var ap_low=Ammo.roll("ap",0,7);var ap_high=Ammo.roll("ap",3,7)
	check(Ammo.shield_pierce(ap_low)>=.25 and Ammo.shield_pierce(ap_high)>Ammo.shield_pierce(ap_low) and Ammo.shield_pierce(Ammo.roll("burn",0,1))==0.0,"AP shield chance grows with rarity, other ammo has none")
	check(Ammo.describe(ap_high).contains("%d%%" % roundi(Ammo.shield_pierce(ap_high)*100)),"AP ammo describes its shield chance")
	arena.queue_free();await get_tree().process_frame
