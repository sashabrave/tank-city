class_name Visuals
extends RefCounted
static var palette_cache: Dictionary = {}
static var brushed_roughness:ImageTexture

const INFANTRY=["soldier","grenadier","shield","sniper","rpg_soldier"]
const VEHICLES=["tank","apc","buggy","drone","flyer","boss"]
## species "dog" swaps infantry for the enemy dogs; vehicles and props ignore it.
static func model(kind: String, parent: Node3D, pos = Vector3.ZERO, species:String="cat") -> Node3D:
	if kind in ["soldier","grenadier","shield","sniper","rpg_soldier","boss","tank","apc","buggy","drone","flyer","mortar"] or kind.begins_with("weapon_"):return kit_model(kind,parent,pos,species)
	var environment_kind="bench_mechanic" if kind=="workbench" else kind
	var environment_path=("res://assets/models/cover_v1/" if kind in ["net","trench"] else "res://assets/models/concrete_v1/" if kind.begins_with("concrete_") else "res://assets/models/biome_props/" if kind.begins_with("biome_") else "res://assets/models/environment_v7/")+environment_kind.trim_prefix("biome_")+".glb"
	var obj = load(environment_path if ResourceLoader.exists(environment_path) else "res://assets/models/" + kind + ".glb").instantiate()
	normalize_materials(obj)
	if ResourceLoader.exists(environment_path):apply_environment_palette(obj,parent,0.0,kind in ["net","trench"])
	parent.add_child(obj)
	obj.position = pos
	if kind=="base":obj.add_child(load("res://scripts/mobile_hq.gd").new())
	if environment_kind.begins_with("bench_"):obj.rotation.y=PI
	return obj

static func kit_model(kind:String,parent:Node3D,pos:Vector3,species:String="cat")->Node3D:
	# The mortar has its own states (warning, lob, reload) on top of the kit wrapper.
	var wrapper=load("res://scripts/mortar_model.gd" if kind=="mortar" else "res://scripts/kit_model.gd").new()
	wrapper.kind=kind
	var dog=species=="dog" and kind in INFANTRY
	if dog:wrapper.species="dog"
	# v6: low-poly chibi cat infantry and weapons (tools/build_infantry_v6.py, build_weapons_v6.py).
	# Vehicles: kit_v4 geometry re-dressed with v6 materials (tools/rematerial_kit_v4.py).
	var family="infantry_v6" if kind in INFANTRY or kind.begins_with("weapon_") else "vehicles_v6" if kind in VEHICLES or kind=="mortar" else "kit_v4"
	var art=load("res://assets/models/"+family+"/"+("dog_" if dog else "")+kind+".glb").instantiate()
	wrapper.add_child(art)
	# One authored cell is .93 units.
	art.scale=Vector3.ONE/.93*model_scale(kind)
	parent.add_child(wrapper);wrapper.position=pos
	if UnitKinds.is_vehicle(kind):preload("res://scripts/world_lighting.gd").headlights(wrapper,true)
	return wrapper

static func model_scale(kind:String)->float:
	# v6 cats are 1.05 authored: .83 keeps the 0.936-cell infantry height.
	if kind in INFANTRY or kind.begins_with("weapon_"):return .83
	return {"apc":1.15,"buggy":1.35,"drone":2.1,"flyer":2.1}.get(kind,1.0)

static func material(color: Color, emission = false) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .9
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = .45
	cozy_material(mat)
	return mat

static func box(parent: Node3D, pos: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = dimensions
	m.mesh = mesh
	m.material_override = material(color)
	parent.add_child(m)
	m.position = pos
	return m

static func label3d(parent: Node3D, text: String, pos: Vector3, color = Color("eff1dc"), font_size = 40) -> Label3D:
	var label = Label3D.new()
	Texts.set_text(label,text)
	label.font_size = font_size
	label.pixel_size = .008
	label.modulate = color
	label.outline_size = 5
	label.outline_modulate = Color("304031")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	label.position = pos
	return label

static func setup_world(parent: Node3D, camera_size: float, target: Vector3) -> Camera3D:
	var world = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("bec3b8")
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("7394b0")
	sky_material.sky_horizon_color = Color("d9dfdd")
	sky_material.ground_bottom_color = Color("44483d")
	sky_material.ground_horizon_color = Color("a1a394")
	var sky = Sky.new()
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = .48
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = env
	parent.add_child(world)
	var sun = DirectionalLight3D.new()
	parent.add_child(sun)
	sun.rotation_degrees = Vector3(-55,-32,0)
	sun.light_color = Color("fff0d7")
	sun.light_energy = .95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 50
	var cam = Camera3D.new()
	parent.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = camera_size
	cam.position = target + Vector3(0,19,14).rotated(Vector3.UP,deg_to_rad(10))
	cam.look_at(target)
	cam.current = true
	var lighting=preload("res://scripts/world_lighting.gd").new();lighting.name="WorldLighting";lighting.environment=env;lighting.sun=sun;lighting.day_background=env.background_color;parent.add_child(lighting)
	var atmosphere=preload("res://scripts/world_atmosphere.gd").new();atmosphere.name="WorldAtmosphere";parent.add_child(atmosphere)
	return cam

static func recolor_enemy(node: Node,rank:int=1):
	if node.has_method("set_paint"):
		node.set_paint("enemy",rank);return
	if node is MeshInstance3D:
		for index in range(node.mesh.get_surface_count()):
			var mat = node.get_active_material(index)
			if mat is StandardMaterial3D:
				var replacement = mat.duplicate()
				var c = mat.albedo_color
				if c.r > c.g * 1.5: replacement.albedo_color = Color("993f30")
				elif c.r > .65: replacement.albedo_color = Color("7b8c88")
				node.set_surface_override_material(index,replacement)
	for child in node.get_children(): recolor_enemy(child)

static var ring_material: ShaderMaterial
static func ring(parent: Node3D, color: Color, radius = .42, urgency := 0.0):
	# Flat quad with a shared shader; colour and animation phase are per instance.
	if ring_material == null:
		ring_material = ShaderMaterial.new();ring_material.shader = preload("res://shaders/fx/ground_ring.gdshader")
	var obj = MeshInstance3D.new()
	var mesh = QuadMesh.new()
	mesh.orientation = PlaneMesh.FACE_Y
	mesh.size = Vector2.ONE*radius*2.3
	obj.mesh = mesh
	obj.material_override = ring_material
	obj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(obj)
	obj.set_instance_shader_parameter("tint",color)
	obj.set_instance_shader_parameter("outer",1.15)
	obj.set_instance_shader_parameter("thickness",clampf(.05/maxf(radius,.05),.02,.2))
	obj.set_instance_shader_parameter("urgency",urgency)
	obj.set_instance_shader_parameter("phase",randf()*TAU)
	obj.position.y = .035
	return obj

static func normalize_materials(node: Node):
	if node is MeshInstance3D:
		for index in range(node.mesh.get_surface_count()):
			var source=node.get_active_material(index)
			if source is StandardMaterial3D:
				var key=source.resource_name
				if not palette_cache.has(key):
					var mat=source.duplicate()
					var hq_colors={"HQ sage armour":"65704f","HQ warm light armour":"aaa995","HQ rubber":"252b27","HQ steel":"465048","HQ amber optics":"d7923b"}
					if hq_colors.has(key):mat.albedo_color=Color(hq_colors[key])
					if key=="TC_Concrete":mat.albedo_color=Color("74796f")
					var environment_colors={"concrete":"939b8d","light":"c4c8b7","olive":"74816b","dark":"364139","steel":"626e62","brick":"b7804d","bag":"b0ac91","orange":"d59948","paper":"dedac2"}
					if key.begins_with("ENV7_"):mat.albedo_color=Color(environment_colors.get(key.trim_prefix("ENV7_"),"939b8d"))
					var colors={"stone":"92958e","ivory":"b9bdb3","orange":"bf772b","dark":"29302c","steel":"59645b","red":"984735"}
					for role in colors:
						if key.begins_with("R13_"+role):mat.albedo_color=Color(colors[role])
					mat.metallic=0.0
					mat.roughness=.78
					if key.begins_with("R13_steel"):
						mat.metallic=1.0
						mat.roughness=.38
					elif key.begins_with("R13_orange") or key.begins_with("R13_red"):
						mat.roughness=.56
					elif key.begins_with("R13_dark"):
						mat.roughness=.88
					elif key.begins_with("R13_stone"):
						mat.roughness=.95
					if source.emission_enabled or key=="HQ amber optics":
						mat.emission_enabled=true;mat.emission_energy_multiplier=1.0
						if key=="HQ amber optics":mat.emission=Color("ffca72")
					cozy_material(mat)
					palette_cache[key]=mat
				node.set_surface_override_material(index,palette_cache[key])
	for child in node.get_children():normalize_materials(child)

static func tiled_floor(parent: Node3D, positions: Array, tint=Color("92958e")):
	parent.set_meta("environment_floor",tint)
	var template=load("res://assets/models/tile.glb").instantiate()
	normalize_materials(template)
	var source=template.find_children("*","MeshInstance3D",true,false)[0]
	var instance=MultiMeshInstance3D.new()
	var multi=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.mesh=source.mesh
	multi.instance_count=positions.size()
	for i in range(positions.size()):
		var trans=source.transform
		trans.origin+=positions[i]
		multi.set_instance_transform(i,trans)
	instance.multimesh=multi
	instance.material_override=material(tint)
	parent.add_child(instance)
	template.free()

static func tint_model(node: Node, tint: Color):
	# Local overrides keep the shared palette and actor colors unchanged.
	var mat=material(tint)
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		mesh.material_override=mat

static func cozy_model(kind:String,parent:Node3D,pos:Vector3)->Node3D:
	var wrapper=load("res://scripts/cozy_model.gd").new()
	var art=load("res://assets/models/cozy/"+kind+".glb").instantiate();wrapper.add_child(art);art.rotation.y=PI
	var bounds=mesh_bounds(art,Transform3D.IDENTITY)
	var target=3.6 if kind=="boss" else (.65 if kind.begins_with("bonus_") else 1.05)
	var factor=target/maxf(bounds.size.x,bounds.size.z)
	if UnitKinds.is_infantry(kind):factor=1.25/bounds.size.y
	if kind.begins_with("weapon_"):factor=.75/maxf(bounds.size.z,.1)
	art.scale*=factor
	art.position=Vector3(-bounds.get_center().x*factor,-bounds.position.y*factor,-bounds.get_center().z*factor)
	parent.add_child(wrapper);wrapper.position=pos
	return wrapper
static func mesh_bounds(node:Node3D,trans:Transform3D)->AABB:
	var total=trans*node.transform;var result=AABB();var first=true
	if node is MeshInstance3D:result=total*node.get_aabb();first=false
	for child in node.get_children():
		if child is Node3D:
			var bound=mesh_bounds(child,total)
			if bound.size==Vector3.ZERO:continue
			result=bound if first else result.merge(bound);first=false
	return result
static func named_part(node:Node,fragment:String):
	for child in node.find_children("*","Node3D",true,false):
		if fragment.to_lower() in str(child.name).to_lower():return child
	return null
static func equip_model(actor_model:Node3D,id:String):
	if actor_model.has_method("equip_weapon"):
		actor_model.equip_weapon(id);return
	var holder=named_part(actor_model,"weapon and hands")
	if holder==null:return
	for child in holder.get_children():
		if "rifle" in str(child.name).to_lower() or child.name=="EquippedWeapon":child.hide();child.queue_free()
	var weapon=load("res://assets/models/cozy/weapon_"+id+".glb").instantiate();holder.add_child(weapon);weapon.name="EquippedWeapon";weapon.position=Vector3(.08,-.04,.35);weapon.scale=Vector3.ONE*.8
	actor_model.gun=weapon;actor_model.gun_home=weapon.position

static func apply_environment_palette(node:Node,context:Node,shade:float=0.0,terrain_cover:bool=false):
	var owner_node=context
	while owner_node and not owner_node.has_meta("environment_floor"):owner_node=owner_node.get_parent()
	var floor_color:Color=owner_node.get_meta("environment_floor") if owner_node else Color("92958e")
	var wall_color:Color=owner_node.get_meta("environment_wall",floor_color) if owner_node else floor_color
	var brick_color:Color=owner_node.get_meta("environment_brick",Color("bf772b")) if owner_node else Color("bf772b")
	var colors={"light":floor_color,"concrete":wall_color.darkened(.26).lerp(Color("5d625a"),.12),  # indestructible blocks must read against the floor
		"brick":brick_color.lerp(floor_color,.12),"bag":Color("b0ac91").lerp(floor_color,.42),"olive":Color("74816b").lerp(floor_color,.4),"steel":floor_color.darkened(.32),"dark":floor_color.darkened(.62),"orange":brick_color,"paper":floor_color.lightened(.12)}
	if terrain_cover:
		colors["bag"]=floor_color.darkened(.12);colors["olive"]=floor_color.darkened(.1)
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for index in range(mesh.mesh.get_surface_count()):
			var source=mesh.mesh.surface_get_material(index)
			if not source is StandardMaterial3D or not source.resource_name.begins_with("ENV7_"):continue
			var mat=source.duplicate()
			mat.albedo_color=colors.get(source.resource_name.trim_prefix("ENV7_"),floor_color).darkened(shade)
			mat.metallic=0;mat.roughness=.9
			cozy_material(mat)
			mesh.set_surface_override_material(index,mat)

static func battle_foundation(parent:Node3D,positions:Array,grid_size:int,tint:Color):
	box(parent,Vector3(0,-1.02,0),Vector3(grid_size,.14,grid_size),tint)
	var mesh=BoxMesh.new();mesh.size=Vector3(1,.82,1)
	var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.mesh=mesh;multi.instance_count=positions.size()
	for i in range(positions.size()):multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,positions[i]+Vector3(0,-.54,0)))
	var instance=MultiMeshInstance3D.new();instance.name="BattleFoundation";instance.multimesh=multi;instance.material_override=material(tint);parent.add_child(instance)

static func cozy_material(mat:StandardMaterial3D):
	if not mat.has_meta("cozy_original"):
		mat.set_meta("cozy_roughness_texture",mat.roughness_texture)
		mat.set_meta("cozy_original",Vector2(mat.metallic,mat.roughness))
	var original:Vector2=mat.get_meta("cozy_original")
	mat.metallic=original.x;mat.roughness=original.y;mat.roughness_texture=mat.get_meta("cozy_roughness_texture") if mat.has_meta("cozy_roughness_texture") else null
	mat.rim_enabled=false;mat.clearcoat_enabled=false
	if not Settings.values.get("shaders",true):return
	var title=mat.resource_name.to_lower()
	var shiny=bool(Settings.values.get("shiny_metal",true))
	if Settings.values.get("rim_light",true) and mat.shading_mode!=BaseMaterial3D.SHADING_MODE_UNSHADED:
		mat.rim_enabled=true;mat.rim=.4;mat.rim_tint=.55
	if "steel" in title or "metal" in title:
		mat.metallic=.92 if shiny else .9;mat.roughness=.3 if shiny else .48;mat.roughness_texture=metal_roughness();mat.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
	elif shiny and ("graphite" in title or "frames" in title):
		# Weapon bodies and frames: blued gunmetal instead of flat plastic.
		mat.metallic=.7;mat.roughness=.4
	elif "rubber" in title or "dark" in title or "graphite" in title:
		mat.roughness=.85
	elif title.begins_with("env7_"):pass
	elif "armor" in title or "armour" in title or "ivory" in title or "olive" in title or "enamel" in title or "sage" in title or "ochre" in title:
		mat.metallic=.1 if shiny else 0.0;mat.roughness=.46 if shiny else .52
		if shiny:mat.clearcoat_enabled=true;mat.clearcoat=.5;mat.clearcoat_roughness=.35
	elif original.x>.8:
		mat.roughness=minf(original.y,.2) if shiny else .35

static func refresh_cozy_materials(root:Node):
	if root is GeometryInstance3D and root.material_override is StandardMaterial3D:cozy_material(root.material_override)
	if root is MeshInstance3D and root.mesh:
		for i in range(root.mesh.get_surface_count()):
			var mat=root.get_active_material(i)
			if mat is StandardMaterial3D:cozy_material(mat)
	for child in root.get_children():refresh_cozy_materials(child)

static func metal_roughness()->ImageTexture:
	if brushed_roughness:return brushed_roughness
	var image=Image.create(128,128,false,Image.FORMAT_L8)
	var rng=RandomNumberGenerator.new();rng.seed=6231
	for y in range(128):
		var line=.66+rng.randf_range(-.08,.08)
		for x in range(128):
			var value=clampf(line+rng.randf_range(-.025,.025),0,1);image.set_pixel(x,y,Color(value,value,value))
	image.generate_mipmaps();brushed_roughness=ImageTexture.create_from_image(image);return brushed_roughness
