extends Node
var hub
func _ready():call_deferred("run")
func samples(label:String):
	for i in range(45):await get_tree().process_frame
	var times=[];var last=Time.get_ticks_usec()
	for i in range(180):
		if label=="walking":
			if i%60==0:
				Input.action_release("east");Input.action_release("west")
				Input.action_press("east" if i%120==0 else "west")
		await get_tree().process_frame
		var now=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
	Input.action_release("east");Input.action_release("west")
	times.sort();print("HUB PERF ",label," median=",times[90]," p95=",times[171]," max=",times.back()," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," nodes=",Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Settings.values.fullscreen=false;Settings.values.fps=0;Settings.values.vsync=0;Settings.apply()
	var began=Time.get_ticks_usec();hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	print("HUB PERF create ms=",(Time.get_ticks_usec()-began)/1000.0)
	await get_tree().create_timer(1).timeout;hub.phase="combat"
	await samples("idle")
	began=Time.get_ticks_usec()
	for i in range(20):NumberDisplay.refresh()
	print("HUB CPU text pre-draw ms=",(Time.get_ticks_usec()-began)/20000.0)
	var refresh_costs=[]
	for i in range(3):
		began=Time.get_ticks_usec();hub.refresh();refresh_costs.append((Time.get_ticks_usec()-began)/1000.0)
		await get_tree().process_frame
	print("HUB PERF refresh ms=",refresh_costs)
	hub.avatar.position=hub.command_pos+Vector3(1.2,0,0)
	await samples("near-command")
	hub.avatar.position=Vector3(2,0,2)
	var profile={}
	var nodes=get_tree().root.find_children("*","Node",true,false)
	for node in nodes:
		if not is_instance_valid(node) or not node.get_script():continue
		var path=node.get_script().resource_path
		if not (path.begins_with("res://scripts/") and (node.has_method("_process") or node==hub)):continue
		if not node.is_processing() and node!=hub:continue
		var method="_physics_process" if node==hub else "_process"
		began=Time.get_ticks_usec()
		for i in range(20):node.call(method,0.0)
		profile[path]=profile.get(path,0.0)+(Time.get_ticks_usec()-began)/20000.0
	var ranked=profile.keys();ranked.sort_custom(func(a,b):return profile[a]>profile[b])
	for path in ranked.slice(0,12):print("HUB CPU ",path," ms=",profile[path])
	hub.set_physics_process(false)
	await samples("hub-physics-off")
	hub.set_physics_process(true)
	began=Time.get_ticks_usec();hub.show_build_menu();print("HUB PERF build menu ms=",(Time.get_ticks_usec()-began)/1000.0)
	await samples("build-menu");hub.close_station()
	for id in Game.BUILD_COST:
		if id not in Game.built_workshops:Game.built_workshops.append(id)
	hub.update_bench_visuals();hub.avatar.position=Vector3(2,0,1);hub.moving=false
	await samples("walking")
	assert(hub.avatar.position.distance_to(Vector3(2,0,1))>.05,"Movement must be exercised")
	Settings.values.world_lighting="night";Settings.apply()
	await samples("all-buildings-night")
	print("HUB PERFORMANCE COMPLETE");get_tree().quit()
