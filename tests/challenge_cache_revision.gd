extends Node3D
# Cache challenge: one special point per world 1 stage 2–6, open exit, ambush on opening,
# reward chest by difficulty. Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades();Campaign.configure(1)
	var one_special=true;var stage0_clean=true
	for seed_value in range(1,60):
		var plan=RoutePlan.build(seed_value)
		stage0_clean=stage0_clean and plan[0].all(func(n):return n.type=="battle")
		for stage in range(1,6):one_special=one_special and plan[stage].filter(func(n):return n.type!="battle").size()==1
	check(stage0_clean,"first stage stays battles")
	check(one_special,"one special point on each stage 2–6")
	var seed_value=1;var plan=[];var node={}
	for candidate in range(1,300):
		plan=RoutePlan.build(candidate)
		for stage in range(1,6):
			for n in plan[stage]:
				if n.type=="cache" and n.difficulty>=1:node=n
		if not node.is_empty():seed_value=candidate;break
	check(not node.is_empty(),"found a ★ cache")
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=seed_value;add_child(arena);arena.set_physics_process(false);arena.auto_pause_enabled=false
	arena.run.route_choices=RoutePlan.path_to(plan,node.stage,node.id)
	arena.begin_room(node.stage);await settle()
	check(arena.room.mode=="cache" and arena.room.room_cleared and arena.phase=="combat" and arena.room.spawn_queue.is_empty(),"cache room starts quiet with the exit open")
	check(not arena.room.flag_armed,"exit does not trigger under the soldier at start")
	var cache=arena.challenges.chest
	check(not cache.is_empty() and cache in arena.room.pickups,"cache chest placed")
	arena.player.position=cache.node.position+Vector3(.8,0,0)
	arena.reward.collect_nearby_pickups(.1)
	check(cache in arena.room.pickups,"walking by does not open the cache")
	arena.interact()
	check(arena.challenges.opened and arena.room.spawn_queue.size()==ChallengeRooms.AMBUSH_SIZE[node.difficulty],"opening calls the ambush")
	check(arena.room.wave_roster.all(func(r):return r.rank>=2),"ambush is veterans")
	arena.room.spawn_queue.clear()
	for actor in arena.room.actors:
		if is_instance_valid(actor) and not actor.player_owned:actor.dead=true
	arena.challenges.tick()
	var chest=arena.room.pickups.filter(func(p):return p.kind=="recipe_draft")
	check(arena.challenges.rewarded and chest.size()==1 and chest[0].offers.size()==3,"reward chest after the ambush")
	check(chest[0].offers.filter(func(o):return o.category=="upgrade").all(func(o):return o.tier==node.difficulty),"card rarity follows the stars")
	arena.phase="combat";arena.open_recipe_draft(chest[0])
	var history=arena.run.upgrade_history.size()
	var card=chest[0].offers.map(func(o):return o.category).find("upgrade")
	arena.choose_recipe_card(card)
	check(arena.run.upgrade_history.size()==history+1,"reward card applied")
	arena.phase="combat";arena.open_flag()
	check(arena.phase=="upgrade" and arena.room.reward_claimed,"exit leads on")
	arena.queue_free();await settle()
	print("CACHE: %d failures" % failures);get_tree().quit(1 if failures else 0)
