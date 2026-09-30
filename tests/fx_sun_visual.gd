extends Node
## Window check: toon explosion phases, battle sun moments, route map clouds. Settings/profile writes disabled.
var failures=0
var prefix="/tmp/r13-fx-"
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func _ready():call_deferred("run")
func wait(seconds:float):await get_tree().create_timer(seconds,true,false,true).timeout
func shot(label:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(prefix+label+".png")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="):prefix=arg.trim_prefix("--prefix=")
	Settings.values.fullscreen=false;Settings.values.world_lighting="day";Settings.values.shaders=true;Settings.values.tilt_shift=false;Settings.values.sun_day="random";Settings.values.sun_night="random";Settings.apply();Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=4242;arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false);arena.phase="combat";arena.spawn_queue.clear()
	for actor in arena.actors:actor.set_physics_process(false)
	if arena.presentation:arena.presentation.set_process(false)
	var center=arena.base_model.position+Vector3(0,0,-3)
	var tank=Visuals.model("tank",arena,center+Vector3(-1.6,0,.4));tank.rotation.y=deg_to_rad(-25)
	var camera=arena.camera
	await wait(3.0)
	# Sun moments: deterministic per room, explicit choice overrides.
	var lighting=arena.get_node("WorldLighting")
	var first=preload("res://scripts/world_lighting.gd").moment(arena,false)
	check(not first.is_empty(),"Battle room gets a sun moment")
	check(preload("res://scripts/world_lighting.gd").moment(arena,false).angle==first.angle,"Moment is deterministic")
	check(preload("res://scripts/world_lighting.gd").moment(null,false).is_empty(),"No moment outside battle")
	camera.size=11;camera.position=center+Vector3(0,19,14).rotated(Vector3.UP,deg_to_rad(10));camera.look_at(center)
	for id in ["dawn","morning","noon","golden","sunset"]:
		Settings.change("sun_day",id);await wait(.4)
		check(lighting.sun.light_color.is_equal_approx(Color(lighting.MOMENTS[id].sun)),"Day moment colour "+id)
		await shot("sun-"+id)
	Settings.change("world_lighting","night")
	for id in ["dusk","moon","predawn"]:
		Settings.change("sun_night",id);await wait(.4);await shot("sun-"+id)
	Settings.change("world_lighting","day");Settings.change("sun_day","golden")
	# Explosion phases, close-up.
	camera.size=4.2;camera.position=center+Vector3(0,19,14).rotated(Vector3.UP,deg_to_rad(10));camera.look_at(center)
	await wait(.5)
	arena.burst(center+Vector3(.6,.35,0),Color("e78331"),1.45)
	arena.burst(center+Vector3(-.9,.5,-1.0),Color("dc9870"),.16)
	check(get_tree().get_nodes_in_group("scorch_marks").size()==1,"Large blast leaves one scorch mark")
	var marks=[.03,.12,.3,.6,1.1]
	var elapsed=0.0
	for mark in marks:
		await wait(mark-elapsed);elapsed=mark;await shot("blast-%03d"%int(mark*100))
	await wait(2.0);check(get_tree().get_nodes_in_group("combat_effects").is_empty(),"Effects free themselves")
	await shot("scorch")
	for i in range(12):arena.burst(center+Vector3(i*.1,.3,0),Color("e78331"),1.2)
	check(get_tree().get_nodes_in_group("scorch_marks").size()<=8,"Scorch marks are bounded")
	await wait(2.4)
	# Markers: calm friendly ring, enemy danger ring, sniper sight.
	GrenadeVisual.marker(arena,center+Vector3(-1.2,0,-.6),1.0,true)
	GrenadeVisual.marker(arena,center+Vector3(1.3,0,-.4),1.0,false)
	var line=Visuals.box(arena,center+Vector3(0,.5,.9),Vector3(.035,.035,3.5),Color("f24436"));line.rotation.y=PI*.5
	line.material_override=EffectLighting.laser(Color("ff263f"),false)
	var halo=Visuals.box(line,Vector3.ZERO,Vector3(.095,.095,3.5),Color("ff263f"));halo.material_override=EffectLighting.laser(Color("ff263f"),true)
	check(Visuals.ring(arena,Color.WHITE).mesh is QuadMesh,"Rings use the flat animated quad")
	await wait(.3);await shot("markers-a");await wait(.45);await shot("markers-b")
	# Projectile family line-up: stationary for the photo.
	for node in get_tree().get_nodes_in_group("scorch_marks"):node.queue_free()
	var kinds=[["bullet",true],["bullet",false],["shell",true],["shell",false],["sniper",false],["rocket",true],["rocket",false],["orb",false]]
	var lineup=[]
	for i in range(kinds.size()):
		var bullet=load("res://scripts/projectile.gd").new();bullet.arena=arena;bullet.friendly=kinds[i][1];bullet.speed=0.0;bullet.lifetime=99.0
		bullet.travel_direction=Vector3.RIGHT.rotated(Vector3.UP,.35)
		bullet.position=center+Vector3(-1.6+(i%4)*1.1,.55,-.9+int(i/4.0)*1.1);arena.add_child(bullet);bullet.set_physics_process(false);lineup.append(bullet)
		match kinds[i][0]:
			"shell":bullet.piercing=true
			"sniper":bullet.sniper_round=true
			"rocket":bullet.rocket_radius=.8;bullet.scale=Vector3.ONE*1.5
			"orb":bullet.orb=true
	await wait(.3);await shot("projectiles-day")
	Settings.change("world_lighting","night");await wait(.3);await shot("projectiles-night");Settings.change("world_lighting","day")
	check(lineup[5].has_node("ProjectileVisual") and lineup[5].get_node("ProjectileVisual").get_child_count()==4,"Rocket gets body, flame core, halo and trail")
	for bullet in lineup:
		if is_instance_valid(bullet):bullet.queue_free()
	arena.queue_free();await get_tree().process_frame
	var route=load("res://scripts/route_map.gd").new();route.wave_seed=92;add_child(route)
	await wait(2.0)
	var atmosphere=route.get_node("WorldAtmosphere")
	check(atmosphere.clouds.size()==1 and atmosphere.clouds[0].multimesh.instance_count>0,"Map has puffy cloud clusters")
	check(atmosphere.batches[0].multimesh.instance_count==0,"Near-camera bokeh removed on map")
	Settings.change("tilt_shift",true)
	await shot("map-day")
	for i in range(3):
		route.scroll+=14;route.move_camera();await wait(.4);await shot("map-scroll-%d"%i)
	Settings.change("tilt_shift",false)
	Settings.change("world_lighting","night");await wait(.5);await shot("map-night")
	Settings.change("world_lighting","day")
	route.queue_free();await get_tree().process_frame
	print("FX SUN "+("PASS" if failures==0 else "FAIL %d"%failures))
	get_tree().quit(failures)
