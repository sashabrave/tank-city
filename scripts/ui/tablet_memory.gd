extends RefCounted
const PATH="user://tablet_state.cfg"
static var loaded=false
static var state:Dictionary={}
static func read()->Dictionary:
	if not loaded:
		loaded=true
		var config=ConfigFile.new()
		if config.load(PATH)==OK:
			var saved=config.get_value("tablet","state",{})
			if saved is Dictionary:state=saved
	return state
static func write():
	if not Settings.persistence_enabled:return
	var config=ConfigFile.new();config.set_value("tablet","state",state);config.save(PATH)
