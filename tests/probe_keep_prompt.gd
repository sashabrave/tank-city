extends Node
## Probe: Apply a screen change → «keep?» prompt; no answer reverts. Shot /tmp/r13-keep.png.
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false
	get_window().size=Vector2i(1280,720)
	var memory=preload("res://scripts/ui/tablet_memory.gd");memory.loaded=true;memory.state={}
	var view=preload("res://scripts/ui/field_tablet.gd").new();view.tab="settings";view.settings_tab="Экран";add_child(view)
	await get_tree().create_timer(.6).timeout
	Settings.change("quality",0)
	await get_tree().process_frame
	var apply_button=view.find_child("*Применить*",true,false)
	for b in view.find_children("*","Button",true,false):
		if b.text.contains("Применить"):apply_button=b
	apply_button.pressed.emit()
	await get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-keep.png")
	print("PROMPT ",get_tree().root.find_child("KeepDisplayPrompt",true,false)!=null," quality ",Settings.values.quality)
	await get_tree().create_timer(16.0).timeout
	print("AFTER ",get_tree().root.find_child("KeepDisplayPrompt",true,false)!=null," quality ",Settings.values.quality)
	get_tree().quit()
