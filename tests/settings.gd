extends Node
func _ready():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	Settings.open()
	assert(get_tree().paused)
	Settings.tab=2;Settings.draw();Settings.waiting="fire"
	var event=InputEventKey.new();event.physical_keycode=KEY_E;event.keycode=KEY_E;event.pressed=true
	Settings._input(event)
	assert(Settings.keys.fire==KEY_E and Settings.keys.interact==KEY_SPACE)
	assert(event.is_action("fire"))
	Settings.change("music",0.0)
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("TankCityMusic")))
	Settings.reset_defaults()
	assert(Settings.keys.fire==KEY_SPACE and Settings.values.music==0.8)
	Settings.close()
	assert(not get_tree().paused)
	print("SETTINGS: pause, rebind swap, fire action, mute, reset, resume passed")
	get_tree().quit()
