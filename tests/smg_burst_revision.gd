extends Node3D
## Pistol and SMG share a short range; one SMG pull fires a 3-shot burst; the shown rate counts every shot.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	var W=Game.LOOT.WEAPONS
	check(is_equal_approx(W.pistol.range,W.smg.range) and W.pistol.range<W.rifle.range,"pistol and SMG: same shorter range")
	check(int(W.smg.burst)==3 and int(W.pistol.burst)==1,"SMG fires bursts of 3")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=5;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().process_frame
	arena.run.weapon="smg";arena.phase="combat"
	var spawned=[0]
	arena.child_entered_tree.connect(func(n):if n.get("friendly")==true:spawned[0]+=1)
	arena.fire_weapon(arena.player)
	check(spawned[0]==1,"first shot of the burst is immediate")
	await get_tree().create_timer(.25).timeout
	check(spawned[0]==3,"two more shots follow (%d)" % spawned[0])
	var stats=CombatStats.weapon(arena,"smg")
	check(is_equal_approx(stats.rate,3.0/stats.interval),"rate counts every shot of the burst")
	print("SMG BURST: %d failures" % failures);get_tree().quit(1 if failures else 0)
