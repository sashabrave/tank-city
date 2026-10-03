extends Node
## Screen settings (0.7.2): display options wait for «Применить», other options apply at once and never touch
## the window; resolution list; Retina off halves the 3D density on a 2× screen.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false
	var before=Settings.values.vsync
	Settings.change("vsync",not before)
	check(Settings.values.vsync==before and Settings.pending.has("vsync"),"screen option waits for Apply")
	check(Settings.shown("vsync")==(not before),"page shows the chosen value")
	Settings.apply_pending()
	check(Settings.values.vsync==(not before) and Settings.pending.is_empty(),"Apply takes it over")
	Settings.change("vsync",before);Settings.change("vsync",not before)
	check(Settings.pending.is_empty(),"choosing the current value again leaves nothing pending")
	Settings.change("vsync",before);Settings.save_all()
	check(Settings.values.vsync==before,"Save applies too")
	var mode=DisplayServer.window_get_mode()
	Settings.change("glow",not Settings.values.glow);Settings.change("glow",not Settings.values.glow)
	check(DisplayServer.window_get_mode()==mode,"other options keep the window mode")
	check(not Settings.resolutions().is_empty() and Settings.resolutions()[0].contains("x"),"resolution list (%s)" % ", ".join(Settings.resolutions().slice(0,3)))
	Settings.values.retina=true;var full=Settings.render_scale();Settings.values.retina=false;var half=Settings.render_scale();Settings.values.retina=true
	check(half<=full,"Retina off never renders more (%.2f / %.2f)" % [half,full])
	print("SETTINGS DISPLAY: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
