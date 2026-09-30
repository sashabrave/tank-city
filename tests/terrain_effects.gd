extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.auto_pause_enabled=false;add_child(arena);arena.set_physics_process(false)
	for a in arena.actors:a.set_physics_process(false)
	var fx=arena.get_node("TerrainAmbience");assert(fx.materials.size()<=2 and fx.get_child_count()==fx.materials.size())
	var before=fx.clock
	await get_tree().create_timer(.08).timeout
	assert(fx.clock>before)
	get_tree().paused=true;before=fx.clock
	await get_tree().create_timer(.08,true).timeout
	assert(fx.clock==before);get_tree().paused=false
	for node in fx.get_children():assert(node.multimesh.instance_count<=64)
	print("PASS lightweight batched terrain effects, clock advances, pause freezes, bounded instances")
	get_tree().quit()
