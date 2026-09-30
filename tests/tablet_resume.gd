extends Node
var failures=0
func check(ok,message):
	if not ok:failures+=1;push_error(message)
func _ready():call_deferred("run_test")
func press_escape():
	var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.physical_keycode=KEY_ESCAPE;event.pressed=true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func release_escape():
	var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.physical_keycode=KEY_ESCAPE;event.pressed=false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run_test():
	process_mode=Node.PROCESS_MODE_ALWAYS
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false
	await get_tree().process_frame
	for phase in ["combat","countdown"]:
		for method in ["escape","continue","cross"]:
			arena.phase=phase;arena.countdown=100
			press_escape()
			await get_tree().process_frame
			release_escape()
			var tablet=get_tree().get_first_node_in_group("field_tablet")
			check(tablet!=null and get_tree().paused and arena.phase=="paused","Esc opens tablet: "+phase)
			if tablet==null:continue
			if method=="escape":press_escape()
			else:
				var label="Продолжить [Esc]" if method=="continue" else "×"
				for button in tablet.get_child(0).find_children("*","Button",true,false):
					if button.text==label:button.pressed.emit();break
			await get_tree().physics_frame
			await get_tree().process_frame
			release_escape()
			check(not get_tree().paused and arena.phase==phase,"Closing resumes "+phase+" via "+method)
			check(get_tree().get_nodes_in_group("field_tablet").is_empty(),"Tablet stays closed via "+method)
			if get_tree().paused:get_tree().paused=false
	arena.queue_free()
	print("TABLET RESUME: ",failures," failures");get_tree().quit(1 if failures else 0)
