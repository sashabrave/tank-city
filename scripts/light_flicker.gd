extends Node
## Rare, believable lamp flicker: every 6–16 s a short stutter (two or three dips), then steady light.
## Child of a Light3D; visual RNG only, never the combat RNG.
var light:Light3D
var base=1.0
var wait=0.0
var steps:Array=[]
var rng=RandomNumberGenerator.new()
static func attach(target:Light3D,seed_value:int):
	var f=load("res://scripts/light_flicker.gd").new();f.name="Flicker";f.rng.seed=seed_value;target.add_child(f)
func _ready():
	light=get_parent() as Light3D;base=light.light_energy;wait=rng.randf_range(3.0,14.0)
func _process(delta):
	if not is_instance_valid(light):return
	if steps.is_empty():
		wait-=delta
		if wait>0:return
		wait=rng.randf_range(6.0,16.0);base=light.light_energy if light.light_energy>0 else base
		for i in range(rng.randi_range(2,3)):steps.append_array([[rng.randf_range(.04,.09),rng.randf_range(.05,.35)],[rng.randf_range(.05,.12),1.0]])
	steps[0][0]-=delta
	light.light_energy=base*float(steps[0][1])
	if steps[0][0]<=0:steps.pop_front();if steps.is_empty():light.light_energy=base
