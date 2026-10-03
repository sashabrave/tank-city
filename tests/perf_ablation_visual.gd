extends Node
## Which graphics option costs the most (2026-10-03): fullscreen Retina, unlocked FPS, a battle field;
## each option switched off alone, then back. Windowed only, not in the suites.
func _ready():call_deferred("run")
func fps(seconds:=2.5)->float:
	await get_tree().create_timer(.8).timeout
	var f=Engine.get_frames_drawn();var t=Time.get_ticks_msec()
	await get_tree().create_timer(seconds).timeout
	return (Engine.get_frames_drawn()-f)*1000.0/(Time.get_ticks_msec()-t)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Engine.set_meta("hub_calls_off",true)
	Settings.values.fullscreen=true;Settings.values.retina=true;Settings.values.vsync=false;Settings.values.fps=0;Settings.apply()
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=21;add_child(arena);arena.auto_pause_enabled=false
	arena.begin_room(4);await get_tree().create_timer(4.0).timeout
	DisplayServer.window_move_to_foreground()
	for light in ["day","night"]:
		Settings.values.world_lighting=light;Settings.apply()
		var base=await fps()
		print("ABL %s base %.0f fps" % [light,base])
		for key in ["ambient_occlusion","glow","soft_shadows","atmosphere","tilt_shift","haze","rim_light","shiny_metal","depth_light","cinematic_light","shaders"]:
			var keep=Settings.values.get(key,true)
			Settings.values[key]=false;Settings.apply()
			var v=await fps()
			print("ABL %s %s off: %.0f fps (%+.0f%%)" % [light,key,v,(v/base-1)*100])
			Settings.values[key]=keep;Settings.apply()
		for scale in ["50","75","100"]:
			Settings.values.render_scale=scale;Settings.apply()
			print("ABL %s render_scale %s: %.0f fps" % [light,scale,await fps()])
		Settings.values.render_scale="auto";Settings.apply()
		var budget=Settings.values.light_budget
		Settings.values.light_budget=4;Settings.apply();print("ABL %s light_budget 4: %.0f fps" % [light,await fps()])
		Settings.values.light_budget=budget;Settings.apply()
	get_tree().quit()
