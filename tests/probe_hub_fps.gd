extends Node
## Probe: hub FPS per graphics preset and per «Кино» ingredient (windowed only). Not part of the suites.
func _ready():call_deferred("run")
func measure(label)->void:
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().create_timer(1.5).timeout
	var frames=Engine.get_frames_drawn();var t=Time.get_ticks_msec()
	await get_tree().create_timer(2.5).timeout
	print("FPS %s: %.1f" % [label,(Engine.get_frames_drawn()-frames)*1000.0/(Time.get_ticks_msec()-t)])
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.values.vsync=false;Settings.values.fps=0;Settings.apply()
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	for night in ["day","night"]:
		Settings.values.world_lighting=night
		for preset in ["standard","cinema"]:
			Settings.change("graphics_preset",preset);await measure(night+" "+preset)
		Settings.values.render_scale="auto";Settings.apply();await measure(night+" cinema scale-auto")
		Settings.values.render_scale="100";Settings.values.light_budget=10;Settings.apply();await measure(night+" cinema budget10")
		var we=get_tree().root.find_children("*","WorldEnvironment",true,false)
		if we:we[0].environment.ssil_enabled=false
		await measure(night+" cinema budget10 no-ssil")
	get_tree().quit()
