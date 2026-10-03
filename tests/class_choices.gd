extends Node3D
## Meta stage 3: own Q per class without repeats, a free choice of one of two «1» abilities, the gadget
## does not duplicate slot «1», the choice is saved. Profile and settings writes stay disabled.
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
		check(Game.CLASS_CHOICES[id].size()==2 and Game.CLASS_CHOICES[id].all(func(a):return AbilityCatalog.DATA.has(a) and a!=Game.CLASS_SKILLS[id]),"two real «1» options: "+id)
	Game.class_unlocks=["recruit","marksman"];Game.selected_class="recruit";Game.class_levels={"recruit":3}
	check(Game.class_loadout()==["grenade","comrade"],"default second is the first option")
	check(Game.choose_class_second("recruit","mine") and Game.class_loadout()==["grenade","mine"],"free switch to the other option")
	check(not Game.choose_class_second("recruit","laser"),"foreign ability is refused")
	Game.purchased_gadgets=["mine","barrier"];Game.ability_unlocks.append("mine");Game.gadget="mine"
	check(Game.hero_loadout()==["grenade","mine"],"gadget equal to slot «1» is not doubled")
	Game.gadget="barrier"
	check(Game.hero_loadout()==["grenade","mine","barrier"],"other gadget stays on F")
	check(not Game.ability_available("comrade") and not Game.ability_available("cloak"),"class-only abilities outside the loadout stay off")
	var data=Game.serialize_progress()
	check(data.class_choices.get("recruit")=="mine","choice is in the profile")
	data.class_choices={"recruit":"laser","heavy":"gas"}
	Game.apply_profile(data.duplicate(true))
	check(Game.class_choices=={"heavy":"gas"},"loading keeps only valid choices")
	var station=load("res://scripts/ui/stations/fighter_station.gd").new()
	var info=station.detail("shells","recruit")
	check(info.actions.any(func(a):return a.id=="pick"),"Kazarma offers the switch")
	print("CLASS CHOICES: %d failures" % failures);get_tree().quit(1 if failures else 0)
