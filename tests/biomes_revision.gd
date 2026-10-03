extends Node3D
## Biomes by world and route part, container packs in urban fields, clutter, live route weather.
## Window shots /tmp/r13-biome-*.png. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func shot(path):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(path)
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	get_window().size=Vector2i(1600,900)
	var B=preload("res://scripts/biome_catalog.gd")
	Campaign.configure(1)
	var early=[];var late=[]
	for s in range(60):
		early.append(B.entry(s,0).family);late.append(B.entry(s,5).family)
	check(early.all(func(f):return f in ["forest","steppe","coast","urban"]),"world 1 opens on calm ground (forest, steppe, coast, city)")
	check(late.all(func(f):return f in ["desert","marsh","frost","ash","urban"]) and ("frost" in late or "ash" in late),"world 1 ends on hard ground (frost, ash, marsh, desert, city)")
	check(B.world_line(1).split(", ").size()==8 or Settings.values.get("language","ru")!="ru","world 1 carries all eight families: "+B.world_line(1))
	# Urban field with containers.
	var seed_value=-1
	for s in range(400):
		if B.entry(s,4).family=="urban":seed_value=s;break
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=seed_value;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(.4).timeout
	arena.begin_room(4);await get_tree().create_timer(1.2).timeout;arena.set_physics_process(false)
	var dressing=arena.get_node_or_null("FieldDressing")
	var boxes=dressing.find_children("Container","Node3D",false,false) if dressing else []
	check(arena.room_palette().family=="urban","urban field (%s)" % arena.room_palette().name)
	check(boxes.size()>=1,"container packs placed (%d)" % boxes.size())
	check(arena.walls.values().filter(func(w):return w.get("style_kind","")=="container").all(func(w):return w.hp<0),"containers are indestructible")
	check(dressing.connected(),"every entrance still reaches the HQ")
	check(dressing.find_children("Clutter","Node3D",false,false).size()>0,"a little floor clutter")
	await shot("/tmp/r13-biome-urban.png")
	arena.queue_free();await get_tree().process_frame
	# Route map with live weather.
	Settings.values.weather="rain";Settings.values.rain_style="downpour"
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=seed_value;add_child(route)
	await get_tree().create_timer(1.6).timeout
	check(route.find_children("Fall","CPUParticles3D",true,false).size()>0,"route tiles show falling rain")
	check(route.find_children("Bolt","Node3D",true,false).size()>0,"a downpour is a thunderstorm")
	await shot("/tmp/r13-biome-route.png")
	Settings.values.weather="random";Settings.values.rain_style=""
	print("BIOMES: %d failures" % failures);get_tree().quit(1 if failures else 0)
