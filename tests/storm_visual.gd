extends Node3D
## Battle thunderstorm (T-074): rain over the whole view in gusts, lightning flash, thunder event.
## Window shots /tmp/r13-storm-rain.png and /tmp/r13-storm-flash.png.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func shot(path):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(path)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	Settings.values.world_lighting="night";Settings.values.weather="rain";Settings.values.rain_style="downpour"
	get_window().size=Vector2i(1600,900)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=21;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.4).timeout
	var weather=arena.get_node("Weather")
	check(weather.kind=="rain" and is_instance_valid(weather.storm_light),"rain brings a storm light")
	check(weather.batches[0].material_override.get_shader_parameter("area")>arena.grid_size+10,"rain covers more than the field")
	await shot("/tmp/r13-storm-rain.png")
	weather.storm_wait=0.0
	var top=0.0;var shot_taken=false
	for i in range(30):
		await get_tree().process_frame;top=maxf(top,weather.storm_light.light_energy)
		if top>.5 and not shot_taken:shot_taken=true;await shot("/tmp/r13-storm-flash.png")
	check(top>.5,"lightning flashes (%.2f)" % top)
	await get_tree().create_timer(1.5).timeout
	check(weather.storm_light.light_energy<.05 and weather.storm_wait>1.5,"flash fades, next one later (%.2f, %.1f)" % [weather.storm_light.light_energy,weather.storm_wait])
	Settings.values.weather="random";Settings.values.rain_style="";Settings.values.world_lighting="day"
	print("STORM: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
