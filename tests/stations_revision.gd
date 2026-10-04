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
	check(view.provider.tabs().size()==4 and view.find_child("Page",true,false)!=null and view.find_children("Class_*","Button",true,false).size()==ClassCatalog.ROSTER.size()+ClassCatalog.CONCEPTS.size(),"«Классы» is one page with the class ribbon (playable + in development)")
	# The ribbon scrolls; «Все» opens every class on one screen, a concept shows its sketch.
	var page=view.find_child("Page",true,false)
	view.find_child("AllClasses",true,false).pressed.emit();await settle()
	check(page.get_node_or_null("ClassRoster")!=null and page.get_node("ClassRoster").find_children("Roster_*","Button",true,false).size()==ClassCatalog.ROSTER.size()+ClassCatalog.CONCEPTS.size(),"«Все» lists every class")
	page.get_node("ClassRoster").find_child("Roster_concept_0",true,false).pressed.emit();await settle()
	page=view.find_child("Page",true,false)
	check(page.find_child("ConceptStats",true,false)!=null and page.find_child("Take",true,false).disabled,"a class in development shows its sketch, nothing to take")
	view.selected="recruit";view.build();await settle()
	check(view.find_children("Slot_*","Button",true,false).size()==2 and view.find_child("Take",true,false)!=null and view.find_child("ClassPath",true,false)!=null,"one path button, two slot cells and the take button")
	# Barracks redesign (T-204/T-208/T-211/T-220): main tabs on top, the path strip with the upgrade and the total.
	check(view.find_child("Tab_general",true,false).is_in_group("h_tab") and view.find_child("ClassList",true,false)!=null,"main tabs are a row on top, classes a list on the left")
	var total=view.find_child("TotalCost",true,false)
	check(total!=null and total.text.contains(str(Game.class_step_cost(0)+Game.class_step_cost(1))),"«Всего до 3 ур.» sums the ladder")
	var level_before=ClassCatalog.level("recruit")
	view.find_child("LevelUp",true,false).pressed.emit();await settle()
	check(ClassCatalog.level("recruit")==level_before+1 and view.find_child("LevelText",true,false).text.contains(str(level_before+1)),"the upgrade button buys the next level and the page refreshes at once")
	view.selected="heavy";view.build();await settle()
	check(view.find_child("UnlockText",true,false)!=null and view.find_child("PathStrip",true,false)==null,"a locked class shows how to open it instead of the path")
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
	hub.close_station()

	# from station_notices_revision: seen-aware station dots and «Новое» chips.
	var N=preload("res://scripts/ui/station_notices.gd")
	Game.credits=0;Game.cores=0
	Game.progression.seen=Game.progression.seen.filter(func(s):return not str(s).begins_with("item:") and s!=N.BASELINE)
	Game.progression.viewed_updates.erase("station:fighter")
	check(not N.has_dot("fighter"),"notices baseline: an existing profile starts without dots")
	Game.credits=100000
	check(N.has_dot("fighter"),"new affordable upgrades light the Barracks dot")
	var news=N.scan("fighter").filter(func(i):return N.item_new("fighter",i.id,i.status))
	for k in range(news.size()-1):N.mark_item_seen("fighter",news[k].tab,news[k].id.split(":",true,1)[1])
	check(news.size()<2 or N.has_dot("fighter"),"the dot stays while one new item is left")
	if not news.is_empty():
		var last=news.back();N.mark_item_seen("fighter",last.tab,last.id.split(":",true,1)[1])
		check(not N.has_dot("fighter"),"selecting the last new item clears the dot")
		check(not N.tab_new("fighter",last.tab),"and the tab dot")
	check(hub.bench_available("character")==N.has_dot("fighter"),"the bench dot follows the station notice")
	N.mark_all_seen("arsenal")
	var fresh=Game.LOOT.gun_ids().filter(func(w):return w not in Game.weapon_unlocks)
	check(not fresh.is_empty(),"a weapon blueprint is still left to test the Arsenal notice")
	if not fresh.is_empty():
		Game.weapon_unlocks.append(fresh[0])
		check(N.has_dot("arsenal"),"a new blueprint lights the Arsenal dot")
		var arsenal_tab=load(N.STATIONS.arsenal).new().tabs()[0][0]
		check(N.item_new("arsenal",arsenal_tab+":"+fresh[0],"owned") or N.is_new("arsenal",arsenal_tab,fresh[0]),"the unlocked weapon is marked «Новое»")
		for i in N.scan("arsenal").filter(func(i):return N.item_new("arsenal",i.id,i.status)):N.mark_item_seen("arsenal",i.tab,i.id.split(":",true,1)[1])
		check(not N.is_new("arsenal",arsenal_tab,fresh[0]) and not N.has_dot("arsenal"),"selecting the new items clears «Новое» and the dot")
	# from hub_refresh_cache: hub bench dots follow live availability as alloy changes.
	for id in ["character","weapons","bonuses"]:
		if id not in Game.built_workshops:Game.built_workshops.append(id)
	hub.update_bench_visuals()
	check(not hub.bench_dots.is_empty(),"built benches carry availability dots")
	for credits in [0,99999]:
		Game.credits=credits;hub.hint_refresh=0;hub._physics_process(.4)
		var mismatched=hub.bench_dots.keys().filter(func(id):return hub.bench_dots[id].visible!=hub.bench_available(id))
		check(mismatched.is_empty(),"bench dots match availability at %d alloy %s" % [credits,str(mismatched)])
	hub.queue_free();await settle()

	# from headquarters: HQ rules — keys, blueprint gate, one hub slot, insurance, supply timer, Q heal and
	# shield, regeneration, Tesla, interceptor, route cards, workbench level and save round trip.
	Game.reset_upgrades()
	check(InputMap.has_action("hq_ability") and Settings.DEFAULT_KEYS.hq_ability==KEY_2 and Settings.DEFAULT_KEYS.class_ability==KEY_Q,"HQ support on 2, class ability on Q")
	check(Game.hq_modules.is_empty() and HQCatalog.available("hq_medbay") and not HQCatalog.available("hq_tesla"),"a fresh profile knows only the starting HQ tech")
	Game.credits=5000
	check(not Game.build_workshop("headquarters"),"no HQ without its blueprint")
	Game.research_unlocks.append("headquarters");check(Game.build_workshop("headquarters"),"the blueprint builds the HQ")
	check(Game.equip_hq("hq_patch") and Game.equip_hq("hq_plating") and Game.hq_active=="" and Game.hq_modules==["hq_plating"],"one HQ slot in the hub: a new tech replaces the old one")
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.phase="combat";arena.set_physics_process(false)
	check(is_equal_approx(Game.death_loss_fraction(),.4),"death loses 40% without insurance")
	Game.progression.insurance=1;check(is_equal_approx(Game.death_loss_fraction(),.35),"one insurance level: 35%")
	Game.progression.insurance=6;check(is_equal_approx(Game.death_loss_fraction(),.2),"full insurance: 20%")
	check(not Game.buy_insurance(),"insurance stops at its cap");Game.progression.insurance=0
	var h=arena.headquarters
	check(arena.base_max_hp==8,"base has 8 HP")
	h.modules=["hq_medbay","hq_plating"];h.active="hq_patch";h.room_started();check(arena.base_max_hp==8,"modules keep base HP at 8")
	arena.phase="countdown";h.tick(100);var supply_ok=arena.pickups.is_empty()
	arena.phase="combat";h.tick(89);supply_ok=supply_ok and arena.pickups.is_empty()
	h.tick(1);supply_ok=supply_ok and arena.pickups.size()==1 and arena.pickups[0].kind=="heart"
	h.tick(89);supply_ok=supply_ok and arena.pickups.size()==1
	h.tick(1);supply_ok=supply_ok and arena.pickups.size()==2
	arena.phase="upgrade";h.tick(300);supply_ok=supply_ok and arena.pickups.size()==2
	arena.phase="combat";h.tick(90);supply_ok=supply_ok and arena.pickups.size()==3
	check(supply_ok,"a medkit every 90 combat seconds, never in countdown or card picks")
	var pickup=arena.pickups[0];arena.soldier_hp=1;arena.player.hp=1;arena.reward.collect_pickup(pickup);check(arena.soldier_hp>1,"the HQ medkit heals")
	arena.base_hp=3;check(h.cast() and arena.base_hp==6 and not h.cast(),"Q patch repairs the base by 3 and goes on cooldown")
	Game.set_all_recipes(true);Game.progression.level=4
	h.apply("hq_swap:hq_field:0",1);check(h.cooldown>=55,"swapping in the field shield starts a long cooldown");h.cooldown=0
	check(h.cast(),"the field shield casts");var health=arena.base_hp;arena.combat.damage_base(1);check(arena.base_hp==health,"the shield absorbs base damage")
	h.shield_time=0;arena.combat.damage_base(1);check(h.hit_delay==6,"a hit delays regeneration")
	h.modules=["hq_regen"];h.timers.hq_regen=0;h.tick(1);var dented=arena.base_hp==health-1;h.tick(6);check(dented and arena.base_hp>health-1,"regeneration restores the base after the delay")
	var foe=arena.spawn_actor("soldier",Vector2i(3,3),false);foe.set_physics_process(false);foe.position=h.origin()+Vector3(1,0,-1);var hp=foe.hp
	check(h.trigger("hq_tesla") and (foe.dead or foe.hp<hp),"Tesla hits a nearby enemy")
	var bullet=load("res://scenes/projectile.tscn").instantiate();bullet.arena=arena;bullet.position=h.origin()+Vector3(1,0,0);arena.add_child(bullet);arena.projectiles.append(bullet)
	check(h.trigger("hq_interceptor") and bullet.spent,"the interceptor stops a projectile")
	var offers=arena.reward.service_offers("headquarters")
	check(not offers.is_empty() and offers.all(func(o):return o.id.begins_with("hq_")),"the HQ service stop offers HQ cards")
	arena.queue_free();await settle()
	check(Game.upgrade_hq("hq_medbay"),"the workbench levels an HQ tech")
	# Profile round trip only inside a fresh temporary folder (profile, backup and temp files).
	var dir=OS.get_temp_dir().path_join("warcats_stations_%d" % Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(dir)
	var restore={"path":Game.save_path,"selected":Game.profiles.selected,"blocked":Game.save_blocked}
	Game.save_path=dir.path_join("profile.json");Game.profiles.selected=true;Game.save_blocked=false;Game.save_enabled=true
	var saved=Game.save_progress();Game.hq_unlocks=[];Game.hq_levels={};Game.load_progress()
	check(saved and "hq_tesla" in Game.hq_unlocks and int(Game.hq_levels.get("hq_medbay",0))==1,"HQ techs and levels survive a save round trip")
	Game.save_enabled=false;Game.save_path=restore.path;Game.profiles.selected=restore.selected;Game.save_blocked=restore.blocked
	for file in DirAccess.get_files_at(dir):DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
	Game.reset_upgrades()
	print("STATIONS: %d failures" % failures);get_tree().quit(1 if failures else 0)
