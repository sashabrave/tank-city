extends Node
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Engine.physics_ticks_per_second=240;Campaign.configure(2 if "--world2" in OS.get_cmdline_user_args() else 3)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;arena.run_seed=14;add_child(arena);arena.set_physics_process(false);arena.begin_room(5);arena.phase="combat";arena.spawn_queue.clear()
	for a in arena.actors:a.set_physics_process(false)
	var player=arena.player;player.hp=100;player.max_hp=100;arena.star_time=0;arena.abilities.shield_time=0;arena.abilities.cloak_time=0
	player.invulnerable=0;player.occupying_trench=false;player.hidden_in_trench=false;player.take_damage(4);check(is_equal_approx(player.hp,96),"Open ground receives full damage")
	player.invulnerable=0;player.occupying_trench=true;player.take_damage(4);check(is_equal_approx(player.hp,94),"Trench receives half bullet damage")
	player.invulnerable=0;player.take_damage(4,Vector3.RIGHT);check(is_equal_approx(player.hp,92),"Trench receives half blast damage")
	player.invulnerable=0;player.hidden_in_trench=true;player.take_damage(100,Vector3.RIGHT);check(is_equal_approx(player.hp,92),"Fully hidden receives zero damage")
	player.occupying_trench=false;player.hidden_in_trench=false
	# Wall damage elsewhere must not starve a long incremental search.
	for kind in ["soldier","tank"]:
		var enemy=arena.spawn_actor(kind,Vector2i(1,0),false);enemy.set_physics_process(false);enemy.route_points=[Vector2i(arena.grid_size-2,arena.grid_size-4)]
		# The search is bounded by wall time per frame, so its length depends on machine load; the rule
		# under test is that invalidations never restart it (same search state until the route is found).
		var reached=false;var key="quarter_search" if enemy.uses_quarter_steps() else "cell_search";var search=null;var kept=true
		for frame in range(2400):
			arena.navigation.invalidate(Vector2i(arena.grid_size/2,2))
			var direction=arena.path_direction(enemy)
			if search==null:search=enemy.get_meta(key)
			elif not is_same(search,enemy.get_meta(key,null)):kept=false
			if direction!=Vector2i.ZERO:reached=true;break
			await get_tree().physics_frame
		check(kept,kind+" search survives continuous distant wall changes")
		check(reached,kind+" finds route despite continuous distant wall changes")
		print("ACTIVE SEARCH ",kind," ready=",reached)
		enemy.dead=true;enemy.queue_free();await get_tree().process_frame
	# Exercise actual movement and thinking, rather than teleporting along planner output.
	arena.begin_room(5);arena.phase="combat";arena.spawn_queue.clear();arena.player.set_physics_process(false);arena.player.hp=999999;arena.base_hp=999999
	var enemies=[]
	for i in range(4):
		var enemy=arena.spawn_actor(["soldier","tank","apc","grenadier"][i],Vector2i(1+i*int((arena.grid_size-3)/3.0),0),false);enemy.set_physics_process(false);enemy.hp=99999;enemies.append(enemy)
	# Riflemen may stop at weapon range in a firing lane of the base (02_combat.md): a lane cell with a clear shot counts as the approach.
	var arrived=func(enemy):return enemy.deepest_row>=arena.grid_size-6 or (enemy.cell in arena.enemy.base_firing_cells(enemy) and arena.enemy.base_aim(enemy)!=Vector2i.ZERO)
	# Each frame is one 1/60 s game step with the game's own per-frame planner budget. That budget is wall time
	# (~6 quarter-cell expansions per frame on M4), so a long search can idle a unit for seconds and the march
	# length depends on CPU load: 90 s is the expected pace, 180 s the hard limit of this check.
	var frames=0
	while frames<10800 and not enemies.all(arrived):
		for enemy in enemies:
			if not enemy.dead:enemy._physics_process(1.0/60.0)
		# Simulate continuous combat damage invalidating a distant bucket.
		if frames%18==0:arena.navigation.invalidate(Vector2i(arena.grid_size/2,2))
		frames+=1;await get_tree().physics_frame
	print("ACTIVE MARCH game seconds=",frames/60.0)
	for enemy in enemies:
		print("ACTIVE MARCH ",enemy.kind," cell=",enemy.cell," deepest=",enemy.deepest_row," moving=",enemy.moving)
		check(arrived.call(enemy),enemy.kind+" reaches base approach by real movement")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/r13-active-world-"+str(Campaign.world)+".png")
	print("ACTIVE BATTLE REVISION failures ",failures);get_tree().quit(1 if failures else 0)
