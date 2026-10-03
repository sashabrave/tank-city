extends Node
## T-174: the HQ wall number is 9 minus boss wins; after a boss victory the hub clicks it down once and remembers.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.profiles.selected=true;Engine.set_meta("hub_calls_off",true)
	var W=preload("res://scripts/wall_counter.gd")
	var keep=Game.progression.counters.duplicate()
	Game.progression.counters.erase("boss_wins");Game.progression.counters.erase("wall_shown")
	check(W.value()==9,"a fresh profile reads 9")
	Game.progression.event("boss_wins")
	check(W.value()==8,"one boss win makes it 8")
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(4.6).timeout
	var counter=hub.get_node_or_null("WallCounter")
	check(counter!=null and counter.label.text=="8" and int(Game.progression.counters.get("wall_shown",9))==8,"the hub clicks 9 → 8 and remembers it")
	hub.queue_free();await get_tree().process_frame
	hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);await get_tree().process_frame
	check(not hub.get_node("WallCounter").clicking,"no second click on the next visit")
	Game.progression.counters=keep
	print("WALL COUNTER: %d failures" % failures);get_tree().quit(1 if failures else 0)
