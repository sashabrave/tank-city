extends Node3D
# Windowed diagnostic: frame times while the soldier fires continuously into (a) open air, (b) brick walls,
# (c) enemies. Prints median / p95 / max and every spike above 25 ms with live counters.
# Run: Godot --path . tests/shooting_performance.tscn. Profile and settings writes stay disabled.
var arena
var times:Array=[]
var spikes:Array=[]
var last=0
var label=""
func _ready():call_deferred("run")
func frames(n):
	for i in range(n):await get_tree().process_frame
func _process(_delta):
	var now=Time.get_ticks_usec()
	if last>0 and label!="":
		var ms=(now-last)/1000.0;times.append(ms)
		if ms>25:spikes.append("%s %.1f ms · projectiles %d · nodes %d · draw %d · objects %d" % [label,ms,arena.room.projectiles.size(),Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	last=now
func scenario(name:String,facing:Vector2i,seconds:float):
	times.clear();spikes.clear();label=name
	arena.player.facing=facing;arena.player.model.rotation.y=arena.player.angle_for(facing)
	var end=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		Game.touch_fire=true
		if arena.player.fire_cooldown<=0:arena.player.shoot()
		await get_tree().process_frame
	Game.touch_fire=false;label=""
	var sorted=times.duplicate();sorted.sort()
	var median=sorted[sorted.size()/2] if not sorted.is_empty() else 0.0
	var p95=sorted[int(sorted.size()*.95)] if not sorted.is_empty() else 0.0
	print("SCENARIO %s frames=%d median=%.1f p95=%.1f max=%.1f spikes=%d" % [name,sorted.size(),median,p95,sorted.back() if not sorted.is_empty() else 0.0,spikes.size()])
	for spike in spikes.slice(0,12):print("  SPIKE ",spike)
func run():
	Game.save_enabled=false;Game.sound_enabled=true;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	Campaign.configure(1)
	arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=14;add_child(arena);arena.auto_pause_enabled=false
	arena.begin_room(3);await frames(90)
	arena.room.spawn_queue.clear()
	for actor in arena.room.actors:
		if is_instance_valid(actor) and not actor.player_owned:actor.set_physics_process(false)
	arena.phase="combat"
	await scenario("warmup_up",Vector2i.UP,3.0)
	await scenario("air_side",Vector2i.LEFT,6.0)
	# Wall directly in front: build a brick row above the soldier.
	var cell=arena.player.cell+Vector2i.UP*2
	for x in range(-1,2):
		var c=cell+Vector2i(x,0)
		if not arena.room.walls.has(c):arena.add_wall(c,40)
	await scenario("bricks_up",Vector2i.UP,6.0)
	for i in range(4):
		var enemy=arena.spawn_actor("soldier",arena.find_free_near(arena.player.cell+Vector2i(3+i,0)),false);enemy.max_hp=500;enemy.hp=500;enemy.set_physics_process(false)
	await scenario("enemies_right",Vector2i.RIGHT,6.0)
	get_tree().quit()
