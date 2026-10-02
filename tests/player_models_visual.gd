extends Node
# Windowed check: the hub avatar wearing each wardrobe model (frames /tmp/player-model-<id>.png).
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	Game.profiles.selected=true
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	for i in range(20):await get_tree().process_frame
	for id in PlayerModels.MODELS:
		Game.player_model=id;hub.refresh_uniform()
		for i in range(30):await get_tree().process_frame
		var cam=get_viewport().get_camera_3d()
		await RenderingServer.frame_post_draw
		var image=get_viewport().get_texture().get_image()
		image.save_png("/tmp/player-model-"+id+"-game.png")
		# Close-up: crop around the avatar's projected position and enlarge it (the hub camera keeps control).
		var k=Vector2(image.get_size())/get_viewport().get_visible_rect().size   # Retina: image pixels vs viewport points
		var p=cam.unproject_position(hub.avatar.global_position+Vector3.UP*.45)*k
		var half=Vector2i(Vector2(70,80)*k.x)
		var r=Rect2i(Vector2i(p)-half,half*2).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
		var crop=image.get_region(r);crop.resize(crop.get_width()*4,crop.get_height()*4,Image.INTERPOLATE_NEAREST)
		crop.save_png("/tmp/player-model-"+id+"-close.png")
		print("SHOT ",id)
	Game.player_model=PlayerModels.DEFAULT
	get_tree().quit()
