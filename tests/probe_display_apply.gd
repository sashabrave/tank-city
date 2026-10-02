extends Node
## Probe: do screen settings really reach the window? (windowed run)
func _ready():call_deferred("run")
func state(tag):
	var vp=get_viewport()
	print("STATE %s mode=%d size=%s scale3d=%.2f mode3d=%d msaa=%d vsync=%d screen_scale=%.1f" % [tag,DisplayServer.window_get_mode(),DisplayServer.window_get_size(),vp.scaling_3d_scale,vp.scaling_3d_mode,vp.msaa_3d,DisplayServer.window_get_vsync_mode(),DisplayServer.screen_get_scale()])
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false
	await get_tree().create_timer(.5).timeout;state("start")
	Settings.change("resolution","1600x900");Settings.apply_pending();await get_tree().create_timer(.6).timeout;state("res1600")
	Settings.change("retina",false);Settings.apply_pending();await get_tree().create_timer(.3).timeout;state("retina_off")
	Settings.change("render_scale","50");Settings.apply_pending();await get_tree().create_timer(.3).timeout;state("scale50")
	Settings.change("quality",2);Settings.apply_pending();await get_tree().create_timer(.3).timeout;state("msaa4")
	Settings.change("fullscreen",true);Settings.apply_pending();await get_tree().create_timer(1.5).timeout;state("full")
	Settings.change("glow",false);await get_tree().create_timer(.3).timeout;state("after_glow")
	Settings.change("fullscreen",false);Settings.apply_pending();await get_tree().create_timer(1.5).timeout;state("windowed")
	get_tree().quit()
