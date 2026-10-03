extends Node3D
## Meta stage 4: class level milestones (3 second ability, 5 perk, 7 stronger Q, 10 mastery) and the one-time
## refund of «Выучка». Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func arena_for(level:int):
	Game.class_levels[Game.selected_class]=level
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=9;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	return arena
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	check(Game.class_loadout()==["grenade"],"level 0: the class Q is free")
	Game.class_levels.recruit=2;check(Game.class_loadout().size()==1,"level 2: one ability")
	Game.class_levels.recruit=3;check(Game.class_loadout()==["grenade","comrade"],"level 3: second ability")
	var low=arena_for(4);var crit_low=low.run.crit_chance;var power_low=low.abilities.states.grenade.level.power;low.queue_free();await get_tree().process_frame
	var mid=arena_for(5);check(is_equal_approx(mid.run.crit_chance,crit_low+.05),"level 5: the perk adds crit");var crit_damage_mid=mid.run.crit_damage;mid.queue_free();await get_tree().process_frame
	var seven=arena_for(7);check(power_low==0.0 and seven.abilities.states.grenade.level.power==1.0,"level 7: Q starts one power step higher");seven.queue_free();await get_tree().process_frame
	var top=arena_for(10);check(is_equal_approx(top.run.crit_damage,crit_damage_mid+.25),"level 10: mastery adds crit damage");top.queue_free();await get_tree().process_frame
	Game.selected_class="heavy";Game.class_unlocks.append("heavy");Game.class_levels.heavy=4
	check(is_equal_approx(CombatStats.class_weapon_multiplier("shotgun"),1.0),"shotgun bonus is closed before the perk")
	Game.class_levels.heavy=5;check(is_equal_approx(CombatStats.class_weapon_multiplier("shotgun"),1.1),"shotgun bonus is the level 5 perk")
	check(ClassCatalog.perk_lines("heavy")[1].ends_with("(закрыто)"),"locked mastery is marked")
	# Refund: two dodge levels and an old second-slot purchase come back as alloy, once.
	var data=Game.serialize_progress();var dodge=StatRegistry.get_def("dodge")
	data.stat_levels={"dodge":2};data.class_second_slots=["recruit"];data.credits=100
	Game.apply_profile(data.duplicate(true))
	var expected=100+dodge.cost_base+(dodge.cost_base+dodge.cost_step)+2500
	check(Game.credits==expected and Game.stat_levels.is_empty() and Game.class_second_slots.is_empty(),"«Выучка» and the old slot are refunded")
	check(Game.notification_history.any(func(n):return str(n.text).begins_with("Выучка убрана")),"the refund is announced")
	var again=Game.serialize_progress();Game.apply_profile(again.duplicate(true))
	check(Game.credits==expected,"refund happens once")
	print("CLASS MILESTONES: %d failures" % failures);get_tree().quit(1 if failures else 0)
