extends Node3D
## Bounded, Compatibility-friendly toon effects. No physics bodies or shadow lights.
## Pieces share four materials; per-piece state goes through instance uniforms.
static var sphere: SphereMesh
static var quad: QuadMesh
static var smoke_material: ShaderMaterial
static var fire_material: ShaderMaterial
static var ring_material: ShaderMaterial
static var scorch_material: ShaderMaterial
var age := 0.0
var lifetime := 1.2
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

static func shared():
	if sphere:return
	sphere = SphereMesh.new();sphere.radial_segments = 12;sphere.rings = 6;sphere.radius = .5;sphere.height = 1.0
	quad = QuadMesh.new();quad.size = Vector2.ONE;quad.orientation = PlaneMesh.FACE_Y
	smoke_material = ShaderMaterial.new();smoke_material.shader = preload("res://shaders/fx/smoke.gdshader")
	fire_material = ShaderMaterial.new();fire_material.shader = preload("res://shaders/fx/fire.gdshader")
	ring_material = ShaderMaterial.new();ring_material.shader = preload("res://shaders/fx/ground_mark.gdshader");ring_material.set_shader_parameter("kind",0)
	scorch_material = ShaderMaterial.new();scorch_material.shader = preload("res://shaders/fx/ground_mark.gdshader");scorch_material.set_shader_parameter("kind",1)

func build(color: Color, radius: float):
	rng.randomize()
	shared()
	var large = radius >= .65
	var hot = color.lerp(Color("ffe08a"),.35)
	# Flash: one quick hot ball.
	piece(fire_material,hot,Vector3.ZERO,radius*(.9 if large else .7),.09 if large else .07,0.0,"flash")
	for i in range(5 if large else 2):
		var direction = Vector3(rng.randf_range(-1,1),rng.randf_range(.2,.9),rng.randf_range(-1,1))
		piece(fire_material,color.lerp(hot,rng.randf_range(0,.4)),direction*radius*2.4,radius*rng.randf_range(.55,.8),rng.randf_range(.3,.42),rng.randf_range(0,.04),"fire")
	# Two smoke tones read as volume even without lighting detail.
	var smoke_light = Color("a9a7a6").lerp(color,.05)
	var smoke_dark = Color("5c5958")
	for i in range(6 if large else 2):
		var direction = Vector3(rng.randf_range(-1,1),rng.randf_range(.3,1.1),rng.randf_range(-1,1))
		var tone = smoke_dark if i%3==0 else smoke_light
		piece(smoke_material,tone.lerp(smoke_light,rng.randf()*.3),direction*radius*2.2,radius*rng.randf_range(.55,.8),rng.randf_range(.85,1.2) if large else .6,rng.randf_range(.13,.22) if large else .06,"smoke")
	if large:
		# A short lingering column rises slowly after the blast.
		for i in range(2):
			piece(smoke_material,smoke_dark.lerp(smoke_light,.35+i*.3),Vector3(rng.randf_range(-.15,.15),.9+i*.35,rng.randf_range(-.15,.15)),radius*(.55-i*.1),1.7,.22+i*.2,"column")
	for i in range(6 if large else 3):
		var direction = Vector3(rng.randf_range(-2,2),rng.randf_range(1.2,3),rng.randf_range(-2,2))
		piece(fire_material,Color("ffc374"),direction*radius,radius*.08,rng.randf_range(.35,.55),0.0,"spark")
	if large and position.y < 1.3:
		ground_ring(radius,color)
		scorch(radius)
	for p in pieces:lifetime = maxf(lifetime,p.delay+p.life)
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

func piece(material: ShaderMaterial, color: Color, velocity: Vector3, size: float, life: float, delay: float, kind: String):
	var mesh = MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	mesh.visible = false
	mesh.rotation = Vector3(rng.randf()*TAU,rng.randf()*TAU,0)
	mesh.set_instance_shader_parameter("tint",color)
	mesh.set_instance_shader_parameter("seed",rng.randf()*10.0)
	pieces.append({"node":mesh,"velocity":velocity,"size":size,"life":life,"delay":delay,"kind":kind})

func ground_ring(radius: float, color: Color):
	var mesh = MeshInstance3D.new();mesh.mesh = quad;mesh.material_override = ring_material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh);mesh.global_position = Vector3(global_position.x,.03,global_position.z)
	mesh.set_instance_shader_parameter("tint",Color("cbbfa9").lerp(color,.2))
	mesh.set_instance_shader_parameter("seed",rng.randf()*10.0)
	pieces.append({"node":mesh,"velocity":Vector3.ZERO,"size":radius*3.4,"life":.42,"delay":0.0,"kind":"ring"})

func scorch(radius: float):
	# Lives on the parent, fades slowly; the newest eight marks are kept.
	var marks = get_tree().get_nodes_in_group("scorch_marks")
	# Repeated blasts on one spot refresh the old mark instead of stacking into a black blot.
	for mark in marks:
		if Vector2(mark.global_position.x-global_position.x,mark.global_position.z-global_position.z).length() < radius*.7:
			mark.remove_from_group("scorch_marks");mark.queue_free()
	marks = get_tree().get_nodes_in_group("scorch_marks")
	if marks.size() >= 8:marks[0].remove_from_group("scorch_marks");marks[0].queue_free()
	var mesh = MeshInstance3D.new();mesh.mesh = quad;mesh.material_override = scorch_material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.add_to_group("scorch_marks")
	get_parent().add_child(mesh);mesh.global_position = Vector3(global_position.x,.022,global_position.z)
	mesh.rotation.y = rng.randf()*TAU;mesh.scale = Vector3.ONE*radius*1.8
	mesh.set_instance_shader_parameter("tint",Color("2f2b27"))
	mesh.set_instance_shader_parameter("seed",rng.randf()*10.0)
	var tween = mesh.create_tween()
	tween.tween_interval(4.5)
	tween.tween_method(func(v):mesh.set_instance_shader_parameter("progress",v),0.0,1.0,2.5)
	tween.tween_callback(mesh.queue_free)

func _process(delta: float):
	age += delta
	for p in pieces:
		var t: float = (age-p.delay)/p.life
		p.node.visible = t>=0.0 and t<1.0
		if not p.node.visible:continue
		var elapsed: float = age-p.delay
		var scale_value := 1.0
		match p.kind:
			"flash":
				scale_value = lerpf(.6,1.25,t)
			"fire":
				p.node.position = p.velocity*(1.0-exp(-5.0*elapsed))/5.0
				scale_value = (1.0-pow(1.0-minf(1,t*5.0),3.0))*lerpf(1.0,.55,t)
			"smoke":
				p.node.position = p.velocity*(1.0-exp(-3.2*elapsed))/3.2+Vector3.UP*.35*elapsed
				scale_value = lerpf(.25,1.5,1.0-pow(1.0-t,2.0))
			"column":
				p.node.position = p.velocity*elapsed
				scale_value = lerpf(.5,1.5,t)
			"spark":
				p.node.position = p.velocity*elapsed
				p.node.position.y -= 3.2*elapsed*elapsed
				scale_value = lerpf(1.0,.2,t)
			"ring":
				scale_value = 1.0
		p.node.scale = Vector3.ONE*maxf(.001,p.size*scale_value)
		# Fire and smoke eat away from the edges; the flash just pops.
		p.node.set_instance_shader_parameter("progress",0.0 if p.kind=="flash" else t)
	if is_instance_valid(flash):
		flash.light_energy = maxf(0.0,1.8*(1.0-age/.16))
		if age>.16:flash.queue_free()
	if age>lifetime:queue_free()
