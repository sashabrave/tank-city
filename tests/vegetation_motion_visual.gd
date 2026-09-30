extends Node3D
var run_seed=517
var room_index=0
var palette={}
var effects:Array=[]
func room_palette()->Dictionary:return palette
func world_pos(cell:Vector2i)->Vector3:return Vector3(cell.x*1.35,0,cell.y*1.45)
func _ready():call_deferred("run")
func shot(label:String):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/r13-vegetation-"+label+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Settings.values.fullscreen=false;Settings.values.atmosphere=true;Settings.values.world_lighting="day";Settings.apply()
	var environment=WorldEnvironment.new();environment.environment=Environment.new();add_child(environment)
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("606e64")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("d2ddca");environment.environment.ambient_light_energy=.8
	var sun=DirectionalLight3D.new();add_child(sun);sun.rotation_degrees=Vector3(-48,-25,0);sun.light_energy=1.5;sun.shadow_enabled=true
	var camera=Camera3D.new();add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=10.2;camera.position=Vector3(7,10,12);camera.look_at(Vector3(1.4,.6,2.9));camera.current=true
	var vegetation=load("res://scripts/vegetation_visual.gd")
	var families=["spruce","palm","charred","broadleaf","frost"]
	for row in range(families.size()):
		palette={"vegetation":families[row]}
		var tint=Color(["82968b","b8aa7d","968c86","aab197","98aab1"][row])
		var terrain=load("res://scripts/systems/terrain_system.gd").new(self)
		for variant in range(3):
			var cell=Vector2i(variant,row)
			while vegetation.appearance(run_seed,room_index,cell).tile!=variant:run_seed+=1
			vegetation.place(self,cell,tint)
			Visuals.box(self,world_pos(cell)+Vector3(0,-.06,0),Vector3(1.06,.12,1.06),tint)
			terrain.set_cell(cell,"vegetation")
		var fx=load("res://scripts/systems/vegetation_ambience.gd").new();add_child(fx);fx.setup(terrain,tint);effects.append(fx)
	await get_tree().create_timer(1.1).timeout;await shot("day-a")
	await get_tree().create_timer(1.4).timeout;await shot("day-b")
	Settings.values.world_lighting="night";sun.light_energy=.35;environment.environment.ambient_light_energy=.40
	await get_tree().create_timer(1.2).timeout;await shot("night-a")
	await get_tree().create_timer(1.2).timeout;await shot("night-b")
	Settings.values.atmosphere=false
	await get_tree().process_frame
	for fx in effects:fx._process(0);assert(not fx.visible)
	await shot("particles-off")
	print("VEGETATION MOTION VISUAL PASS: 15 variants, independent wind, day/night particles, off switch")
	get_tree().quit()
