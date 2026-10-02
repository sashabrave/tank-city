extends Node
## «Развитие заставы» board in the hub: one next goal per track. Window shots /tmp/r13-roadmap-*.png.
## Profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func shot(path):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(path)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	get_window().size=Vector2i(1600,900)
	Game.progression.counters["world_depth_1"]=3
	var station=preload("res://scripts/ui/stations/roadmap_station.gd").new()
	for tab in station.tabs():
		var items=station.items(tab[0])
		check(items.filter(func(i):return i.status=="goal").size()<=1,"one next goal on "+tab[0])
	check(station.items("story")[1].status=="done" and station.items("story")[2].status=="goal","story: third field done, approach is next")
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub)
	await get_tree().create_timer(1.2).timeout
	for ring in hub.find_children("IncomingCall","",true,false):ring.queue_free()
	hub.avatar.position=hub.ROADMAP_POS+Vector3(0,0,1);hub.cell=Vector2i(1,-1);hub.destination=hub.avatar.position
	await get_tree().create_timer(.4).timeout
	await shot("/tmp/r13-roadmap-hub.png")
	hub.interact();await get_tree().create_timer(.6).timeout
	check(hub.find_child("Station_roadmap",true,false)!=null,"board opens the roadmap station")
	await shot("/tmp/r13-roadmap-screen.png")
	hub.queue_free();await get_tree().process_frame
	print("ROADMAP: %d failures" % failures);get_tree().quit(1 if failures else 0)
