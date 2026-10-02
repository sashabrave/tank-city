extends Node3D
## Field lamps: about a quarter flicker rarely, the rest stay steady; a flicker returns to full energy.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var total=0;var flickering=0
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=5;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(.6).timeout;arena.set_physics_process(false)
	for room in range(4):
		arena.begin_room(room);await get_tree().process_frame
		var lights=arena.find_children("*","Light3D",true,false).filter(func(l):return str(l.get_path()).contains("MilitaryLightStand") or str(l.get_path()).contains("Floodlight"))
		total+=lights.size();flickering+=lights.filter(func(l):return l.has_node("Flicker")).size()
	check(total>0 and flickering>0 and flickering<total,"some field lamps flicker, not all (%d of %d)" % [flickering,total])
	var light=OmniLight3D.new();add_child(light);light.light_energy=2.0
	var f=preload("res://scripts/light_flicker.gd");f.attach(light,7);var node=light.get_node("Flicker");node.wait=0.0
	var dipped=false
	for i in range(60):
		await get_tree().process_frame
		if light.light_energy<1.9:dipped=true
	check(dipped and is_equal_approx(light.light_energy,2.0),"a flicker dips and comes back to full light")
	print("FLICKER: %d failures" % failures);get_tree().quit(1 if failures else 0)
