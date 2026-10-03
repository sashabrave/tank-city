extends Node
var errors=0
func check(ok:bool,label:String):
	if not ok:errors+=1;push_error(label)
func clear_attackers(arena):
	for actor in arena.actors.duplicate():
		if actor.kind in ["drone","flyer"] and not actor.player_owned and not actor.allied:
			actor.dead=true;arena.actors.erase(actor);actor.queue_free()
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false)
	for actor in arena.actors:actor.set_physics_process(false)
	arena.phase="combat";arena.room.surprise_initialized=false;arena.room.combat_elapsed=0;arena.surprises.start_wave()
	check(arena.room.surprise_timer>=15 and arena.room.surprise_timer<=30,"Initial delay 15-30 seconds")
	arena.room.surprise_timer=0;arena.room.combat_elapsed=14.99
	var count=arena.actors.size();arena.surprises.tick(.01);check(arena.actors.size()==count,"No early drone")
	arena.room.combat_elapsed=16;var combat_rng=arena.combat_rng.state
	arena.surprises.tick(.01);check(arena.actors.size()==count+1,"Cooldown dispatches a drone during main wave")
	check(arena.room.surprise_timer>=18 and arena.room.surprise_timer<=30,"Random repeat cooldown")
	check(combat_rng==arena.combat_rng.state,"Drone randomness stays separate")
	var timer=arena.room.surprise_timer
	for phase in ["upgrade","paused","countdown"]:
		arena.phase=phase;arena.surprises.tick(10);check(arena.room.surprise_timer==timer,"No ticking outside combat")
	arena.room.wave=1;arena.surprises.start_wave();check(arena.room.surprise_timer==timer,"Next wave keeps cooldown")
	arena.phase="combat"
	# No total quota: sustained ground combat permits more than the former room maximum.
	for i in range(7):
		clear_attackers(arena);count=arena.actors.size();arena.room.surprise_timer=0
		arena.surprises.tick(.01);check(arena.actors.size()==count+1,"Unbounded total background attacks")
	clear_attackers(arena)
	for i in range(3):arena.room.surprise_timer=0;arena.surprises.tick(.01)
	check(arena.enemy_count()-arena.wave_enemy_count()==2,"At most two simultaneous background attackers")
	arena.spawn_queue.clear();arena.room.surprise_timer=0
	count=arena.actors.size();arena.surprises.tick(100);check(arena.actors.size()==count,"No late dispatch after main enemies are gone")
	var bomb=load("res://scenes/bomb.tscn").instantiate();bomb.arena=arena;arena.add_child(bomb);arena.bombs.append(bomb);bomb.set_physics_process(false)
	var hp=arena.base_hp;var credits=Game.credits
	arena.room.wave=0;arena._physics_process(.016)
	check(arena.phase=="combat" and arena.enemy_count()==2,"Living drones hold the wave")
	arena.finish_wave();arena.surprises.end_wave()
	check(arena.phase=="combat" and arena.enemy_count()==2 and not arena.bombs.is_empty(),"No forced withdrawal while enemies live")
	clear_attackers(arena)
	arena.room.surprise_timer=1000
	# Every hostile kind, including a flyer and ordinary infantry, must be defeated.
	for kind in ["drone","flyer","soldier"]:
		var actor=arena.spawn_actor(kind,Vector2i(0,0),false,false,1,true);actor.set_physics_process(false)
		arena._physics_process(.016)
		check(arena.phase=="combat" and not actor.dead,"Live hostile blocks completion: "+kind)
		actor.dead=true;arena.actors.erase(actor);actor.queue_free()
	arena.room.surprise_timer=1000
	arena._physics_process(.016)
	check(arena.phase=="upgrade","Final kill ends wave without waiting for drone cooldown")
	# Planted drone bombs are no longer swept away at the end of a wave (T-040/T-041): they go off on their own.
	check(arena.enemy_count()==0,"No live enemies after the final kill")
	check(arena.base_hp==hp and Game.credits==credits,"Cleanup has no damage or fabricated kill reward")
	var battle=RoutePlan.build(arena.run_seed)[1].filter(func(n):return n.type=="battle")[0];arena.run.route_choices[1]=battle.id
	arena.begin_room(1);check(arena.room.surprise_timer>=15 and arena.room.surprise_timer<=30,"New room resets first delay")
	print("DRONE BACKGROUND COOLDOWN failures ",errors);get_tree().quit(1 if errors else 0)
