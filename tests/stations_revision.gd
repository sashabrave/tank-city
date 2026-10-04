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
	check(view.find_children("Slot_*","Button",true,false).size()==1 and view.find_child("Take",true,false)!=null and view.find_child("ClassPath",true,false)!=null,"one path button, one slot cell (Q) and the take button")
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
	check(view.find_child("Item_heal",true,false).find_child("Action_buy",true,false)!=null and view.find_child("Detail",true,false)==null,"the card carries its own action, no detail panel")
	# Station cards (scenes/ui/components/station_card.tscn): buy on the card, progress bar, «i» popup, Esc.
	var heal_level=Game.level("heal")
	view.find_child("Item_heal",true,false).find_child("Action_buy",true,false).pressed.emit();await settle()
	var heal_card=view.find_child("Item_heal",true,false)
	check(Game.level("heal")==heal_level+1 and int(heal_card.get_node("Layout/Progress").value)==heal_level+1 and int(heal_card.get_node("Layout/Progress").max_value)==Game.upgrade_cap("heal"),"buying on the card refreshes it and its level bar")
	heal_card.find_child("Info",true,false).pressed.emit();await settle()
	var popup=view.find_child("InfoPopup",true,false)
	check(popup!=null and popup.find_child("Action_buy",true,false)!=null and popup.find_child("InfoText",true,false)!=null,"«i» opens the full card with its actions")
	var esc_event=InputEventAction.new();esc_event.action="pause";esc_event.pressed=true
	view._unhandled_input(esc_event);await settle()
	check(is_instance_valid(view) and view.find_child("InfoPopup",true,false)==null and is_instance_valid(hub.build_menu),"Esc closes the popup, the station stays")
	view.tab="general";view.build();await settle()
	check(view.find_child("Item_health",true,false).find_child("Action_reset",true,false)==null,"the secondary action is not on the card")
	view.open_info("health");await settle()
	check(view.find_child("InfoPopup",true,false).find_child("Action_reset",true,false)!=null,"…but stays reachable in the popup")
	view.close_info();await settle()
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

	# from headquarters: HQ rules (author, 4 Oct 2026) — no HQ key, every module acts by its own rule; blueprint gate,
	# one hub slot, insurance, medkit timer, dome, repair, medical post, defence pulse, route cards, save round trip.
	Game.reset_upgrades()
	check(not InputMap.has_action("hq_ability") and not Settings.DEFAULT_KEYS.has("hq_ability") and Settings.DEFAULT_KEYS.class_ability==KEY_Q,"no HQ key: the HQ acts on its own; class ability on Q")
	check(not Settings.DEFAULT_KEYS.has("melee") and not Settings.DEFAULT_KEYS.has("use_medkit"),"no V and no H: Space strikes, aid kits heal on pickup")
	check(Game.hq_modules.is_empty() and HQCatalog.available("hq_medbay") and HQCatalog.available("hq_regen") and not HQCatalog.available("hq_tesla") and not HQCatalog.available("hq_medpost"),"a fresh profile knows only the starting HQ modules")
	check(HQCatalog.DATA.values().all(func(d):return d.mode in ["auto","passive"]),"no active HQ support is left")
	Game.credits=5000
	check(not Game.build_workshop("headquarters"),"no HQ without its blueprint")
	Game.research_unlocks.append("headquarters");check(Game.build_workshop("headquarters"),"the blueprint builds the HQ")
	check(Game.equip_hq("hq_regen") and Game.equip_hq("hq_plating") and Game.hq_modules==["hq_plating"],"one HQ slot in the hub: a new module replaces the old one")
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.phase="combat";arena.set_physics_process(false)
	check(is_equal_approx(Game.death_loss_fraction(),.4),"death loses 40% without insurance")
	Game.progression.insurance=1;check(is_equal_approx(Game.death_loss_fraction(),.35),"one insurance level: 35%")
	Game.progression.insurance=6;check(is_equal_approx(Game.death_loss_fraction(),.2),"full insurance: 20%")
	check(not Game.buy_insurance(),"insurance stops at its cap");Game.progression.insurance=0
	var h=arena.headquarters
	check(arena.base_max_hp==8,"base has 8 HP")
	# Аптечка: every 90 combat seconds, one lying at a time; a blocked delivery waits «ready» instead of jumping to 1 s.
	h.modules=["hq_medbay","hq_plating"];h.room_started();check(arena.base_max_hp==8,"modules keep base HP at 8")
	arena.pickups.clear()
	var hq_kits=func():return arena.pickups.filter(func(p):return p.get("hq_medkit",false))
	arena.phase="countdown";h.tick(100);var supply_ok=hq_kits.call().is_empty()
	arena.phase="combat";h.tick(89);supply_ok=supply_ok and hq_kits.call().is_empty()
	h.tick(1);supply_ok=supply_ok and hq_kits.call().size()==1 and hq_kits.call()[0].kind=="heart"
	arena.phase="upgrade";h.tick(300);supply_ok=supply_ok and hq_kits.call().size()==1
	check(supply_ok,"a medkit after 90 combat seconds, never in countdown or card picks")
	arena.phase="combat";h.tick(89.5);h.tick(1)
	check(hq_kits.call().size()==1 and is_zero_approx(h.timers.hq_medbay),"one HQ medkit lies at a time: the next one waits ready")
	h.tick(.5);h.tick(3)
	check(is_zero_approx(h.timers.hq_medbay),"a blocked medkit timer stays ready, it does not jump back to 1 s")
	var pickup=hq_kits.call()[0];arena.soldier_hp=1;arena.player.hp=1;arena.reward.collect_pickup(pickup)
	check(arena.soldier_hp>1 and hq_kits.call().is_empty(),"the HQ medkit heals at once on pickup")
	h.tick(.05);check(hq_kits.call().size()==1 and h.timers.hq_medbay>80,"the waiting medkit comes as soon as the old one is taken")
	arena.soldier_hp=arena.soldier_max_hp;arena.player.hp=arena.soldier_hp;pickup=hq_kits.call()[0];arena.reward.collect_pickup(pickup)
	check(hq_kits.call().size()==1,"at full health the medkit stays on the ground")
	for kit in arena.pickups:kit.node.queue_free()
	arena.pickups.clear()
	# Купол: the hit that raises it lands, the next ones do not; after it the recharge.
	Game.set_all_recipes(true);Game.progression.level=4
	h.modules=["hq_field"];h.room_started();var full=arena.base_hp
	arena.combat.damage_base(1);check(arena.base_hp==full-1 and h.shield_time>=5,"the first hit raises the dome")
	arena.combat.damage_base(2);arena.combat.damage_base(1);check(arena.base_hp==full-1,"under the dome the HQ takes no damage")
	h.tick(5.1);check(h.shield_time<=0,"the dome falls after its time")
	arena.combat.damage_base(1);check(arena.base_hp==full-2 and h.shield_time<=0 and h.timers.hq_field>0,"then it recharges: no dome on the next hit")
	h.tick(HQCatalog.interval("hq_field",0)+.1);arena.combat.damage_base(1);check(h.shield_time>0,"recharged, the next hit raises it again")
	# Ремонт: waits QUIET seconds after a hit, then repairs in steps.
	h.modules=["hq_regen"];h.room_started();h.shield_time=0;arena.combat.damage_base(2);var dented=arena.base_hp
	h.tick(1);var waited=arena.base_hp==dented;h.tick(4.1)
	check(waited and arena.base_hp>dented,"repair waits 5 s without hits, then restores the base")
	# Медпункт: heals the hero on foot near the HQ in portions from its stock, then recharges.
	h.modules=["hq_medpost"];h.room_started();arena.run.soldier_max_hp=20.0;arena.soldier_hp=1.0;arena.player.hp=1.0
	arena.player.position=h.origin()+Vector3(1,0,0)
	h.tick(.01);var first=arena.soldier_hp
	h.tick(.1);var paced=arena.soldier_hp==first
	for i in range(40):h.tick(.2)
	check(is_equal_approx(first,2.0) and paced,"the medical post heals 1 HP per portion, one portion per 0,6 s")
	check(is_equal_approx(arena.soldier_hp,1.0+HQCatalog.medpost_stock(0)) and h.medpost_stock<=0,"it stops when the stock is empty")
	var cooling=h.timers.hq_medpost;h.tick(cooling-1.0);var still=arena.soldier_hp
	check(cooling>=39 and is_equal_approx(still,1.0+HQCatalog.medpost_stock(0)),"an empty stock recharges before healing again")
	h.tick(1.1);h.tick(.01);check(arena.soldier_hp>still and h.medpost_stock>0,"after the recharge the stock refills and heals")
	arena.player.position=h.origin()+Vector3(6,0,0);var far=arena.soldier_hp;h.tick(1);check(arena.soldier_hp==far,"far from the HQ the post does not heal")
	# Оборона: an enemy close to the HQ sets off a pulse — damage and stun to everyone around, enemy rounds burnt.
	h.modules=["hq_tesla"];h.room_started()
	var foe=arena.spawn_actor("soldier",Vector2i(3,3),false);foe.set_physics_process(false);foe.position=h.origin()+Vector3(1,0,-1);foe.hp=99.0;foe.max_hp=99.0
	var other=arena.spawn_actor("soldier",Vector2i(4,3),false);other.set_physics_process(false);other.position=h.origin()+Vector3(-2,0,-1);other.hp=99.0;other.max_hp=99.0
	var away=arena.spawn_actor("soldier",Vector2i(5,3),false);away.set_physics_process(false);away.position=h.origin()+Vector3(0,0,-6);away.hp=99.0;away.max_hp=99.0
	var bullet=load("res://scenes/projectile.tscn").instantiate();bullet.arena=arena;bullet.position=h.origin()+Vector3(1,0,0);arena.add_child(bullet);arena.projectiles.append(bullet)
	h.tick(.05)
	check(foe.hp<99 and other.hp<99 and foe.stun_time>0 and other.stun_time>0,"the defence pulse hits and stuns every enemy within 3 cells")
	check(away.hp==99.0 and bullet.spent and h.timers.hq_tesla>=HQCatalog.interval("hq_tesla",0)-.1,"far enemies are spared, enemy rounds burnt, then a recharge")
	var after=foe.hp;h.tick(1);check(foe.hp==after,"no second pulse while recharging")
	for a in [foe,other,away]:
		if is_instance_valid(a):a.dead=true;arena.actors.erase(a);a.queue_free()
	check(not h.events.is_empty() and h.events.back().text=="Оборона","each trigger leaves a caption for the HUD")
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
	# Migration of a profile from before 4 Oct 2026: merged modules, the old key-2 support becomes a module, levels keep the max.
	var old=Game.serialize_progress()
	old.headquarters={"slots":1,"unlocks":["hq_medbay","hq_plating","hq_patch","hq_emp","hq_field","hq_supply"],"modules":[],"active":"hq_field","levels":{"hq_patch":2,"hq_supply":3,"hq_regen":1,"hq_emp":1,"hq_interceptor":4,"hq_field":2}}
	old.purchased_hq=["hq_medbay","hq_plating","hq_patch","hq_emp","hq_field","hq_interceptor"]
	old.duplicate_recipes=[{"category":"hq","id":"hq_supply"}]
	var checked=preload("res://scripts/profile/schema.gd").validate(old);check(checked.ok,"an old HQ profile validates")
	Game.apply_profile(checked.data)
	check("hq_regen" in Game.hq_unlocks and "hq_tesla" in Game.hq_unlocks and "hq_field" in Game.hq_unlocks and not Game.hq_unlocks.any(func(id):return id in HQCatalog.MERGED),"old unlocks map onto the merged modules")
	check(Game.hq_modules==["hq_field"],"the old key-2 dome is now the equipped module")
	check(int(Game.hq_levels.hq_regen)==3 and int(Game.hq_levels.hq_tesla)==4 and int(Game.hq_levels.hq_field)==2,"merged levels keep the highest")
	check(Game.purchased_hq.size()==5 and "hq_regen" in Game.purchased_hq and "hq_tesla" in Game.purchased_hq,"purchases map without duplicates")
	check(Game.duplicate_recipes.size()==1 and Game.duplicate_recipes[0].id=="hq_regen","a spare old blueprint maps too")
	# Old run snapshot: aid kits in the backpack heal once, the old active support joins the HQ modules.
	var snapshot={"run":{"soldier_hp":1.0,"soldier_max_hp":6.0,"supplies":[{"type":"medkit","heal":2.0},{"type":"medkit","heal":2.0}]}}
	preload("res://scripts/profile/run_checkpoint.gd").upgrade(snapshot)
	check(is_equal_approx(float(snapshot.run.soldier_hp),5.0) and not snapshot.run.has("supplies"),"old backpack aid kits heal once and are gone")
	Game.save_enabled=false;Game.save_path=restore.path;Game.profiles.selected=restore.selected;Game.save_blocked=restore.blocked
	for file in DirAccess.get_files_at(dir):DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
	Game.reset_upgrades()
	print("STATIONS: %d failures" % failures);get_tree().quit(1 if failures else 0)
