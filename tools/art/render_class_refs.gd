extends Node3D
## Window render of the in-game cat soldier for each class portrait (reference for art requests).
## Writes art_requests/class_portraits_v17/model_refs/<class>_<view>.png. No profile or settings writes.
const OUT="res://art_requests/class_portraits_v17/model_refs/"
const GEAR={"recruit":"rifle","gunner":"mg","driver":"pistol","heavy":"grenade_launcher","marksman":"sniper","engineer":"smg"}
const VIEWS={"three_quarter":PI-0.6,"front":PI,"side":PI/2}
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	# Interface overlays (currency, FPS, save icon) are not part of the reference.
	for node in get_tree().root.get_children():
		for layer in node.find_children("*","CanvasLayer",true,false)+([node] if node is CanvasLayer else []):layer.visible=false
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("e9e4d6");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("fff6e8");env.environment.ambient_light_energy=.75;add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0);sun.light_energy=1.3;sun.shadow_enabled=true;add_child(sun)
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.25;camera.position=Vector3(0,.5,4);add_child(camera);camera.current=true
	for id in GEAR:
		for view in VIEWS:
			var model=Visuals.model("soldier",self,Vector3.ZERO);model.equip_weapon(GEAR[id]);model.rotation.y=VIEWS[view]
			for i in 6:await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image=get_viewport().get_texture().get_image();var side=image.get_height()
			image=image.get_region(Rect2i((image.get_width()-side)/2,0,side,side));image.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
			image.save_png(ProjectSettings.globalize_path(OUT+id+"_"+view+".png"))
			model.queue_free();await get_tree().process_frame
	print("CLASS REFS done");get_tree().quit()
