extends Node3D
## Rare biome particles: at most 3 alive, they drift with the weather wind, they respect the atmosphere toggle.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=9;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().process_frame;arena.set_physics_process(false);arena.phase="combat"
	var drift=arena.get_node("BiomeParticles")
	check(drift!=null,"battle has a biome particle layer")
	for i in 12:drift.wait=0;drift._process(.016)
	check(drift.alive.size()==drift.MAX_ALIVE,"never more than %d at once" % drift.MAX_ALIVE)
	var weather=arena.get_node("Weather");weather.kind="sandstorm"
	var p=drift.alive[0];p.velocity=drift.wind()*1.0
	check(p.velocity.x>2.0,"particles ride the sandstorm wind")
	var x=p.node.position.x;drift.step(p,.5)
	check(p.node.position.x>x,"they move downwind")
	for q in drift.alive.duplicate():q.node.queue_free()
	drift.alive.clear();Settings.values.atmosphere=false
	for i in 5:drift.wait=0;drift._process(.016)
	check(drift.alive.is_empty(),"atmosphere off: no particles")
	Settings.values.atmosphere=true
	print("BIOME PARTICLES: %d failures" % failures);get_tree().quit(1 if failures else 0)
