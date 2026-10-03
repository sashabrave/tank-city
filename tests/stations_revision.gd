extends Node
# Four hub stations on one template: Боец always, Арсенал / Штаб / Стоянка after building; retired buildings migrate.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame
func screen(hub)->Control:return hub.build_menu if is_instance_valid(hub.build_menu) and hub.build_menu.get_script()==preload("res://scripts/ui/station_screen.gd") else null
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	var profile=Game.serialize_progress();profile.built=["character","bonuses"];profile.research=["character","bonuses"];profile.credits=0
	Game.apply_profile(profile)
	check("weapons" in Game.built_workshops and "character" not in Game.built_workshops and Game.credits==Game.RETIRED_BUILDINGS.character,"retired buildings: bonuses become the arsenal, the rest is refunded")
	Game.reset_upgrades();Game.credits=100000;Game.cores=50;Game.profiles.selected=true
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);await settle()
	hub.phase="combat"
	hub.open_station("fighter");await settle()
	var view=screen(hub)
	check(view!=null and view.find_child("StationPanel",true,false)!=null,"fighter station opens on the template")
	check(view.provider.tabs().size()==4 and view.find_child("Page",true,false)!=null and view.find_children("Class_*","Button",true,false).size()==ClassCatalog.ROSTER.size(),"«Классы» is one page with the class column")
	check(view.find_children("Slot_*","Button",true,false).size()==2 and view.find_child("Take",true,false)!=null and view.find_child("ClassPath",true,false)!=null,"one path button, two slot cells and the take button")
	# Meta stage 4: no «Выучка» tab.
	check(not view.provider.tabs().any(func(t):return t[0]=="training"),"no training tab")
	var p=view.provider
	check(p.act("shells","gunner","equip")=="","class stays closed until its goal")
	Game.progression.counters["barrel_kills"]=10
	check(p.act("shells","gunner","equip")!="" and Game.selected_class=="gunner","goal opens and selects a class")
	check(Game.class_loadout().is_empty(),"a new class starts without abilities")
	check(p.act("general","health","buy")!="" and Game.health_level==1,"general upgrade")
	check(p.act("supply","heal","buy")!="" and Game.branch_unlocked("heal"),"supply branch unlocks without a building")
	check(p.act("kit","backpack","buy")!="" and Game.backpack_slots==2,"backpack in the fighter station")
	view.tab="supply";view.selected="heal";view.build();await settle()
	check(view.find_child("Action_buy",true,false)!=null,"detail shows the action")
	hub.close_station();Game.built_workshops.erase("weapons")
	hub.open_station("arsenal");await settle()
	check(screen(hub)==null,"arsenal needs its building first")
	Game.research_unlocks.append("weapons");check(Game.build_workshop("weapons"),"build the arsenal")
	hub.open_station("arsenal");await settle();p=screen(hub).provider
	Game.weapon_unlocks=["pistol","rifle"]
	check(p.act("weapons","rifle","take")!="" and Game.selected_weapon=="rifle","take a weapon")
	check(p.act("weapons","rifle","level")!="" and Game.weapon_level("rifle")==1,"level a weapon")
	Game.bonus_unlocks=["heart","repair"];check(p.act("bonuses","repair","level")!="","level a bonus")
	Game.ability_unlocks.append("mine");check(p.act("gadgets","mine","equip")!="" and Game.gadget=="mine","buy and pick a gadget")
	hub.close_station();Game.research_unlocks.append("headquarters");Game.build_workshop("headquarters")
	hub.open_station("hq");await settle();p=screen(hub).provider
	check(p.act("tech","hq_medbay","equip")!="" and "hq_medbay" in Game.hq_loadout(),"equip an HQ technology")
	check(p.act("defence","base","buy")!="" and Game.branch_unlocked("base"),"base defence in the HQ")
	check(p.act("insurance","alloy","buy")!="" and Game.progression.insurance==1,"insurance in the HQ")
	Game.research_unlocks.append("garage");check(p.act("build","garage","build")=="","the parking needs the yard first")
	check(p.act("build","yard","build")!="" and "yard" in Game.built_workshops,"buy the yard from the HQ")
	check(p.act("build","garage","build")!="" and "garage" in Game.built_workshops,"build the parking lot from the HQ")
	hub.close_station();Game.garage.unlocks.append("vehicle_buggy")
	hub.open_station("garage");await settle();p=screen(hub).provider
	check(p.act("vehicles","buggy","buy")!="" and "buggy" in Game.garage.owned,"buy a vehicle")
	check(p.act("vehicles","buggy","choose")!="" and Game.garage.starting_vehicle()=="buggy","vehicle waits at the start")
	hub.close_station();hub.queue_free();await settle()
	print("STATIONS: %d failures" % failures);get_tree().quit(1 if failures else 0)
