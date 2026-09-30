extends SceneTree
func _init():
	var model=load("res://assets/models/tile.glb").instantiate()
	for obj in model.find_children("*","MeshInstance3D",true,false):
		var m=obj.get_active_material(0)
		print("MAT ",m.resource_name," albedo ",m.albedo_color," emission ",m.emission_enabled," energy ",m.emission_energy_multiplier," metallic ",m.metallic)
	model.free()
	quit()
