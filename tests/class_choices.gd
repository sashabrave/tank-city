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
	await class_milestone_checks()
	await dynamite_checks()
	await grenade_checks()
	Game.reset_upgrades();Campaign.configure(1)
	print("CLASS CHOICES: %d failures" % failures);get_tree().quit(1 if failures else 0)

func arena_for(stored:int):
	Game.class_levels[Game.selected_class]=stored
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=9;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	return arena

# from class_milestones: 20 levels on a geometric price ladder; perk at 5, stronger Q at 10, mastery; one-time refund of «Выучка».
func class_milestone_checks():
	Game.reset_upgrades();Campaign.configure(1)
	check(ClassCatalog.level("recruit")==1 and Game.class_upgrade_cost("recruit",false)==100,"a class starts at level 1, the next level costs 100")
	var total=0
	for stored in range(7):total+=roundi(100.0*pow(1.32,stored))
	check(total>1700 and total<2100,"levels 1→8 cost ≈1900 in total (%d)" % total)
	Game.class_levels.recruit=19;check(Game.class_upgrade_cost("recruit",false)==-1 and ClassCatalog.level("recruit")==20,"level 20 is the top")
	var low=arena_for(3);var crit_low=low.run.crit_chance;low.queue_free();await get_tree().process_frame
	var mid=arena_for(4);check(mid.run.crit_chance>crit_low+.05,"level 5: the perk adds crit on top of the growth");mid.queue_free();await get_tree().process_frame
	var q8=arena_for(8);var p8=q8.abilities.states.grenade.level.power;q8.queue_free();await get_tree().process_frame
	var q9=arena_for(9);check(p8==0.0 and q9.abilities.states.grenade.level.power==1.0,"level 10: Q starts one power step higher");q9.queue_free();await get_tree().process_frame
	check(ClassCatalog.growth("recruit")[0][1]>0 and ClassCatalog.growth_line("recruit").contains("здоровья"),"levels grow the class stats")
	Game.selected_class="heavy";Game.class_unlocks.append("heavy");Game.class_levels.heavy=3
	check(is_equal_approx(CombatStats.class_weapon_multiplier("shotgun"),1.0),"shotgun bonus is closed before the perk")
	Game.class_levels.heavy=4;check(is_equal_approx(CombatStats.class_weapon_multiplier("shotgun"),1.1),"shotgun bonus is the level 5 perk")
	check(ClassCatalog.perk_lines("heavy")[1].ends_with("(закрыто)"),"locked mastery is marked")
	var data=Game.serialize_progress();var dodge=StatRegistry.get_def("dodge")
	data.stat_levels={"dodge":2};data.class_second_slots=["recruit"];data.credits=100
	Game.apply_profile(data.duplicate(true))
	var expected=100+dodge.cost_base+(dodge.cost_base+dodge.cost_step)+2500
	check(Game.credits==expected and Game.stat_levels.is_empty() and Game.class_second_slots.is_empty(),"«Выучка» and the old slot are refunded")
	var again=Game.serialize_progress();Game.apply_profile(again.duplicate(true))
	check(Game.credits==expected,"refund happens once")

# from dynamite_revision: fuse first, then the cross hits enemies on the lines and spares the soldier.
func dynamite_checks():
	Game.reset_upgrades();Campaign.configure(1)
	check(ClassCatalog.abilities("gunner").slice(0,2)==["dynamite","gas"],"Подрывник: dynamite first, gas second")
	check(AbilityCatalog.DATA.has("dynamite"),"dynamite is in the ability catalog")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=3;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().process_frame;arena.set_physics_process(false);arena.phase="combat"
	var origin=Vector2i(arena.grid_size/2,arena.grid_size/2)
	for cell in [origin+Vector2i(1,0),origin+Vector2i(2,0),origin+Vector2i(-1,0),origin+Vector2i(-2,0),origin+Vector2i(0,1),origin+Vector2i(0,-1),origin+Vector2i(0,-2)]:
		if arena.walls.has(cell):arena.damage_wall(cell,999)
	var enemy=arena.spawn_actor("soldier",origin+Vector2i(0,-2),false);enemy.set_physics_process(false);enemy.hp=50;enemy.max_hp=50
	var player=arena.player;player.position=arena.world_pos(origin+Vector2i(-1,0));var hp=player.hp
	var bomb=load("res://scripts/ability_effect.gd").new();bomb.arena=arena;bomb.kind="dynamite";bomb.power=6;bomb.utility=0;bomb.position=arena.world_pos(origin);arena.add_child(bomb)
	bomb._physics_process(1.0)
	check(is_instance_valid(bomb) and not bomb.is_queued_for_deletion(),"dynamite: nothing before the fuse burns down")
	bomb._physics_process(.6)
	check(enemy.hp<50,"dynamite: enemy on the line is hit")
	check(is_equal_approx(player.hp,hp),"dynamite: the soldier is spared")
	arena.queue_free();await get_tree().process_frame

# from grenade_v19: grenade uses the real ability radius, impact fuse damage, one shockwave, flight/bounce physics. Hub preview dropped (visual).
func grenade_checks():
	Game.reset_upgrades();Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=88;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false;arena.phase="combat";arena.player.set_physics_process(false)
	for wall in arena.walls.values():wall.node.queue_free()
	arena.walls.clear();arena.player.position=arena.world_pos(Vector2i(5,8));arena.player.facing=Vector2i.UP
	var enemy=arena.spawn_actor("soldier",Vector2i(5,3),false);enemy.set_physics_process(false)
	enemy.hp=100;enemy.max_hp=100
	arena.abilities.select("grenade");check(arena.abilities.cast(),"grenade cast")
	if arena.grenades.is_empty():
		check(false,"grenade spawned");arena.queue_free();await get_tree().process_frame;return
	var grenade=arena.grenades[0];grenade.set_physics_process(false)
	check(grenade.friendly and is_instance_valid(grenade.marker),"grenade is friendly and has a marker")
	check(is_equal_approx(grenade.marker.get_meta("blast_radius"),arena.abilities.radius()) and is_equal_approx(Balance.CONFIG.combat.grenade_radius,1.5),"grenade blast uses the ability radius (base 1.5)")
	check(grenade.target==arena.world_pos(Vector2i(5,3)),"grenade aims at the enemy in the facing line")
	var before=enemy.hp
	grenade._physics_process(.3);check(not grenade.spent,"grenade is still flying after 0.3 s")
	for i in range(30):
		if not grenade.spent:grenade._physics_process(.05)
	check(grenade.spent and enemy.hp<before,"impact fuse explodes on the enemy")
	check(arena.grenades.is_empty() and arena.find_children("GrenadeShockwave","Node3D",true,false).size()==1,"one shared shockwave, grenade list cleaned")
	arena.queue_free();await get_tree().process_frame
	var motion_script=load("res://scripts/grenade_motion.gd")
	var motion=motion_script.new(Vector3(0,.8,0),Vector3(0,0,-5),.65,func(_cell):return false)
	motion.advance(.65)
	var reached=absf(motion.position.z+5)<.04
	motion.advance(2)
	check(reached and motion.position.z>=-5.5 and motion.position.z<=-5 and is_equal_approx(motion.position.y,.14) and motion.velocity.length()<.001,"grenade lands at target and rests on the ground")
	for fps in [30,60,120]:
		var bounce=motion_script.new(Vector3(0,.8,0),Vector3(0,0,-5),.65,func(probe):return Vector2i(roundi(probe.x),roundi(probe.z))==Vector2i(0,-2))
		for frame in range(fps*3):bounce.advance(1.0/fps)
		check(bounce.collided and bounce.landed and bounce.position.z>-1.36 and bounce.position.z<-0.86 and is_equal_approx(bounce.position.y,.14),"grenade bounces off a wall the same at %d fps" % fps)
