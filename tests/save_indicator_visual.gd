extends Node
## Window check: the autosave icon spins in the bottom-right corner over the hub. No profile writes.
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	for i in 40:await get_tree().process_frame
	Game.save_indicator().pulse()
	for i in 12:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/r13-save-indicator.png")
	print("SAVE ICON alpha=%.2f rot=%.2f" % [Game.save_icon.icon.modulate.a,Game.save_icon.icon.rotation]);await get_tree().process_frame
	get_tree().quit()
