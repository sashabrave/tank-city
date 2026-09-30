extends Node3D
# Upgrade registry: every card loads, previews equal the real effect, caps hide useless cards,
# behaviour cards run through the event bus. Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	var defs=UpgradeRegistry.all()
	check(defs.size()>=15,"registry loads all card files")
	for def in defs:
		check(def.id!="" and def.title!="" and (def.modifiers.size()>0 or def.effect!=null),"card is complete: "+def.id)
		for modifier in def.modifiers:check(modifier.has("stat") and str(modifier.get("op","add")) in ["add","add_round","scale","pow"],"modifier readable: "+def.id)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=81;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false;arena.phase="upgrade"
	arena.player.set_physics_process(false)
	arena.abilities.slots=["grenade"]
	for def in defs:
		if def.preview=="":continue
		for tier in range(3):
			var change=RunUpgrades.measure_change(arena,def,Balance.tier_power(tier))
			var before=RunUpgrades.measure(arena,def.preview)
			check(is_equal_approx(change[0],before),"preview does not change the run: "+def.id)
			RunUpgrades.apply(arena,def.id,tier)
			check(is_equal_approx(RunUpgrades.measure(arena,def.preview),change[1]),"preview equals applied value: %s tier %d" % [def.id,tier])
	var shown=CombatStats.probability(arena,"soldier",arena.run.weapon)*100
	check(RunUpgrades.preview_text(arena,"intercept",0).begins_with("Перехват: "+UiKit.number(shown)),"interception preview starts from the real chance")
	for i in range(40):RunUpgrades.apply(arena,"speed",2)
	check(not RunUpgrades.eligible(arena,UpgradeRegistry.get_def("speed")),"capped speed is not offered")
	check(is_equal_approx(arena.run.speed_multiplier,Balance.speed_multiplier_cap()),"speed stops at balance cap")
	for i in range(20):RunUpgrades.apply(arena,"intercept",2)
	check(not RunUpgrades.eligible(arena,UpgradeRegistry.get_def("intercept")),"capped interception is not offered")
	check(not RunUpgrades.eligible(arena,UpgradeRegistry.get_def("weapon_damage")),"weight 0 cards stay out of offers")
	arena.abilities.slots=[]
	check(not RunUpgrades.eligible(arena,UpgradeRegistry.get_def("device_power")),"device cards need an ability")
	RunUpgrades.apply(arena,"exit_dash",0)
	check("exit_dash" in arena.run.behavior_cards and not RunUpgrades.eligible(arena,UpgradeRegistry.get_def("exit_dash")),"behaviour card taken once")
	arena.run.elapsed=20;arena.effects.emit("vehicle_exit")
	check(is_equal_approx(arena.effects.modify("move_speed",1.0),1.25),"event bus drives behaviour effect")
	arena.run.elapsed=24
	check(is_equal_approx(arena.effects.modify("move_speed",1.0),1.0),"effect expires")
	arena.room.upgrade_offers.clear();arena.room.next_is_room=false;arena.reward.prepare_upgrade_offers()
	var ids=arena.room.upgrade_offers.map(func(o):return o.id)
	check(ids.size()==3 and ids.all(func(id):return UpgradeRegistry.has(id) and RunUpgrades.eligible(arena,UpgradeRegistry.get_def(id))),"offers are eligible registry cards")
	check(ids.size()==Array(ids).reduce(func(acc,id):return acc if id in acc else acc+[id],[]).size(),"offers do not repeat")
	arena.queue_free()
	print("UPGRADE REGISTRY: %d failures" % failures);get_tree().quit(1 if failures else 0)
