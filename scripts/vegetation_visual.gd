extends RefCounted
## Blender-exported miniatures. Appearance never consumes gameplay RNG.
const WIND=preload("res://assets/shaders/vegetation_wind.gdshader")
static var tinted:Dictionary={}
static func appearance(seed_value:int,room:int,cell:Vector2i)->Dictionary:
	var rng=RandomNumberGenerator.new();rng.seed=hash([seed_value,room,cell,73091])
	return {"tile":rng.randi_range(0,2),"turn":rng.randi_range(0,3),"wind":rng.randf_range(0,100)}
static func model_path(family:String,tile:int)->String:
	return "res://assets/models/vegetation/%s_%02d.glb" % [family,tile]
static func place(arena,cell:Vector2i,tint:Color):
	var family=arena.room_palette().get("vegetation","spruce")
	var spec=appearance(arena.run_seed,arena.room_index,cell)
	var scene=load(model_path(family,spec.tile))
	var node=scene.instantiate();node.name="Vegetation";arena.add_child(node)
	node.position=arena.world_pos(cell);node.rotation.y=spec.turn*PI*.5
	node.set_meta("vegetation_appearance",spec)
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		mesh.set_instance_shader_parameter("wind_offset",spec.wind)
		for surface in range(mesh.mesh.get_surface_count()):
			var original=mesh.mesh.surface_get_material(surface)
			if not original is StandardMaterial3D:continue
			var color=original.albedo_color.lerp(tint,.36)
			var key=str(color)
			if not tinted.has(key):
				var material=ShaderMaterial.new();material.shader=WIND
				material.set_shader_parameter("foliage_color",color);tinted[key]=material
			mesh.set_surface_override_material(surface,tinted[key])
