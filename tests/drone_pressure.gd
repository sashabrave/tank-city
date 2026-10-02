extends Node3D
var checks=0
var failures=0
func check(ok:bool,msg:String):
	checks+=1
	if not ok:failures+=1;push_error(msg)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false;Game.reset_upgrades()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false);arena.phase="combat"
	arena.player.set_physics_process(false)
	for kind in ["drone","flyer"]:
		for distance in [.8,1.3]:
			var drone=arena.spawn_actor(kind,Vector2i(3,3),false);drone.set_physics_process(false)
			drone.position=arena.player.position+Vector3(distance,0,0)
			arena.player.invulnerable=0;var hp=arena.player.hp
			drone.take_damage(999)
			check(is_equal_approx(arena.player.hp,hp-(.5 if distance<1.15 else 0)),kind+" death radius "+str(distance))
			var after=arena.player.hp;arena.player.invulnerable=0;drone.take_damage(999)
			check(arena.player.hp==after,"death explosion only once")
	arena.abilities.shield_time=4;var before=arena.player.hp
	arena.combat.drone_death_explosion(arena.player.position)
	check(arena.player.hp==before,"active shield blocks drone explosion")
	for win in [true,false]:
		var friendly=arena.spawn_bullet(arena.player,Vector3.ZERO,Vector2i.UP,1,true);friendly.set_physics_process(false)
		var hostile=arena.spawn_bullet(arena.player,Vector3.ZERO,Vector2i.DOWN,1,false);hostile.set_physics_process(false)
		friendly.pressure=1 if win else 0;hostile.pressure=0 if win else 1
		arena.resolve_interception(friendly,hostile)
		var flashes=arena.find_children("PressureFlash*","Sprite3D",false,false)
		check(flashes.size()==(1 if win else 0),"one flash only on successful pressure")
		check(hostile.spent==win and friendly.spent!=win,"interception result unchanged")
		if win:check(is_equal_approx(flashes[0].pixel_size*flashes[0].texture.get_width(),.256),"tiny lightning (quarter cell)")
		# The flash lives 0.16 s. A slow frame can advance the timer before the tween starts, so allow
		# a few more frames, still well under a third of a second of real time.
		var started=Time.get_ticks_msec();await get_tree().create_timer(.22).timeout
		while not arena.find_children("PressureFlash*","Sprite3D",false,false).is_empty() and Time.get_ticks_msec()-started<330:await get_tree().process_frame
		check(arena.find_children("PressureFlash*","Sprite3D",false,false).is_empty(),"flash expires quickly")
		if is_instance_valid(friendly):friendly.consume()
		if is_instance_valid(hostile):hostile.consume()
	arena.queue_free();await get_tree().process_frame
	print("DRONE/PRESSURE: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
