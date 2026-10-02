extends Node3D
## Combat feel: shots flash, the soldier's gun drops casings (capped), explosions shake the camera, a heavy
## kill gives a short hit-stop that always restores time, and ui_motion off disables shake and stop.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=2;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().process_frame;arena.set_physics_process(false);arena.phase="combat"
	var feel=arena.get_node("CombatFeel")
	for i in 40:arena.spawn_bullet(arena.player,arena.player.position,Vector2i.UP,1.0,true)
	check(feel.casings.size()==feel.MAX_CASINGS,"casings are capped")
	arena.explosion(Vector3(0,0,0),2);check(feel.trauma>0,"an explosion shakes the camera")
	feel.hit_stop(.05);check(Engine.time_scale<1.0,"hit-stop slows time")
	for i in 20:await get_tree().process_frame
	check(is_equal_approx(Engine.time_scale,1.0),"time is restored after the stop")
	Settings.values.ui_motion=false;feel.trauma=0;feel.shake(.5);feel.hit_stop(.1)
	check(feel.trauma==0 and is_equal_approx(Engine.time_scale,1.0),"motion off: no shake, no stop")
	Settings.values.ui_motion=true
	print("COMBAT FEEL: %d failures" % failures);get_tree().quit(1 if failures else 0)
