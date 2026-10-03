extends Node3D
## Route map: merchant and upgrade stops are Blender models (assets/models/route/*.glb) when the files exist.
## Window shot /tmp/r13-route-merchant.png. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	get_window().size=Vector2i(1600,900)
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=42;route.available=1;add_child(route)
	await get_tree().create_timer(1.0).timeout
	var shops=route.find_children("MerchantShop","",true,false)
	check(not shops.is_empty(),"merchant stop shows the shop truck model (%d)" % shops.size())
	for pair in [["TrainingPoint",preload("res://scripts/route_miniatures.gd").TRAINING_MODEL],["MechanicPoint",preload("res://scripts/route_miniatures.gd").MECHANIC_MODEL],["WorkshopPoint",preload("res://scripts/route_miniatures.gd").WORKSHOP_MODEL],["CommandPostPoint",preload("res://scripts/route_miniatures.gd").COMMAND_POST_MODEL]]:
		if ResourceLoader.exists(pair[1]):check(not route.find_children(pair[0],"",true,false).is_empty(),"%s shows its Blender model" % pair[0])
	if not shops.is_empty():
		var z=shops[0].global_position.z
		route.follow_camera=false;route.scroll=-z+2.0;route.move_camera()
		await get_tree().create_timer(1.0).timeout
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-route-merchant.png")
	print("ROUTE MERCHANT: %d failures" % failures);get_tree().quit(1 if failures else 0)
