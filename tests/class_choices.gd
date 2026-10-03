extends Node3D
## Class abilities (0.8.0 class path): own Q per class without repeats, abilities open at levels 1/7/14,
## two slots from level 7, any unlocked ability goes into any slot (free, swaps), saved in the profile.
## Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	var qs=ClassCatalog.ROSTER.map(func(id):return Game.CLASS_SKILLS[id])
	check(qs.size()==Array(qs).reduce(func(acc,q):return acc if q in acc else acc+[q],[]).size(),"no Q repeats between classes")
	for id in ClassCatalog.ROSTER:
		check(ClassCatalog.abilities(id).size()==3 and ClassCatalog.abilities(id).all(func(a):return AbilityCatalog.DATA.has(a)),"three real abilities: "+id)
	Game.class_unlocks=["recruit","marksman"];Game.selected_class="recruit";Game.class_levels={}
	check(Game.class_loadout().is_empty(),"level 1: no abilities at the start")
	Game.class_levels.recruit=2
	check(Game.class_loadout()==["grenade"],"level 3: Q in the first slot")
	Game.class_levels.recruit=7
	check(ClassCatalog.level("recruit")==8 and Game.class_loadout()==["grenade","comrade"],"level 8: second ability in the second slot")
	check(not Game.set_class_slot("recruit",1,"mine"),"the third ability is closed before level 14")
	Game.class_levels.recruit=13
	check(Game.set_class_slot("recruit",1,"mine") and Game.class_loadout()==["grenade","mine"],"level 14: any unlocked ability into a slot")
	check(Game.set_class_slot("recruit",0,"mine") and Game.class_loadout()==["mine","grenade"],"putting the other slot's ability swaps them")
	check(not Game.set_class_slot("recruit",1,"laser"),"a foreign ability is refused")
	check(Game.set_class_slot("recruit",1,"") and Game.class_slot_layout("recruit")==["mine",""] and Game.class_loadout()==["mine"],"a slot can be emptied")
	Game.set_class_slot("recruit",1,"grenade")
	Game.purchased_gadgets=["mine","barrier"];Game.ability_unlocks.append("mine");Game.gadget="mine"
	check(not Game.hero_loadout().count("mine")>1,"a gadget equal to a slot is not doubled")
	var data=Game.serialize_progress()
	check(data.class_slots.get("recruit")==["mine","grenade"],"slots are in the profile")
	data.class_slots={"recruit":["laser","grenade"]}
	Game.apply_profile(data.duplicate(true))
	check(Game.class_loadout()[0]=="grenade","loading drops abilities the class does not have")
	var station=load("res://scripts/ui/stations/fighter_station.gd").new()
	check(station.page_for("shells")!=null,"Barracks «Классы» is the class page")
	print("CLASS CHOICES: %d failures" % failures);get_tree().quit(1 if failures else 0)
