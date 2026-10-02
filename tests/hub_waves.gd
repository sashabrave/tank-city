extends Node
var failures=0
var checks=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;push_error(message)
	else:print("PASS: ",message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Game.damage_level=0
	var hub=load("res://scenes/hub.tscn").instantiate();add_child(hub);hub.set_physics_process(false)
	check(not is_instance_valid(hub.build_menu),"workshop hidden initially")
	hub.interact();check(not is_instance_valid(hub.build_menu),"E away from workshop does not open it")
	hub.avatar.position=Vector3(0,0,0);hub.cell=Vector2i(0,0);hub.interact()
	check(is_instance_valid(hub.build_menu) and not hub.dpad.enabled and hub.start_button.disabled,"E near workbench opens modal and disables movement")
	hub.shoot();check(hub.projectiles.is_empty(),"no shooting inside workshop")
	hub.close_station();check(hub.phase=="combat" and hub.dpad.enabled,"close restores controls")
	hub.avatar.position=Vector3(2,0,2);hub.cell=Vector2i(2,2);hub.facing=Vector2i.UP;hub.shoot()
	var bullet=hub.projectiles.back();bullet.set_physics_process(false);bullet._physics_process(.4)
	check(hub.dummy_hits==1,"soldier shot hits dummy")
	hub.mounted=true;hub.training_tank.position=Vector3(2,0,2);hub.shoot()
	bullet=hub.projectiles.back();bullet.set_physics_process(false);bullet._physics_process(.4)
	check(hub.dummy_hits==2 and hub.dummy_label.text=="−3","tank shot hits dummy for three")
	hub.free()
	var arena=load("res://scenes/arena.tscn").instantiate();add_child(arena);arena.auto_pause_enabled=false;arena.set_physics_process(false)
	check(is_equal_approx(arena.countdown,3.75),"wave delay 1.5x")
	var director=load("res://scripts/wave_director.gd");var valid=true;var variants={}
	for seed_value in range(100):
		for room in range(5):
			for wave in range(3):
				var baseline=arena.ROOM_WAVES[room][wave];var roster=director.generate(seed_value,room,wave,baseline)
				var before=0;var after=0
				for kind in baseline:before+=director.COST[kind]
				for kind in roster:after+=director.COST[kind]
				valid=valid and before==after and roster.count("drone")<=2 and roster.count("mortar")<=(1 if room==2 else 2)
				if room==0:valid=valid and not roster.has("drone") and not roster.has("apc") and not roster.has("tank") and not roster.has("mortar")
				if wave==2 and room<3:valid=valid and roster.has(["buggy","apc","tank"][room])
				if room==4 and wave==2:valid=valid and roster.all(func(kind):return kind=="tank")
				variants[str(room)+str(wave)+str(roster)]=true
	check(valid,"1500 waves preserve budgets, introduction and specialist limits")
	check(variants.size()>100,"many varied wave combinations")
	arena.phase="combat";arena._physics_process(.3)
	var enemy=arena.actors.back()
	check(arena.wave_roster[0].state=="active","roster marks spawned enemy")
	enemy.take_damage(999);check(arena.wave_roster[0].state=="dead","roster marks killed enemy")
	arena.free();print("HUB/WAVES: ",checks," checks, ",failures," failures");get_tree().quit(failures)
