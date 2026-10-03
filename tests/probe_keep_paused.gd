extends Node
## Probe: the keep-settings prompt works inside the paused tablet (button press and countdown).
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false
	var tablet=preload("res://scripts/ui/pause_tablet.gd")
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.0).timeout
	arena.pause_battle();await get_tree().create_timer(.5).timeout
	print("PAUSED ",get_tree().paused)
	var before=Settings.values.quality
	Settings.change("quality",(before+1)%3);Settings.apply_pending()
	var view=get_tree().root.find_children("*","Control",true,false).filter(func(n):return n.get_script()==preload("res://scripts/ui/field_tablet.gd"))[0]
	preload("res://scripts/ui/tablet_pages.gd").new(view).keep_prompt()
	await get_tree().create_timer(2.5).timeout
	var prompt=get_tree().root.find_child("KeepDisplayPrompt",true,false)
	var label=prompt.find_children("*","Label",true,false).filter(func(l):return l.text.contains("через"))
	print("COUNTDOWN ",label[0].text if not label.is_empty() else "?")
	var keep=prompt.find_children("*","Button",true,false).filter(func(b):return b.text.contains("Оставить"))[0]
	keep.pressed.emit();await get_tree().process_frame
	print("KEPT ",Settings.values.quality!=before," prompt_gone ",get_tree().root.find_child("KeepDisplayPrompt",true,false)==null)
	get_tree().paused=false;get_tree().quit()
