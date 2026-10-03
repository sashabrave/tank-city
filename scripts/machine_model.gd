extends Node
## Room machine models (medkit, ammo gacha, slot machine; art_requests/route_services_v2/build/room_machines.py):
## loads the model under a machine node, adds its coloured light and blinks the two bulb materials in turn.
## Visual only: own clock, no game RNG.
var bulbs_a:Array=[]
var bulbs_b:Array=[]
var light:OmniLight3D
var clock=0.0

## Adds the model to machine; false when the file is missing (the machine keeps its box look).
static func attach(machine:Node3D,path:String,light_color:Color,light_height:=1.3)->bool:
	if not ResourceLoader.exists(path):return false
	var model:Node3D=load(path).instantiate();model.name="Model";machine.add_child(model)
	preload("res://scripts/route_miniatures.gd").library_surfaces(model)
	var blinker=load("res://scripts/machine_model.gd").new();blinker.name="Bulbs";machine.add_child(blinker)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for i in mesh.get_surface_override_material_count():
			var mat=mesh.get_active_material(i)
			if not mat is StandardMaterial3D:continue
			var key=mat.resource_name.to_lower()
			if key.ends_with("bulba") or key.ends_with("bulbb"):
				mat=mat.duplicate();mesh.set_surface_override_material(i,mat)
				(blinker.bulbs_a if key.ends_with("bulba") else blinker.bulbs_b).append(mat)
	blinker.light=OmniLight3D.new();machine.add_child(blinker.light);blinker.light.position=Vector3(0,light_height,.75)
	blinker.light.light_color=light_color;blinker.light.light_energy=.9;blinker.light.omni_range=2.6;blinker.light.shadow_enabled=false
	return true

func _process(delta):
	clock+=delta
	var on=fposmod(clock,.8)<.4
	for mat in bulbs_a:mat.emission_energy_multiplier=2.0 if on else .35
	for mat in bulbs_b:mat.emission_energy_multiplier=.35 if on else 2.0
	if is_instance_valid(light):light.light_energy=.8+.15*sin(clock*3.0)
