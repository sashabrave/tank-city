extends Node3D
## Class path (0.8.0): 20 levels on a geometric price ladder; perk at 4, stronger Q at 10, mastery at 12; class
## stats grow every level; the one-time refund of «Выучка». Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func arena_for(stored:int):
	Game.class_levels[Game.selected_class]=stored
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=9;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	return arena
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
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
	print("CLASS MILESTONES: %d failures" % failures);get_tree().quit(1 if failures else 0)
