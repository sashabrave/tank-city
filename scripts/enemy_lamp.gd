extends Node
## Enemy chest lamps (T-237): most dog infantry carry the same lamp as the hero; now and then a dog switches
## it off for a few seconds. Snipers, pistol dogs and drones go dark on purpose. Visual only: its own RNG
## seeded from the visual run seed, never the combat one.
var rig:Node3D
var rng:=RandomNumberGenerator.new()
var clock:=0.0
func setup(target:Node3D,salt:int):
	rig=target;rng.seed=hash([Game.visual_run_seed,salt]);clock=rng.randf_range(4.0,12.0)
func _process(delta:float):
	if not is_instance_valid(rig):queue_free();return
	clock-=delta
	if clock>0:return
	rig.visible=not rig.visible
	clock=rng.randf_range(6.0,14.0) if rig.visible else rng.randf_range(1.5,4.0)
