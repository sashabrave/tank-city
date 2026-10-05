extends Node
# Sandbox: isolated profile, no automatic waves, admin actions, respawn on death, clean exit.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	for i in range(4):await get_tree().process_frame
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	Game.profiles.selected=true;Game.credits=77;Game.weapon_unlocks=["pistol"]
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await settle()
	check(main.current.root.has_node("DevMenu/SandboxButton"),"hub has the sandbox button")
	main.current.sandbox_requested.emit();await settle()
	var arena=main.run_arena
	check(arena!=null and arena.sandbox and main.current==arena,"sandbox opens a field")
	check(Game.weapon_unlocks.size()==Game.LOOT.gun_ids().size() and not Game.save_enabled,"everything unlocked, writing off")
	var admin=arena.playground.admin
	for i in range(30):arena._physics_process(.05)
	check(arena.phase=="combat" and arena.room.spawn_queue.is_empty() and not arena.room.room_cleared,"no automatic waves")
	admin.count=3;admin.spawn_enemies("tank")
	check(arena.enemy_count()==3,"admin calls enemies")
	admin.clear_enemies();check(arena.enemy_count()==0,"admin clears enemies")
	admin.rebuild({"size":21});await settle()
	check(arena.grid_size==21,"field size changes")
	admin.rebuild({"mode":"hold"});await settle()
	check(arena.room.mode=="hold" and is_instance_valid(arena.challenges.zone),"any challenge can be started")
	admin.rebuild({"mode":"battle","waves":false});await settle()
	RunUpgrades.apply(arena,"fire",2)
	check(arena.run.upgrade_history.size()==1,"cards can be handed out")
	arena.player.invulnerable=0;arena.player.take_damage(99);await settle()
	check(is_instance_valid(arena.player) and not arena.player.dead and arena.phase=="combat","soldier respawns on the spot")
	arena.damage_base(99);await settle()
	check(arena.room.base_hp==arena.room.base_max_hp and arena.phase=="combat","HQ comes back")
	# «Снаряжение» tab: ammo items, backpack, sack, any ability in a slot, class level milestones.
	# «Класс» tab (2026-10-03): any class and any ability, live sliders, reset to the originals; no files written.
	AbilityCatalog.write_enabled=false
	admin.tab="class";admin.open_panel();admin.render();await settle()
	admin.switch_class("heavy");await settle()
	check(Game.selected_class=="heavy" and is_instance_valid(arena.player),"class switch respawns as the chosen class")
	admin.ability_slot=0;admin.tuning="shield";admin.set_ability("shield");await settle()
	check(arena.abilities.slots[0]=="shield" and admin.body.find_child("Tune_cooldown",true,false)!=null,"ability set into Q, its sliders are shown")
	var slider:HSlider=admin.body.find_child("Tune_cooldown",true,false).get_node("Slider");slider.value=5.0
	check(is_equal_approx(AbilityCatalog.DATA.shield.cooldown,5.0),"the slider changes the cooldown at once")
	AbilityCatalog.reset_tuning("shield")
	check(is_equal_approx(AbilityCatalog.DATA.shield.cooldown,AbilityCatalog.default_value("shield","cooldown")),"reset returns the original value")
	admin.close_panel()
	admin.tab="kit";admin.open_panel();admin.render();await settle()
	admin.tier=2;admin.load_ammo("burn")
	check(Ammo.item(arena.run).type=="burn" and Ammo.item(arena.run).rarity==2,"admin loads rolled ammo")
	var used=Backpack.used(arena.run);admin.to_bag({"ammo":[Ammo.roll("burn",0,7)]})
	check(Backpack.used(arena.run)==used+1,"admin fills the backpack")
	admin.drop_sack();check(arena.room.pickups.any(func(p):return str(p.kind)=="sack"),"admin drops a sack")
	admin.ability_slot=1;admin.set_ability("laser")
	check(arena.abilities.slots.size()>=2 and arena.abilities.slots[1]=="laser","any ability goes into a slot")
	admin.class_level(10)
	check(arena.abilities.slots.slice(0,1)==Game.class_loadout() and Game.class_loadout().size()==1,"class level 10: one class slot, Q")
	admin.close_panel()
	Game.earn(500)
	admin.exit_requested.emit();await settle();await settle()
	check(Game.credits==77 and Game.weapon_unlocks==["pistol"],"profile restored after exit")
	check(main.run_arena==null and main.current!=null and main.current.get_script().resource_path.ends_with("hub.gd"),"back in the hub")
	main.queue_free();await settle()
	# from gallery: the object gallery shows the full catalog, respawns targets on their stands, never touches the profile.
	var before=[Game.credits,Game.cores,Game.weapon_unlocks.duplicate(),Game.selected_weapon,Game.ability_unlocks.duplicate()]
	var gallery=load("res://scenes/test_gallery.tscn").instantiate();add_child(gallery)
	gallery.set_physics_process(false);gallery.player.set_physics_process(false)
	check(gallery.exhibits.size()>=80,"gallery: complete object catalog (%d)" % gallery.exhibits.size())
	var target=gallery.exhibits[0].actor;var original=target.position
	target.take_damage(9999)
	check(target.dead and not target.visible and gallery.respawns.size()==1,"gallery: death schedules respawn")
	gallery._physics_process(1.99);check(target.dead,"gallery: still dead before two seconds")
	gallery._physics_process(.02);check(not target.dead and target.visible and target.hp==target.max_hp and target.position==original,"gallery: restored at its stand after two seconds")
	var hero_hp=gallery.player.hp;gallery.player.take_damage(9999);check(gallery.player.hp==hero_hp,"gallery: invulnerable testing hero")
	gallery.focus_exhibit(0);gallery.weapon="pistol";gallery.player.apply_weapon()
	var bullet=gallery.spawn_bullet(gallery.player,target.position,Vector2i.UP,1,true);bullet.set_physics_process(false);bullet.position=target.position
	var target_hp=target.hp;gallery.bullet_hit(bullet);check(target.hp<target_hp,"gallery: a real player bullet damages the exhibit")
	for i in range(gallery.exhibits.size()):gallery.focus_exhibit(i)
	check(before==[Game.credits,Game.cores,Game.weapon_unlocks,Game.selected_weapon,Game.ability_unlocks],"gallery: profile unchanged")
	gallery.queue_free();await settle()
	# from dev_shop_v17: dev unlocks — ability catalog, class purchase and second skill, reversible grants in every group.
	Game.reset_upgrades()
	check(DevUnlocks.catalog("ability").size()==4 and not DevUnlocks.catalog("ability").has("shield"),"dev shop: four buyable abilities, shield is the default")
	DevUnlocks.set_purchase("classes","gunner",true);check("gunner" in Game.class_unlocks and "gunner" in Game.class_first_slots,"dev shop: class purchase opens it with its first slot")
	DevUnlocks.second_skill("gunner",true);check(ClassCatalog.level("gunner")>=8,"dev shop: second skill raises the class level")
	DevUnlocks.toggle("classes","gunner",false);check("gunner" not in Game.class_unlocks,"dev shop: class grant is reversible")
	for pair in [["ability","barrier"],["hq","hq_medbay"],["garage","vehicle_tank"],["research","weapons"]]:
		DevUnlocks.set_purchase(pair[0],pair[1],true);var on=DevUnlocks.purchased(pair[0],pair[1])
		DevUnlocks.set_purchase(pair[0],pair[1],false)
		check(on and not DevUnlocks.purchased(pair[0],pair[1]),"dev shop: %s/%s grant and take back" % pair)
	print("SANDBOX: %d failures" % failures);get_tree().quit(1 if failures else 0)
