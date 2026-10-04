extends Node3D
# World 1 carries the content of all three worlds: blueprint tiers open along the route, every shell
# is buyable, the mechanic works on the player's vehicle, barrels grow towards the boss.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame
func ids(level:int,stage:int)->Array:return EncounterRules.recipe_pool(level,[],stage,true).map(func(r):return r.id)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	Campaign.configure(1)
	check(Campaign.recipe_world()==3 and Campaign.unified_content(),"world 1 holds all content")
	check(ids(2,0).is_empty() and ids(2,1).is_empty(),"no rare blueprints on the first two stages")
	check(ids(1,0).all(func(id):return Game.TIERS.tier(id)<=1),"early stages drop common blueprints")
	var late=ids(2,6)
	for id in ["sniper","rpg","vehicle_tank","vehicle_apc","laser","airstrike"]:check(id in late or id in ids(2,4),"late world 1 can drop "+id)
	check(not ("vehicle_tank" in ids(2,2)),"tank blueprint waits for the second half")
	for id in Game.CLASSES:check(Game.class_world(id)==1,"shell available in world 1: "+id)
	Game.progression.counters["field_reached"]=5;check(Game.can_select_class("heavy") and Game.can_select_class("engineer"),"classes open by goals in world 1")
	Campaign.configure(2)
	check(not Campaign.unified_content() and Campaign.recipe_world()==2,"locked world 2 keeps its gating")
	Campaign.configure(1)
	# Barrels grow towards the boss; the boss arena gets corner barrels.
	var counts=[]
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=77;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	for room in range(7):
		arena.begin_room(room);await settle()
		counts.append(arena.room.walls.values().filter(func(w):return w.get("barrel",false)).size())
	check(counts[0]>=1 and counts[5]>counts[0],"barrels grow along the route %s" % str(counts))
	var g=arena.room.grid_size
	var corners=[Vector2i(1,2),Vector2i(g-2,2),Vector2i(1,g-6),Vector2i(g-2,g-6)].filter(func(c):return arena.room.walls.has(c) and arena.room.walls[c].get("barrel",false)).size()
	check(counts[6]>=3 and corners==counts[6],"boss barrels only in the corners (%d)" % counts[6])
	# Mechanic upgrades the vehicle the player has, not a world-bound one.
	arena.pending_vehicle="tank"
	var service=load("res://scripts/service_room.gd").new();service.arena=arena;service.index=2;service.branch="vehicle";add_child(service);await settle()
	check(service.vehicle=="tank","mechanic works on the pending tank")
	service.queue_free();arena.pending_vehicle=""
	arena.queue_free();await settle()
	print("WORLD1 CONTENT: %d failures" % failures);get_tree().quit(1 if failures else 0)
