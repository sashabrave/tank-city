extends Node
## Probe: in the hub tablet, change display options through the real controls and press Apply / Keep.
func _ready():call_deferred("run")
func btn(root,text)->Button:
	for b in root.find_children("*","Button",true,false):
		if b.is_visible_in_tree() and b.text.contains(text):return b
	return null
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(1.5).timeout
	preload("res://scripts/ui/pause_tablet.gd").open(hub,Callable(),Callable(),"settings")
	await get_tree().create_timer(.5).timeout
	var view=get_tree().root.find_children("*","Control",true,false).filter(func(n):return n.get_script()==preload("res://scripts/ui/field_tablet.gd"))[0]
	view.settings_tab="Экран";view.refresh();await get_tree().create_timer(.3).timeout
	print("START mode=",DisplayServer.window_get_mode()," msaa=",get_viewport().msaa_3d)
	var options=view.find_children("*","OptionButton",true,false)
	print("OPTIONS ",options.size())
	# First option = screen mode, MSAA is the one with 3 items «Выключено, 2×, 4×».
	options[0].select(1);options[0].item_selected.emit(1)
	await get_tree().create_timer(.3).timeout
	var apply=btn(view,"Применить");print("APPLY enabled=",apply!=null and not apply.disabled," pending=",Settings.pending)
	apply.pressed.emit();await get_tree().create_timer(1.5).timeout
	print("AFTER APPLY mode=",DisplayServer.window_get_mode())
	var keep=btn(get_tree().root,"Оставить");print("KEEP found=",keep!=null)
	if keep:keep.pressed.emit()
	await get_tree().create_timer(.5).timeout
	print("FINAL mode=",DisplayServer.window_get_mode()," values.fullscreen=",Settings.values.fullscreen)
	Settings.change("fullscreen",false);Settings.apply_pending();Settings.before_apply={}
	await get_tree().create_timer(1.0).timeout
	get_tree().paused=false;get_tree().quit()
