extends Node
var failures=0
var checks=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error(message)
	else:print("PASS: ",message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.reset_upgrades()
	Game.built_workshops=["yard","range","garage"]
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);hub.set_physics_process(false)
	await get_tree().create_timer(.8).timeout
	check(hub.phase=="combat" and not is_instance_valid(hub.build_menu),"station hidden after the printer intro")
	hub.avatar.position=Vector3(2,0,0);hub.cell=Vector2i(2,0);hub.interact();check(not is_instance_valid(hub.build_menu),"E away from stations does not open one")
	hub.avatar.position=hub.printer_pos+Vector3.FORWARD;hub.cell=Vector2i(3,2);hub.interact()
	check(is_instance_valid(hub.build_menu) and hub.build_menu.station_kind=="fighter" and not hub.dpad.enabled and hub.start_button.disabled,"E near the barracks opens its station and disables movement")
	hub.shoot();check(hub.projectiles.is_empty(),"no shooting inside a station")
	hub.close_station();check(hub.phase=="combat" and hub.dpad.enabled,"close restores controls")
	# Range dummy stands in the yard (built «range»); shots fly north along the pen.
	hub.avatar.position=hub.YARD_DUMMY+Vector3(0,0,2);hub.cell=Vector2i(16,0);hub.facing=Vector2i.UP;hub.shoot()
	var bullet=hub.projectiles.back();bullet.set_physics_process(false);bullet._physics_process(.4)
	check(hub.dummy_hits==1,"soldier shot hits the yard dummy")
	hub.mounted=true;hub.training_tank.position=hub.YARD_DUMMY+Vector3(0,0,2);hub.shoot()
	bullet=hub.projectiles.back();bullet.set_physics_process(false);bullet._physics_process(.4)
	check(hub.dummy_hits==2 and hub.dummy_label.text==Texts.render("−%.2f" % (3+Game.meta_damage())),"tank shot hits the dummy for its own damage")
	hub.free()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	check(is_equal_approx(arena.countdown,3.75),"wave delay 1.5x")
	# Waves are squads (SquadCatalog): exact size, kind caps, content tier per field, drones only as background raids.
	var valid=true;var variants={}
	for seed_value in range(100):
		for room in range(5):
			if room in Campaign.BOSSES:continue
			for wave in range(3):
				var roster=WaveDirector.build(seed_value,room,wave);var kinds=roster.map(func(e):return e.kind)
				valid=valid and roster.size()==WaveDirector.wave_size(room,wave) and not kinds.has("drone") and not kinds.has("flyer")
				for kind in SquadCatalog.CAPS:
					if kind!="rpg":valid=valid and kinds.count(kind)<=SquadCatalog.CAPS[kind]
				if room<2:valid=valid and kinds.all(func(k):return k in ["soldier","shield","grenadier"]) and (wave>0 or not kinds.has("grenadier"))
				valid=valid and kinds.has("tank")==WaveDirector.tanks_in_wave(room,wave)
				if WaveDirector.tanks_in_wave(room,wave):valid=valid and kinds[0]=="tank"
				variants[str(room)+str(wave)+str(kinds)]=true
	check(valid,"1500 waves keep size, caps, tiers and tank pacing")
	check(variants.size()>100,"many varied wave combinations")
	arena.phase="combat";arena._physics_process(.3)
	var enemy=arena.actors.back()
	check(arena.wave_roster[0].state=="active","roster marks spawned enemy")
	enemy.take_damage(999);check(arena.wave_roster[0].state=="dead","roster marks killed enemy")
	arena.free();print("HUB/WAVES: ",checks," checks, ",failures," failures");get_tree().quit(failures)
