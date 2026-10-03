extends Node3D
## Route map: the merchant stop is the Blender military shop truck (assets/models/route/merchant_shop.glb).
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
	if not shops.is_empty():
		var z=shops[0].global_position.z
		route.follow_camera=false;route.scroll=-z+2.0;route.move_camera()
		await get_tree().create_timer(1.0).timeout
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-route-merchant.png")
	print("ROUTE MERCHANT: %d failures" % failures);get_tree().quit(1 if failures else 0)
