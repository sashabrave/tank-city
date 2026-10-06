extends Node
## Same look after merging (T-331): the same battle field rendered with MeshMerge off and on, saved side by
## side, with the share of pixels that differ. Windowed only, not in the suites. Saves and settings stay off.
## Run: Godot --path . tests/mesh_merge_visual.tscn   → /tmp/mesh_merge_off_<case>.png, /tmp/mesh_merge_on_<case>.png (field day/night, hub)
func _ready():call_deferred("run")
func shot(merged:bool,night:bool,place:="field")->Image:
	MeshMerge.enabled=merged
	Settings.values.world_lighting="night" if night else "day";Settings.apply()
	Campaign.configure(1)
	var arena
	if place=="hub":arena=preload("res://scripts/hub.gd").open_practice(self)
	else:
		arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=21;add_child(arena);arena.auto_pause_enabled=false
		arena.begin_room(4)
	for i in range(240):await get_tree().process_frame
	arena.process_mode=Node.PROCESS_MODE_DISABLED
	await RenderingServer.frame_post_draw
	var draws=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var image=get_viewport().get_texture().get_image()
	print("MERGE %s %s %s draws %d" % [place,"on" if merged else "off","night" if night else "day",draws])
	arena.queue_free();await get_tree().process_frame;await get_tree().process_frame
	return image
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Engine.set_meta("hub_calls_off",true)
	Settings.values.fullscreen=false;Settings.values.atmosphere=false;Settings.values.weather="clear";Settings.values.sun_day="noon";Settings.values.sun_night="moon";Settings.apply()
	get_window().size=Vector2i(1600,900)
	for case in [["field",false],["field",true],["hub",false]]:
		var night:bool=case[1]
		var before=await shot(false,night,case[0]);var after=await shot(true,night,case[0])
		var tag=case[0]+("_night" if night else "_day")
		before.save_png("/tmp/mesh_merge_off_%s.png" % tag);after.save_png("/tmp/mesh_merge_on_%s.png" % tag)
		var differ=0;var total=0
		for y in range(0,before.get_height(),2):
			for x in range(0,before.get_width(),2):
				total+=1
				var a=before.get_pixel(x,y);var b=after.get_pixel(x,y)
				if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.06:differ+=1
		print("MERGE %s pixels differing %.2f%%" % [tag,100.0*differ/maxf(1,total)])
	get_tree().quit()
