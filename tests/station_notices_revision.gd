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
	# One rule (0.8.0): the dot stays while any item is new and goes out with the last one selected.
	var news=N.scan("fighter").filter(func(i):return N.item_new("fighter",i.id,i.status))
	for k in range(news.size()-1):N.mark_item_seen("fighter",news[k].tab,news[k].id.split(":",true,1)[1])
	check(news.size()<2 or N.has_dot("fighter"),"the dot stays while one new item is left")
	var last=news.back();N.mark_item_seen("fighter",last.tab,last.id.split(":",true,1)[1])
	check(not N.has_dot("fighter"),"selecting the last new item clears the dot")
	check(not N.tab_new("fighter",last.tab),"and the tab dot")
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);await get_tree().process_frame
	check(hub.bench_available("character")==N.has_dot("fighter"),"the bench dot follows the station notice")
	# A weapon blueprint arrives: the Arsenal gets news and the card a «Новое» chip.
	N.mark_all_seen("arsenal")
	var fresh=Game.LOOT.gun_ids().filter(func(w):return w not in Game.weapon_unlocks)
	if not fresh.is_empty():
		Game.weapon_unlocks.append(fresh[0])
		check(N.has_dot("arsenal"),"a new blueprint lights the Arsenal dot")
		var tab=load(N.STATIONS.arsenal).new().tabs()[0][0]
		check(N.item_new("arsenal",tab+":"+fresh[0],"owned") or N.is_new("arsenal",tab,fresh[0]),"the unlocked weapon is marked «Новое»")
		for i in N.scan("arsenal").filter(func(i):return N.item_new("arsenal",i.id,i.status)):N.mark_item_seen("arsenal",i.tab,i.id.split(":",true,1)[1])
		check(not N.is_new("arsenal",tab,fresh[0]) and not N.has_dot("arsenal"),"selecting the new items clears «Новое» and the dot")
	hub.queue_free()
	print("STATION NOTICES: %d failures" % errors);get_tree().quit(1 if errors else 0)
