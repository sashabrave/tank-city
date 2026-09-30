extends Node
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false
	var gallery=load("res://scenes/test_gallery.tscn").instantiate();add_child(gallery)
	for entry in [[0,"infantry"],[gallery.sections["Боссы"],"boss"],[gallery.sections["Блоки и разрушение"],"blocks"]]:
		gallery.focus_exhibit(entry[0]);await get_tree().create_timer(.4).timeout
		RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://screenshots/gallery-"+entry[1]+".png")
	gallery.focus_exhibit(0);Input.action_press("fire");Game.touch_fire=true
	await get_tree().create_timer(4).timeout
	Input.action_release("fire");Game.touch_fire=false
	assert(gallery.respawn_count>0,"Holding fire kills and respawns a real enemy")
	print("GALLERY VISUAL: screenshots and live firing complete; targets ",gallery.exhibits.size())
	gallery.queue_free();await get_tree().create_timer(.5).timeout
	print("GALLERY CLEANUP complete")
	get_tree().quit()
