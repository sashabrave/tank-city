extends RefCounted
## Blender-exported miniatures. Appearance never consumes gameplay RNG.
const WIND=preload("res://assets/shaders/vegetation_wind.gdshader")
const VARIANTS=5  # tools/build_vegetation_v6.py VARIANTS
static var tinted:Dictionary={}
static var fx_rng:=RandomNumberGenerator.new()  # visual only: twigs and crackle timing
static var twig_mesh:BoxMesh
static var twigs_alive:=0
static var last_crackle:=0
static func appearance(seed_value:int,room:int,cell:Vector2i)->Dictionary:
	var rng=RandomNumberGenerator.new();rng.seed=hash([seed_value,room,cell,73091])
	return {"tile":rng.randi_range(0,VARIANTS-1),"turn":rng.randi_range(0,3),"wind":rng.randf_range(0,100)}
static func model_path(family:String,tile:int)->String:
	return "res://assets/models/vegetation/%s_%02d.glb" % [family,tile]
static func place(arena,cell:Vector2i,tint:Color)->Node3D:
	var family=arena.room_palette().get("vegetation","spruce")
	var spec=appearance(arena.run_seed,arena.room_index,cell)
	var scene=load(model_path(family,spec.tile))
	var node=scene.instantiate();node.name="Vegetation";arena.add_child(node)
	node.position=arena.world_pos(cell);node.rotation.y=spec.turn*PI*.5
	node.set_meta("vegetation_appearance",spec);node.set_meta("vegetation_family",family);node.set_meta("vegetation_tint",tint)
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
	return node

## A bullet passing through the grove: a sharp shiver away from the shot, two or three twigs flicked out,
## a light crackle. Purely visual; a tree answers at most every .15 s so a burst does not turn into noise.
static func rustle(node:Node3D,direction:Vector3):
	if not is_instance_valid(node) or not node.is_inside_tree():return
	var now=Time.get_ticks_msec()
	if now-int(node.get_meta("rustled_at",-1000))<150:return
	node.set_meta("rustled_at",now)
	var home:Basis=node.get_meta("rest_basis",node.basis);node.set_meta("rest_basis",home)
	var axis=Vector3.UP.cross(Vector3(direction.x,0,direction.z)).normalized()
	if axis==Vector3.ZERO:axis=Vector3.RIGHT
	var kick=fx_rng.randf_range(.07,.1)
	var previous=node.get_meta("rustle_tween") if node.has_meta("rustle_tween") else null
	if previous is Tween and previous.is_valid():previous.kill()
	var tween=node.create_tween();node.set_meta("rustle_tween",tween)
	tween.tween_method(func(t:float):node.basis=Basis(axis,kick*sin(t*PI*3.0)*exp(-t*3.2))*home,0.0,1.0,.45)
	tween.tween_callback(func():node.basis=home)
	var family=str(node.get_meta("vegetation_family","spruce"))
	var tint:Color=node.get_meta("vegetation_tint",Color("7f9a5b"))
	var leaf={"charred":Color("3a3431"),"frost":Color("e4ecec"),"palm":Color("8fa352")}.get(family,Color("5f8a4c").lerp(tint,.3))
	var bark=Color("6b4f36") if family!="charred" else Color("2b2624")
	for i in range(fx_rng.randi_range(2,3)):twig(node,direction,leaf if i%2==0 else bark)
	if now-last_crackle>70:last_crackle=now;Game.sound("foliage_crack",node)

static func twig(node:Node3D,direction:Vector3,color:Color):
	if twigs_alive>=36:return
	if twig_mesh==null:twig_mesh=BoxMesh.new();twig_mesh.size=Vector3(.07,.018,.028)
	var piece=MeshInstance3D.new();piece.mesh=twig_mesh;piece.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.9;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;piece.material_override=mat
	node.get_parent().add_child(piece);twigs_alive+=1
	var start=node.global_position+Vector3(fx_rng.randf_range(-.2,.2),fx_rng.randf_range(.45,.85),fx_rng.randf_range(-.2,.2))
	var flat=Vector3(direction.x,0,direction.z).normalized().rotated(Vector3.UP,fx_rng.randf_range(-.9,.9))
	var velocity=flat*fx_rng.randf_range(.9,1.6)+Vector3.UP*fx_rng.randf_range(.8,1.4)
	var spin=Vector3(fx_rng.randf_range(-14,14),fx_rng.randf_range(-10,10),fx_rng.randf_range(-14,14))
	var life=fx_rng.randf_range(.5,.7)
	piece.global_position=start
	var tween=piece.create_tween()
	tween.tween_method(func(t:float):
		piece.global_position=start+velocity*t+Vector3.DOWN*4.9*t*t
		piece.rotation=spin*t
		mat.albedo_color.a=clampf((life-t)/.18,0,1),0.0,life,life)
	tween.tween_callback(func():twigs_alive-=1;piece.queue_free())
