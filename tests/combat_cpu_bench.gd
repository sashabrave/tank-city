extends Node
## Headless CPU diagnostic (T-330), not in the suites: a crowded field (16 enemies), the hero invulnerable and
## firing all the time. Prints the average / p95 / max physics frame; `micro` also prints the cost of single
## brain and bullet functions. Headless time is script CPU only, never FPS. Saves and settings stay off.
## Run: Godot --headless --fixed-fps 60 --path . tests/combat_cpu_bench.tscn -- <room=3> <full|nofire|nobrain|micro>
const FRAMES:=900
var arena
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Campaign.configure(1)
	var args=OS.get_cmdline_user_args();var room_index=int(args[0]) if not args.is_empty() else 3
	var mode=args[1] if args.size()>1 else "full"
	arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=14;add_child(arena);arena.auto_pause_enabled=false
	arena.begin_room(room_index)
	for i in range(240):await get_tree().physics_frame
	arena.phase="combat"
	var kinds=["soldier","soldier","shield","grenadier","soldier","apc","soldier","buggy"]
	for k in range(16):
		var c=arena.find_free_near(Vector2i(1+(k*3)%(arena.grid_size-2),1+(k/6)*2))
		var e=arena.spawn_actor(kinds[k%kinds.size()],c,false);e.max_hp=400;e.hp=400
		if mode=="nobrain":e.set_physics_process(false)
	var samples:Array=[];var enemies=0;var bullets=0
	for i in range(FRAMES):
		if is_instance_valid(arena.player):
			arena.player.hp=arena.player.max_hp;arena.player.invulnerable=1.0
			# A fast trigger (20 shots/s) keeps the field full of rounds.
			if i%3==0:arena.player.fire_cooldown=0
			if i%90==0:Game.input_router.touch_direction=[Vector2i.UP,Vector2i.LEFT,Vector2i.UP,Vector2i.RIGHT][(i/90)%4]
		Game.touch_fire=mode!="nofire"
		var t0=Time.get_ticks_usec()
		await get_tree().physics_frame
		samples.append((Time.get_ticks_usec()-t0)/1000.0)
		enemies+=arena.enemy_count();bullets+=arena.room.projectiles.size()
	Game.touch_fire=false;Game.input_router.touch_direction=Vector2i.ZERO
	if mode=="micro":micro()
	samples.sort();var total=0.0
	for t in samples:total+=t
	print("BENCH %s room=%d physics avg %.3f ms · p95 %.3f · max %.3f · enemies %.1f · bullets %.1f" % [mode,room_index,total/samples.size(),samples[int(samples.size()*.95)],samples.back(),float(enemies)/FRAMES,float(bullets)/FRAMES])
	get_tree().quit()

func timeit(label:String,f:Callable,n:int=200):
	var foes=arena.actors.filter(func(a):return is_instance_valid(a) and not a.player_owned and not a.allied and not a.dead)
	var t0=Time.get_ticks_usec()
	for i in range(n):
		for e in foes:f.call(e)
	print("MICRO %-18s %.4f ms per enemy" % [label,(Time.get_ticks_usec()-t0)/1000.0/(n*maxf(1,foes.size()))])
func micro():
	timeit("enemy_aim",func(e):arena.enemy_aim(e))
	timeit("player_shot",func(e):arena.enemy.player_shot(e,7.0))
	timeit("clear_shot 8",func(e):arena.clear_shot(e.position,e.position+Vector3(0,0,8),.5))
	timeit("can_stand",func(e):arena.can_stand(e.position+Vector3(.25,0,0),e))
	timeit("can_enter",func(e):arena.can_enter(e.cell+Vector2i.RIGHT,e))
	timeit("physics_frame",func(e):e._physics_process(1.0/60.0),30)
	var shots=arena.room.projectiles.filter(func(b):return is_instance_valid(b) and not b.spent)
	var t0=Time.get_ticks_usec();var n=0
	for i in range(300):
		for b in shots:
			if is_instance_valid(b) and not b.spent:arena.combat.bullet_hit(b);n+=1
	print("MICRO bullet_hit         %.4f ms per call (%d calls)" % [(Time.get_ticks_usec()-t0)/1000.0/maxf(1,n),n])
