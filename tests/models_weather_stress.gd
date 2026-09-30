extends Node
## Windowed stress for the cozy model pass: crowded field (vehicles, mortars), downpour with puddles,
## dense fire through groves (shiver, twigs, crackle). Prints median / p95 / max frame time and spikes.
## Run: Godot --path . tests/models_weather_stress.tscn. Saves and settings writes stay disabled.
var arena
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Campaign.configure(3)
	Settings.values.fullscreen=false;Settings.values.fps=0;Settings.values.vsync=0;Settings.values["weather"]="rain";Settings.values["rain_style"]="downpour";Settings.apply()
	arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;arena.run_seed=14;add_child(arena)
	arena.begin_room(5);arena.phase="combat";arena.spawn_queue.clear();arena.player.hp=1e9;arena.base_hp=1e9
	var n=arena.grid_size;var shooters=[]
	for i in range(12):
		var kind=["tank","apc","buggy","mortar"][i%4]
		var a=arena.spawn_actor(kind,Vector2i(1+(i*3)%(n-2),1+int(i/4)*2),false)
		if a:a.max_hp=1e9;a.hp=1e9;shooters.append(a)
	var groves=arena.terrain.vegetation.keys()
	var times=[];var spikes=0;var last=Time.get_ticks_usec();var fired=0
	for frame in range(600):
		# ~40 rounds a second aimed through random groves.
		if frame%2==0 and not groves.is_empty() and not shooters.is_empty():
			var s=shooters[frame%shooters.size()]
			if is_instance_valid(s):
				var target=arena.world_pos(groves[(frame*7)%groves.size()])
				var b=arena.spawn_free_bullet(s,(target-s.position)*Vector3(1,0,1),0.0,9.0,false);b.lifetime=2.5;fired+=1
		await get_tree().process_frame
		var now=Time.get_ticks_usec();var ms=(now-last)/1000.0;last=now
		if frame>30:times.append(ms);if ms>33:spikes+=1
	times.sort()
	print("STRESS fired=",fired," groves=",groves.size()," median_ms=",times[times.size()/2]," p95=",times[int(times.size()*.95)]," max=",times.back()," spikes>33ms=",spikes," twigs_peak_cap=36 draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	get_tree().quit()
