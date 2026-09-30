extends Node3D
var failures=0
func check(ok,message):
	if not ok:failures+=1;push_error(message)
	else:print("PASS ",message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false
	Visuals.setup_world(self,7.0,Vector3(0,0,0))
	var ids=["boss","tank","apc","buggy","drone","flyer","soldier"]
	var x=-2.8
	for kind in ids:
		var m=Visuals.model(kind,self,Vector3(x,0,0));x+=1.2 if kind=="boss" else .85
		m.rotation.y=PI
		m.set_process(false)
		check(m.kind==kind,"updated model "+kind)
		var bounds=Visuals.mesh_bounds(m,Transform3D.IDENTITY)
		print(kind," bounds ",bounds.size)
		if kind in ["apc","buggy","drone"]:
			check(m.wheels.size()==(6 if kind=="apc" else 4),"wheel count "+kind)
			var before=m.wheels[0].transform;m.preview_moving=true;m._process(.1)
			check(not m.wheels[0].transform.is_equal_approx(before),"wheel rotates "+kind)
		if kind in ["boss","tank"]:
			var track=Visuals.named_part(m,"track_L");var before=track.transform;m.preview_moving=true;m._process(.1)
			check(track.transform.is_equal_approx(before),"tracks stay static "+kind)
		if kind in ["drone","flyer"]:
			check(m.beacons.size()==1,"isolated beacon "+kind)
			m.clock=1;m._process(.01);check(m.beacons[0].emission_energy_multiplier==0,"beacon mostly off")
			m.clock=3.8;m._process(.01);check(m.beacons[0].emission_energy_multiplier>0,"brief beacon flash")
		if not m.recoils.is_empty():
			m.kick();m._process(.03);check(m.recoils[0].position!=m.homes[0],"recoil "+kind)
			m._process(.3);check(m.recoils[0].position.is_equal_approx(m.homes[0]),"recoil returns "+kind)
		if not m.yaws.is_empty():
			m.aim(m.global_rotation.y+.5,.2);m._process(.5)
			check(is_equal_approx(m.yaws[0].rotation.y,.5),"turret aim "+kind)
		if kind=="soldier":
			check(m.skeleton.get_bone_count()==17,"hero 17 bones")
			print("CLIPS ",m.player.get_animation_list())
			check(m.player.has_animation("hero_walk"),"walk clip imported")
			m.preview_moving=true;m._process(.1);check(m.player.current_animation=="hero_walk","walk triggered")
	await get_tree().create_timer(.3).timeout
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw();get_viewport().get_texture().get_image().save_png("res://art_demo/kit_detail_v4/godot_kit_preview.png")
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena)
	arena.auto_pause_enabled=false;arena.begin_room(2);arena.phase="combat";arena.set_physics_process(false)
	for kind in ids:
		var actor=arena.spawn_actor(kind,Vector2i(2,2),false);actor.set_physics_process(false)
		check(actor.model.kind==kind,"actor uses kit "+kind)
		actor.model.set_process(false)
		actor.model.kick();actor.model._process(.02)
		var before=actor.model.clock;arena.phase="paused";actor.model._process(.5)
		check(actor.model.clock==before,"pause freezes animation "+kind)
		arena.phase="combat"
		if kind=="boss":arena.boss_step(actor,.1)
		if kind=="flyer":actor.flight_state="burst";actor.flight_timer=0;arena.flyer_step(actor,.1);check(actor.model.recoil==1,"flyer firing kicks turret")
		arena.actors.erase(actor);actor.free()
	arena.free()
	print("KIT FAILURES ",failures);get_tree().quit(failures)
