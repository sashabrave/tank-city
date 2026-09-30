extends Node
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false
	var main=load("res://scenes/main.tscn").instantiate();add_child(main)
	assert(main.current.root.has_node("GalleryButton"))
	main.current.root.get_node("GalleryButton").pressed.emit()
	assert(main.current.exhibits.size()==100 and main.run_arena==null)
	main.current.hub_requested.emit();await get_tree().process_frame
	assert(main.current.has_signal("gallery_requested") and main.run_arena==null)
	print("GALLERY NAVIGATION: hub button, gallery, return passed")
	main.queue_free();await get_tree().process_frame;get_tree().quit()
