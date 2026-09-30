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
		var reached=false
		for frame in range(600):
			arena.navigation.invalidate(Vector2i(arena.grid_size/2,2))
			var direction=arena.path_direction(enemy)
			if direction!=Vector2i.ZERO:reached=true;break
			await get_tree().physics_frame
		check(reached,kind+" finds route despite continuous distant wall changes")
		print("ACTIVE SEARCH ",kind," ready=",reached)
		enemy.dead=true;enemy.queue_free();await get_tree().process_frame
	# Exercise actual movement and thinking, rather than teleporting along planner output.
	arena.begin_room(5);arena.phase="combat";arena.spawn_queue.clear();arena.player.set_physics_process(false);arena.player.hp=999999;arena.base_hp=999999
	var enemies=[]
	for i in range(4):
		var enemy=arena.spawn_actor(["soldier","tank","apc","grenadier"][i],Vector2i(1+i*int((arena.grid_size-3)/3.0),0),false);enemy.set_physics_process(false);enemy.hp=99999;enemies.append(enemy)
	for frame in range(5400):
		for enemy in enemies:
			if not enemy.dead:enemy._physics_process(1.0/60.0)
		# Simulate continuous combat damage invalidating a distant bucket.
		if frame%18==0:arena.navigation.invalidate(Vector2i(arena.grid_size/2,2))
		await get_tree().physics_frame
	for enemy in enemies:
		print("ACTIVE MARCH ",enemy.kind," cell=",enemy.cell," deepest=",enemy.deepest_row," moving=",enemy.moving)
		check(enemy.deepest_row>=arena.grid_size-6,enemy.kind+" reaches base approach in 90 seconds")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/r13-active-world-"+str(Campaign.world)+".png")
	print("ACTIVE BATTLE REVISION failures ",failures);get_tree().quit(1 if failures else 0)
