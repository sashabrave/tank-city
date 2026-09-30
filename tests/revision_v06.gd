extends Node
var checks=0
var failures=0
var arena
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	check(Game.branch_unlocks==["health"] and Game.weapon_unlocks==["rifle"] and Game.bonus_unlocks==["heart"] and Game.ability_unlocks==["barrier"],"first entry unlocked in each workshop")
	Game.credits=1000;check(not Game.purchase("damage"),"locked stat cannot be upgraded")
	var before=Game.credits;check(Game.unlock_branch("damage") and Game.credits==before-140,"branch opens for large one-time price")
	check(Game.purchase("damage"),"unlocked stat upgrades normally")
	var rng=RandomNumberGenerator.new();rng.seed=4
	var pending=[]
	for i in range(200):Game.discover_recipe(rng,pending)
	Game.bank_recipes(pending)
	check(Game.weapon_unlocks.size()==3 and Game.bonus_unlocks.size()==7,"all recipes discoverable without duplicates")
	Game.credits=1000
	for i in range(3):check(Game.upgrade_bonus("heart"),"small bonus level purchased")
	check(not Game.upgrade_bonus("heart") and is_equal_approx(Game.bonus_power("heart"),1.3),"bonus capped at three small levels")
	var path=Game.save_path;Game.save_path="/private/tmp/tank-revision-profile.json";Game.save_enabled=true;Game.save_progress();Game.weapon_unlocks=["rifle"];Game.bonus_unlocks=["heart"];Game.bonus_levels={};Game.load_progress()
	check(Game.weapon_unlocks.size()==3 and Game.bonus_level("heart")==3,"recipes and bonus levels persist")
	Game.save_enabled=false;Game.save_path=path
	arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat";arena.spawn_queue.clear()
	for wall in arena.walls.values():wall.node.queue_free()
	arena.walls.clear();arena.trenches.clear()
	var flyer=arena.spawn_actor("flyer",Vector2i(0,0),false)
	arena.flyer_step(flyer,.1)
	var difference=flyer.flight_target-flyer.position
	check(is_zero_approx(difference.x) or is_zero_approx(difference.z),"flyer movement cardinal")
	flyer.flight_state="burst";flyer.flight_timer=0;var count=arena.projectiles.size();arena.flyer_step(flyer,.1)
	var shot=arena.projectiles.back()
	check(arena.projectiles.size()==count+1 and flyer.flight_state=="rest" and flyer.flight_shots==1,"one flyer shot then reposition")
	check(is_equal_approx(shot.speed,7.65) and (is_zero_approx(shot.travel_direction.x) or is_zero_approx(shot.travel_direction.z)),"flyer shot cardinal and ten percent slower")
	check(shot.get_child(0).mesh is SphereMesh and is_equal_approx(shot.get_child(0).mesh.radius,.22),"large visible flyer round")
	arena.room_index=2;var first=arena.spawn_actor("soldier",Vector2i(1,1),false,false,2)
	arena.room_index=3;var second=arena.spawn_actor("soldier",Vector2i(2,1),false,false,2)
	check(is_equal_approx(second.hp,first.hp*2) and is_equal_approx(second.damage,first.damage*2),"second half exactly doubles health and damage at same rank")
	Game.bonus_unlocks=["heart"];arena.room_index=2;arena.start_wave(0)
	check(arena.pickups.is_empty(),"locked turret absent from scheduled supplies")
	arena.start_wave(2);check(arena.pickups.is_empty(),"locked vehicle absent from scheduled supplies")
	arena.room_index=0;arena.spawn_room_boss();var elite=arena.actors.filter(func(a):return a.elite)[0]
	var peer=arena.spawn_actor(elite.kind,Vector2i(3,1),false)
	check(elite.footprint==1 and elite.model.scale==peer.model.scale and elite.speed==peer.speed,"miniboss retains ordinary size and movement")
	check(is_equal_approx(elite.max_hp,peer.max_hp*2.5),"miniboss health scales from type")
	var valid=true
	for room in range(6):
		for wave in range(3):
			for seed_value in range(100):
				var entries=WaveDirector.build(seed_value,room,wave);var cost=0
				for entry in entries:cost+=WaveDirector.rank_cost(entry.kind,entry.rank)
				valid=valid and entries.size()==WaveDirector.COUNTS[room][wave] and cost<=WaveDirector.BUDGETS[room][wave]
	check(valid and WaveDirector.COUNTS[2]==WaveDirector.COUNTS[5] and WaveDirector.CAPS[0]==2,"1800 waves meet counts; later difficulty grows without extra bodies")
	var shapes={};var colors={}
	for id in Game.LOOT.BONUSES:
		shapes[Game.LOOT.BONUSES[id].shape]=true;colors[Game.LOOT.BONUSES[id].color]=true;arena.drop_pickup(Vector2i.ZERO,id)
	check(shapes.size()==7 and colors.size()==7 and arena.pickups.size()==7,"six distinct bonus shapes colors and labels")
	Game.weapon_unlocks=["rifle"];arena.next_is_room=true;arena.phase="upgrade";arena.upgrade_offers.clear();arena.hud.show_upgrades()
	check(arena.upgrade_offers[0].id=="weapon_locked","no unowned weapon offered without recipe")
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	hub.avatar.position=hub.bonus_bench_pos+Vector3.BACK;hub.interact()
	check(hub.bonus_station.visible and not hub.dpad.enabled,"bonus workbench opens and locks movement")
	hub.close_station();check(not hub.bonus_station.visible and hub.dpad.enabled,"bonus workbench closes")
	print("REV06: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
