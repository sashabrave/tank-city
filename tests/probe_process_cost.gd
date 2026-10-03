extends Node
## Probe: per-script share of _process time in a night battle (switch each script off, compare TIME_PROCESS).
func avg(frames:int)->float:
	var t=0.0
	for i in range(frames):await get_tree().process_frame;t+=Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
	return t/frames
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	Settings.values.world_lighting="night";Settings.values.weather="rain";Settings.values.vsync=false;Settings.values.fps=0;Settings.apply()
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=21;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(5.0).timeout
	var base=await avg(120);print("BASE process ms %.2f" % base)
	var groups={}
	for n in get_tree().root.find_children("*","",true,false):
		if (n.is_processing() or n.is_physics_processing()) and n.get_script():
			var key=n.get_script().resource_path;if not groups.has(key):groups[key]=[]
			groups[key].append(n)
	var rows=[]
	for key in groups:
		var with_it=await avg(60)
		for n in groups[key]:
			n.set_process(false)
			if not key.ends_with("arena.gd"):n.set_physics_process(false)
		var without=await avg(60)
		for n in groups[key]:
			if is_instance_valid(n):n.set_process(true);n.set_physics_process(true)
		rows.append([with_it-without,key,groups[key].size()])
	rows.sort_custom(func(a,b):return a[0]>b[0])
	for r in rows.slice(0,14):print("COST %.2f ms  %s ×%d" % r)
	get_tree().quit()
