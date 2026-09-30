extends Node
## Window check: weather kinds, snow/sand caps and drifts, block props, mid-battle switch. Writes disabled.
var failures=0
var prefix="/tmp/r13-weather-"
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func _ready():call_deferred("run")
func wait(seconds:float):await get_tree().create_timer(seconds,true,false,true).timeout
func shot(label:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(prefix+label+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="):prefix=arg.trim_prefix("--prefix=")
	Settings.values.fullscreen=false;Settings.values.world_lighting="day";Settings.values.shaders=true;Settings.values.weather="random";Settings.values.sun_day="golden";Settings.apply();Campaign.configure(1)
	var Weather=preload("res://scripts/systems/weather.gd")
	# Chain: deterministic, keeps weather between most stages, respects biome.
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=4242;arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false);arena.phase="combat";arena.spawn_queue.clear()
	for actor in arena.actors:actor.set_physics_process(false)
	if arena.presentation:arena.presentation.set_process(false)
	check(Weather.pick(arena)==Weather.pick(arena),"Weather is deterministic")
	check(Weather.pick(null)=="","No weather outside battle")
	check(arena.find_children("*","MeshInstance3D",true,false).any(func(n):return n.is_in_group("block_dressing")),"Blocks get small props")
	await wait(3.0)
	var camera=arena.camera;var center=arena.base_model.position+Vector3(0,0,-3)
	camera.size=10;camera.position=center+Vector3(0,19,14).rotated(Vector3.UP,deg_to_rad(10));camera.look_at(center)
	for kind in ["clear","rain","snow","fog","sandstorm"]:
		Settings.change("weather",kind);await wait(1.2)
		check(arena.get_node("Weather").kind==kind,"Switch to "+kind)
		var drifts=get_tree().get_nodes_in_group("weather_drifts").size()
		check((drifts>0)==(kind in ["snow","sandstorm"]),"Drifts only for snow and sand: "+kind)
		await shot(kind)
	Settings.change("weather","snow");camera.size=5.5;await wait(.8);await shot("snow-close")
	Settings.change("world_lighting","night");await wait(.8);await shot("snow-night")
	Settings.change("world_lighting","day");Settings.change("weather","random")
	arena.queue_free();await get_tree().process_frame
	print("WEATHER "+("PASS" if failures==0 else "FAIL %d"%failures))
	get_tree().quit(failures)
