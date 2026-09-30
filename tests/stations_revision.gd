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
	check(view.provider.tabs().size()==5 and view.find_child("Items",true,false).find_children("Item_*","Button",true,false).size()==ClassCatalog.ROSTER.size()+ClassCatalog.CONCEPTS.size(),"classes and concepts listed as cards")
	# «Выучка»: the stat tree comes from StatRegistry, grouped by family, roots open and the rest locked.
	var tree=view.provider.items("training")
	check(tree.size()==StatRegistry.all().filter(func(d):return d.step>0 and d.meta_field=="").size() and tree.all(func(i):return i.has("group")),"training tree lists every station stat by family")
	Game.credits=5000;var dodge_before=StatRegistry.base_value(StatRegistry.get_def("dodge"))
	check(view.provider.act("training","dodge","buy")!="" and StatRegistry.base_value(StatRegistry.get_def("dodge"))>dodge_before,"training raises the run start value")
	check(view.provider.act("training","guard_bullet","buy")=="","locked node needs its parent level")
	view.provider.act("training","dodge","buy");check(view.provider.act("training","guard_bullet","buy")!="","parent level opens the next node")
	var p=view.provider
	check(p.act("shells","gunner","equip")=="","class stays closed until its goal")
	Game.progression.counters["barrel_kills"]=10
	check(p.act("shells","gunner","equip")!="" and Game.selected_class=="gunner","goal opens and selects a class")
	check(p.act("shells","gunner","first")!="" and "gunner" in Game.class_first_slots,"buy the first ability")
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
	Game.research_unlocks.append("garage");check(p.act("build","garage","build")!="" and "garage" in Game.built_workshops,"build the parking lot from the HQ")
	hub.close_station();Game.garage.unlocks.append("vehicle_buggy")
	hub.open_station("garage");await settle();p=screen(hub).provider
	check(p.act("vehicles","buggy","buy")!="" and "buggy" in Game.garage.owned,"buy a vehicle")
	check(p.act("vehicles","buggy","choose")!="" and Game.garage.starting_vehicle()=="buggy","vehicle waits at the start")
	hub.close_station();hub.queue_free();await settle()
	print("STATIONS: %d failures" % failures);get_tree().quit(1 if failures else 0)
