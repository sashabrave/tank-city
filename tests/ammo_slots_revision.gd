extends Node
## Ammo slots (T-109…T-111): standard ammo at start; a special ammo card loads its type (replacing over the
## active one when the slots are full); improvements only while loaded; levels remembered; second slot from
## the Arsenal and switching.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	Game.ammo_slot_weapons=[]
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=12;add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	await get_tree().create_timer(.8).timeout
	var run=arena.run;Ammo.ensure(run,arena.weapon)
	check(run.ammo_slots==["standard"] and Ammo.active(run)=="standard","starts with standard ammo")
	var heat=UpgradeRegistry.get_def("burn_heat")
	check(RunUpgrades.eligible(arena,UpgradeRegistry.get_def("burn")) and not RunUpgrades.eligible(arena,heat),"base ammo offered, its improvement not yet")
	check(str(RunUpgrades.card(arena,{"id":"burn","tier":0}).short).contains("Зарядит"),"card says it loads the ammo")
	RunUpgrades.apply(arena,"burn",0)
	check(run.ammo_slots==["burn"] and Ammo.active(run)=="burn","incendiary ammo loaded over standard")
	check(RunUpgrades.eligible(arena,heat),"improvements of loaded ammo are offered")
	RunUpgrades.apply(arena,"burn_heat",0);var power=run.burn_power;var chance=run.burn_chance
	check(str(RunUpgrades.card(arena,{"id":"shock","tier":0}).short).contains("Заменит"),"card shows the replacement")
	RunUpgrades.apply(arena,"shock",0)
	check(run.ammo_slots==["shock"] and not RunUpgrades.eligible(arena,heat),"EMP replaces fire; fire improvements stop dropping")
	check(RunUpgrades.eligible(arena,UpgradeRegistry.get_def("burn")),"fire can be loaded back later")
	RunUpgrades.apply(arena,"burn",0)
	check(Ammo.active(run)=="burn" and is_equal_approx(run.burn_power,power) and is_equal_approx(run.burn_chance,chance),"reloading fire keeps its level and does not stack its base again")
	# Two slots from the Arsenal and switching.
	Game.ammo_slot_weapons.append(arena.weapon);Ammo.ensure(run,arena.weapon)
	check(run.ammo_slots.size()==2,"Arsenal second slot gives two cells")
	RunUpgrades.apply(arena,"stun",0)
	check("burn" in run.ammo_slots and "stun" in run.ammo_slots and Ammo.active(run)=="stun","two ammo types loaded, the new one active")
	Ammo.switch(arena);check(Ammo.active(run)=="burn","switching makes the other type active")
	arena.hud.refresh_ammo()
	check(arena.hud.ammo_row!=null and arena.hud.ammo_row.get_child_count()==2,"HUD shows two ammo cells")
	Game.ammo_slot_weapons=[]
	print("AMMO: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
