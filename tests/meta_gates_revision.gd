extends Node
# No base-level gates: permanent upgrades are limited only by price and fixed caps from economy.tres.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	var e=Balance.CONFIG.economy
	Game.progression.level=1;Game.credits=10000000;Game.cores=100
	Game.built_workshops=["weapons","headquarters","garage","bonuses","character"]
	Game.weapon_unlocks=["pistol","rifle"]
	for i in range(e.weapon_level_cap+2):Game.upgrade_weapon("rifle")
	check(Game.weapon_level("rifle")==e.weapon_level_cap,"weapon levels up to the fixed cap at base level 1")
	for i in range(e.insurance_cap+2):Game.buy_insurance()
	check(Game.progression.insurance==e.insurance_cap,"insurance up to its cap")
	Game.bonus_unlocks=["heart","repair"]
	for i in range(e.bonus_level_cap+2):Game.upgrade_bonus("repair")
	check(Game.bonus_level("repair")==e.bonus_level_cap,"bonus levels up to their cap")
	check(Game.upgrade_cap("heal")==e.branch_cap and Game.upgrade_cap("supplies")==e.supplies_cap,"branch caps are fixed")
	Game.ability_unlocks.append("laser")
	check(Game.ability_available("laser"),"late gadgets need only the blueprint")
	for id in HQCatalog.DATA:Game.hq_unlocks.append(id)
	check(HQCatalog.DATA.keys().all(func(id):return HQCatalog.available(id)) and HQCatalog.cap()==e.hq_level_cap,"every known HQ technology usable")
	Game.garage.unlocks=["vehicle_buggy","vehicle_apc","vehicle_tank"]
	check(Game.garage.buy("buggy") and Game.garage.buy("apc") and Game.garage.buy("tank"),"vehicles need only blueprint, order and price")
	check(Game.garage.cap("tank")==e.vehicle_equipment_cap,"vehicle equipment cap is fixed")
	var memory=preload("res://scripts/ui/tablet_memory.gd");memory.loaded=true;memory.state={}
	var view=preload("res://scripts/ui/field_tablet.gd").new();view.manage=true;add_child(view);await settle()
	check(view.tab=="quests","command centre opens on quests")
	check(view.find_child("Nav_quests",true,false)!=null and view.find_child("Nav_base",true,false)!=null and view.find_child("Nav_inventory",true,false)==null,"command centre keeps quests and a summary")
	view.tab="base";view.refresh();await settle()
	check(view.find_child("Summary",true,false)!=null,"summary renders")
	view.queue_free();await settle()
	print("META GATES: %d failures" % failures);get_tree().quit(1 if failures else 0)
