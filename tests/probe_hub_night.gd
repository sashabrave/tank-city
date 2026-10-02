extends Node
## Probe: hub at night with the default camera, standard preset; window shot /tmp/r13-hubnight.png and FPS.
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false
	Settings.values.world_lighting="night";Settings.values.sun_night="moon";Settings.values.graphics_preset="standard";Settings.values.vsync=false;Settings.values.fps=0;Settings.apply();Engine.max_fps=0
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(2.0).timeout
	var frames=Engine.get_frames_drawn();var t=Time.get_ticks_msec()
	await get_tree().create_timer(3.0).timeout
	print("FPS hub night: %.1f" % ((Engine.get_frames_drawn()-frames)*1000.0/(Time.get_ticks_msec()-t)))
	var lamps=get_tree().get_nodes_in_group("night_lamps")
	print("LAMPS visible %d / %d" % [lamps.filter(func(l):return l.visible).size(),lamps.size()])
	for l in lamps:print("  L %s/%s vis=%s e=%.2f prio=%s pos=%s proj=%s sh=%s" % [l.get_parent().get_parent().name,l.get_parent().name,l.visible,l.light_energy,l.get_meta("priority",0),l.global_position.snapped(Vector3.ONE*.1),l.get("light_projector")!=null,l.shadow_enabled])
	var ao=hub.get_node_or_null("FloorAO");print("AO quads ",ao.multimesh.instance_count if ao else -1)
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-hubnight.png")
	for l in lamps:l.light_projector=null
	await get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-hubnight-noproj.png")
	get_tree().quit()
