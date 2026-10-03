extends Node
## T-148: reached roadmap steps pay alloy once, claimed by hand; the hub board alert waits for it.
## Profile writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	var r=load("res://scripts/ui/stations/roadmap_station.gd").new()
	check(r.unclaimed().is_empty(),"a fresh profile has nothing to claim")
	Game.progression.counters["world_depth_1"]=1
	check("depth1" in r.unclaimed(),"the first field pays a reward")
	var d=r.detail("story","depth1")
	check(d.actions.size()==1 and d.actions[0].id=="claim","the detail offers to claim it")
	var before=Game.credits
	check(r.act("story","depth1","claim")!="" and Game.credits==before+r.reward("depth1"),"claiming adds the alloy")
	check(r.act("story","depth1","claim")=="" and Game.credits==before+r.reward("depth1"),"only once")
	check(r.act("story","depth3","claim")=="","an unreached step pays nothing")
	print("ROADMAP REWARDS: %d failures" % failures);get_tree().quit(1 if failures else 0)
