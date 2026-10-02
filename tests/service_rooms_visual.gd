extends Node
## Service rooms and the merchant: mood light, pendant lamps, silhouettes outside. /tmp/r13-room-*.png
func _ready():call_deferred("run")
func settle():
	for i in range(3):await get_tree().process_frame
func shot(path):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(path)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	get_window().size=Vector2i(1600,900)
	Campaign.configure(1);Game.profiles.selected=true
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await settle();await settle()
	main.start_run();await settle()
	main.enter_room(0,RoutePlan.build(Game.visual_run_seed)[0][1].id);await settle()
	for branch in ["vehicle","ability","headquarters","merchant"]:
		main.show_service(branch,2);await get_tree().create_timer(.9).timeout
		await shot("/tmp/r13-room-%s.png" % branch)
	get_tree().quit(0)
