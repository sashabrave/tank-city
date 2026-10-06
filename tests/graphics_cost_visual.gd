extends Node
## What each graphics switch costs on the GPU (2026-10-05): fullscreen Retina, a battle field with the HUD up,
## enemies on the field. FPS on a ProMotion screen sits at the ~145 Hz ceiling, so this reads the measured GPU
## and CPU render time per frame instead, averaged over a few seconds, with the base re-measured between
## options to show the noise. Windowed only, not in the suites. Saves and settings stay off.
## Run: Godot --path . tests/graphics_cost_visual.tscn   (-- night for the night lighting, -- quick for the base only)
var acc:={"gpu":0.0,"cpu":0.0,"draw":0.0,"n":0}
var last:=0
var recording:=false
func _ready():call_deferred("run")
func _process(_d):
	if not recording:return
	var now=Time.get_ticks_usec()
	if last>0:acc.gpu+=(now-last)/1000.0
	last=now
	var vp=get_viewport().get_viewport_rid()
	acc.cpu+=RenderingServer.viewport_get_measured_render_time_cpu(vp)
	acc.draw+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME);acc.n+=1
func sample(seconds:=3.0)->Dictionary:
	await get_tree().create_timer(1.0).timeout
	acc={"gpu":0.0,"cpu":0.0,"draw":0.0,"n":0};last=0;recording=true
	await get_tree().create_timer(seconds).timeout
	recording=false
	var n=maxf(1,acc.n)
	return {"gpu":acc.gpu/n,"cpu":acc.cpu/n,"draw":acc.draw/n}
func report(label:String,r:Dictionary,base:Dictionary):
	print("GFX %-26s frame %5.2f ms (%+5.1f%%) · render cpu %4.2f · draw %4.0f" % [label,r.gpu,(r.gpu/maxf(.01,base.gpu)-1)*100,r.cpu,r.draw])
func set_value(key:String,value):
	Settings.values[key]=value;Settings.apply()
	if key=="ui_glass":get_tree().call_group("ui_glass","queue_redraw")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Engine.set_meta("hub_calls_off",true)
	Settings.values.fullscreen=true;Settings.values.retina=true;Settings.values.vsync=false;Settings.values.fps=0;Settings.values.render_scale="100"
	if "night" in OS.get_cmdline_user_args():Settings.values.world_lighting="night"
	Settings.apply();Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=21;add_child(arena);arena.auto_pause_enabled=false
	arena.begin_room(4);await get_tree().create_timer(5.0).timeout
	DisplayServer.window_move_to_foreground()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	print("GFX (frame = mean wall time per frame, 3D at full size) window %s · 3D scale %.2f · light %s" % [DisplayServer.window_get_size(),get_viewport().scaling_3d_scale,Settings.values.world_lighting])
	var base=await sample()
	report("base (standard)",base,base)
	if "quick" in OS.get_cmdline_user_args():get_tree().quit();return
	var toggles=["ambient_occlusion","glow","soft_shadows","atmosphere","tilt_shift","haze","rim_light","shiny_metal","depth_light","cinematic_light","ui_glass","shaders"]
	for key in toggles:
		var keep=Settings.values.get(key,true)
		set_value(key,false);report(key+" off",await sample(),base)
		set_value(key,keep)
	report("base again",await sample(),base)
	for scale in ["50","75","100"]:
		set_value("render_scale",scale);report("render_scale "+scale,await sample(),base)
	set_value("render_scale","100")
	set_value("retina",false);report("retina off",await sample(),base);set_value("retina",true)
	for q in [0,2]:
		set_value("quality",q);report("msaa "+["off","2x","4x"][q],await sample(),base)
	set_value("quality",1)
	for budget in [6,14]:
		set_value("light_budget",budget);report("light_budget %d" % budget,await sample(),base)
	set_value("light_budget",10)
	var sun:DirectionalLight3D=null
	for light in arena.find_children("*","DirectionalLight3D",true,false):
		if light.shadow_enabled:sun=light;break
	if sun:
		sun.shadow_enabled=false;report("sun shadow off",await sample(),base);sun.shadow_enabled=true
		var keep_distance=sun.directional_shadow_max_distance
		sun.directional_shadow_max_distance=25;report("sun shadow distance 25",await sample(),base);sun.directional_shadow_max_distance=keep_distance
		var keep_mode=sun.directional_shadow_mode
		sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL;report("sun shadow 1 cascade",await sample(),base);sun.directional_shadow_mode=keep_mode
	for size in [2048,8192]:
		RenderingServer.directional_shadow_atlas_set_size(size,true);report("sun shadow map %d" % size,await sample(),base)
	RenderingServer.directional_shadow_atlas_set_size(4096,true)
	set_value("graphics_preset","eco");Settings.values.merge(Settings.GRAPHICS_PRESETS.eco,true);Settings.apply()
	report("preset eco",await sample(),base)
	get_tree().quit()
