extends Node3D
## Bounded, Compatibility-friendly effects. No physics bodies or shadow lights.
static var sphere: SphereMesh
var age := 0.0
var pieces: Array[Dictionary] = []
var flash: OmniLight3D
var rng := RandomNumberGenerator.new()

static func spawn(parent: Node3D, origin: Vector3, color: Color, radius: float):
	if parent.get_tree().get_nodes_in_group("combat_effects").size() >= 20:
		return
	var effect = load("res://scripts/combat_effect.gd").new()
	parent.add_child(effect)
	effect.position = origin
	effect.add_to_group("combat_effects")
	effect.build(color,clampf(radius,.08,1.6))

func build(color: Color, radius: float):
	rng.randomize()
	if sphere == null:
		sphere = SphereMesh.new()
		sphere.radial_segments = 12
		sphere.rings = 6
		sphere.radius = .5
		sphere.height = 1.0
	var large = radius >= .65
	for i in range(4 if large else 2):
		var direction = Vector3(rng.randf_range(-1,1),rng.randf_range(.3,1),rng.randf_range(-1,1))
		piece(color.lerp(Color("fff0b0"),rng.randf_range(.1,.7)),direction*radius*1.3,radius*.65,.28,false,0.0)
	for i in range(5 if large else 2):
		var direction = Vector3(rng.randf_range(-1,1),rng.randf_range(.4,1.4),rng.randf_range(-1,1))
		piece(Color("555852"),direction*radius*.8,radius*.7,1.0,true,.08)
	for i in range(6 if large else 3):
		var direction = Vector3(rng.randf_range(-2,2),rng.randf_range(1,3),rng.randf_range(-2,2))
		piece(Color("ffc374"),direction*radius,radius*.09,.48,false,0.0,true)
	if large and get_tree().get_nodes_in_group("blast_lights").size()<3:
		flash = OmniLight3D.new()
		flash.add_to_group("blast_lights")
		flash.light_color = Color("ffb864")
		flash.light_energy = 1.8
		flash.omni_range = radius*3.0
		flash.shadow_enabled = false
		flash.light_volumetric_fog_energy = 0.0
		add_child(flash)
		flash.position.y = .6

func piece(color: Color, velocity: Vector3, size: float, lifetime: float, smoke: bool, delay: float, spark := false):
	var mesh = MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if not smoke:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	add_child(mesh)
	mesh.visible = false
	pieces.append({"node":mesh,"mat":mat,"velocity":velocity,"size":size,"life":lifetime,"smoke":smoke,"delay":delay,"spark":spark})

func _process(delta: float):
	age += delta
	for p in pieces:
		var t: float = (age-p.delay)/p.life
		p.node.visible = t>=0.0 and t<1.0
		if not p.node.visible:continue
		var elapsed: float = age-p.delay
		p.node.position = p.velocity*elapsed
		if p.spark:p.node.position.y -= 3.0*elapsed*elapsed
		var factor: float = lerpf(.5,2.0,t) if p.smoke else lerpf(1.0,.05,t)
		p.node.scale = Vector3.ONE*maxf(.001,p.size*factor)
		p.mat.albedo_color.a = (1.0-t)*(.65 if p.smoke else 1.0)
	if is_instance_valid(flash):
		flash.light_energy = maxf(0.0,1.8*(1.0-age/.16))
		if age>.16:flash.queue_free()
	if age>1.15:queue_free()
