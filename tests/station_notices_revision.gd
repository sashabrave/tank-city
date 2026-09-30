extends Node
## Seen-aware station notices: baseline, new affordable item lights the dot, visiting clears it,
## a newly unlocked item gets «Новое» until selected.
var errors=0
func check(value:bool,message:String):
	if value:print("PASS ",message)
	else:errors+=1;push_error("FAIL: "+message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	var N=preload("res://scripts/ui/station_notices.gd")
	Game.credits=0;Game.cores=0
	Game.progression.seen=Game.progression.seen.filter(func(s):return not str(s).begins_with("item:") and s!=N.BASELINE)
	Game.progression.viewed_updates.erase("station:fighter")
	check(not N.has_dot("fighter"),"baseline: an existing profile starts without dots")
	Game.credits=100000
	check(N.has_dot("fighter"),"new affordable upgrades light the Barracks dot")
	N.mark_viewed("fighter")
	check(not N.has_dot("fighter"),"visiting the station clears the dot")
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);await get_tree().process_frame
	check(hub.bench_available("character")==N.has_dot("fighter"),"the bench dot follows the station notice")
	# A weapon blueprint arrives: the Arsenal gets news and the card a «Новое» chip.
	N.mark_viewed("arsenal")
	var fresh=Game.LOOT.WEAPONS.keys().filter(func(w):return w not in Game.weapon_unlocks)
	if not fresh.is_empty():
		Game.weapon_unlocks.append(fresh[0])
		check(N.has_dot("arsenal"),"a new blueprint lights the Arsenal dot")
		var tab=load(N.STATIONS.arsenal).new().tabs()[0][0]
		check(N.is_new("arsenal",tab,fresh[0]),"the unlocked weapon is marked «Новое»")
		N.mark_item_seen("arsenal",tab,fresh[0]);N.mark_viewed("arsenal")
		check(not N.is_new("arsenal",tab,fresh[0]) and not N.has_dot("arsenal"),"selecting it clears «Новое» and the dot")
	hub.queue_free()
	print("STATION NOTICES: %d failures" % errors);get_tree().quit(1 if errors else 0)
