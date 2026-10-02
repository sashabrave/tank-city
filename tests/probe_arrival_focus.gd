extends Node
## Probe: which control holds focus when the hub greeting opens.
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	var hub=load("res://scenes/hub.tscn").instantiate();hub.arrival_reason="wake";add_child(hub)
	for t in [.1,.5,1.5]:
		await get_tree().create_timer(t).timeout
		var f=get_viewport().gui_get_focus_owner()
		print("FOCUS %.1f: %s %s" % [t,f,(f.text if f is Button else "")])
	get_tree().quit()
