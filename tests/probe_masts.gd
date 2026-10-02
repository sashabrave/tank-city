extends Node3D
## Probe: corner mast lights at night — visible, energy, where the beam hits.
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	Settings.values.world_lighting="night";Settings.values.weather="clear"
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=21;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.6).timeout
	for rig in arena.find_children("MilitaryLightStand","Node3D",true,false):
		for l in rig.find_children("*","SpotLight3D",true,false):
			var dir=-l.global_basis.z;var hit=l.global_position+dir*(l.global_position.y/maxf(.01,-dir.y))
			print("MAST vis=%s e=%.2f pos=%s hit=%s range=%.1f budget=%d" % [l.visible,l.light_energy,l.global_position.snapped(Vector3.ONE*.1),hit.snapped(Vector3.ONE*.1),l.spot_range,Settings.values.light_budget])
	print("LAMPS total ",get_tree().get_nodes_in_group("night_lamps").filter(func(n):return n.visible).size()," of ",get_tree().get_nodes_in_group("night_lamps").size())
	get_tree().quit()
