extends Node
## Window check of shader styles: vehicle metal, gold drops, soft shadows, haze. Settings/profile writes disabled.
var failures=0
var prefix="/tmp/r13-style-"
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func _ready():call_deferred("run")
func shot(label:String):
	if DisplayServer.get_name()=="headless":return
	await get_tree().create_timer(.7,true,false,true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(prefix+label+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="):prefix=arg.trim_prefix("--prefix=")
	Settings.values.fullscreen=false;Settings.values.world_lighting="day";Settings.values.shaders=true;Settings.values.tilt_shift=false;Settings.apply();Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=4242;arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false);arena.phase="combat";arena.spawn_queue.clear()
	for actor in arena.actors:actor.set_physics_process(false)
	var center=arena.base_model.position+Vector3(0,0,-3)
	var models=[]
	for entry in [["tank",Vector3(-1.4,0,0)],["apc",Vector3(0,0,-.2)],["buggy",Vector3(1.4,0,.1)],["boss",Vector3(0,0,-2.1)]]:
		var model=Visuals.model(entry[0],arena,center+entry[1]);model.rotation.y=deg_to_rad(-25);models.append(model)
	models[3].set_paint("enemy",1)
	for i in range(3):
		var drop=load("res://scripts/resource_drop.gd").new();drop.arena=arena;drop.denomination=[1,5,10][i];drop.position=center+Vector3(.9+i*.55,.4,.9);arena.add_child(drop);arena.room.resource_drops.append(drop)
	if arena.presentation:arena.presentation.set_process(false)
	if arena.hud:arena.hud.visible=false
	var camera=arena.camera;camera.size=7.5;camera.position=center+Vector3(0,19,14).rotated(Vector3.UP,deg_to_rad(10));camera.look_at(center)
	var styles=Settings.SHADER_STYLES if "SHADER_STYLES" in Settings else ["current"]
	# Let the start-of-battle dim finish first.
	await get_tree().create_timer(3.0,true,false,true).timeout
	for style in styles:
		if "shader_style" in Settings.values:Settings.change("shader_style",style)
		camera.size=7.5;await shot(style)
		camera.size=3.6;await shot(style+"-close");camera.size=7.5
	Settings.change("shader_style","pastel");Settings.change("haze",false);await shot("pastel-nohaze");Settings.change("haze",true)
	Settings.change("world_lighting","night");await shot("night")
	Settings.change("shaders",false);await shot("off")
	check(not arena.get_node("WorldLighting").environment.glow_enabled,"Off disables glow")
	Settings.change("shaders",true);Settings.change("world_lighting","day")
	arena.queue_free();await get_tree().process_frame
	var hub=preload("res://scripts/hub.gd").open_practice(self)
	await get_tree().create_timer(1.5,true,false,true).timeout
	await shot("hub")
	var layer=CanvasLayer.new();add_child(layer);layer.layer=200
	var tablet=load("res://scripts/ui/field_tablet.gd").new();tablet.tab="settings";tablet.settings_tab="Видео";layer.add_child(tablet)
	await shot("tablet")
	var scroll=tablet.find_children("*","ScrollContainer",true,false)
	if not scroll.is_empty():scroll[0].scroll_vertical=300
	await shot("tablet-scroll")
	var toggles=tablet.find_children("*","CheckButton",true,false)
	check(toggles.size()>=7,"Master toggle plus six style options")
	layer.queue_free();hub.queue_free();await get_tree().process_frame
	print("STYLES "+("PASS" if failures==0 else "FAIL %d"%failures))
	get_tree().quit(failures)
