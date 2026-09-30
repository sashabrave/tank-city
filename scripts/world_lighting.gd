extends Node
## Only world lighting changes; UI colors and camera geometry are untouched.
var environment:Environment
var sun:DirectionalLight3D
var day_background:Color
var elapsed=0.0
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	Settings.changed.connect(apply)
	apply()
	call_deferred("refresh_materials")
func refresh_materials():
	Visuals.refresh_cozy_materials(get_parent())
func apply():
	var night=Settings.values.get("world_lighting","day")=="night"
	environment.background_color=day_background.darkened(.78) if night else day_background
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR if night else Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color=Color("869fbc") if night else Color.WHITE
	environment.ambient_light_energy=.38 if night else .48
	sun.light_color=Color("9ab7e0") if night else Color("fff0d7")
	sun.light_energy=.28 if night else .95
	var cozy=bool(Settings.values.get("shaders",true))
	var advanced=RenderingServer.get_current_rendering_method()=="forward_plus"
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC if cozy else Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure=1.15 if cozy else 1.0
	environment.ssao_enabled=cozy and advanced
	environment.ssao_radius=.65
	environment.ssao_intensity=1.45
	environment.ssao_detail=.6
	environment.glow_enabled=cozy and advanced
	environment.glow_intensity=.35
	environment.glow_bloom=.02
	environment.volumetric_fog_enabled=cozy and advanced and night
	environment.volumetric_fog_density=.012
	environment.volumetric_fog_length=48.0
	environment.volumetric_fog_albedo=Color("a7b9d0")
	environment.volumetric_fog_ambient_inject=.15
	sun.light_angular_distance=1.5 if cozy else 0.0
	if cozy:
		sun.rotation_degrees=Vector3(-42,-32,0)
		sun.light_color=Color("9ab7e0") if night else Color("ffdbad")
		environment.ambient_light_energy=.32 if night else .55
	else:sun.rotation_degrees=Vector3(-55,-32,0)
	refresh_materials()
	update_lamps()
func _process(delta):
	elapsed+=delta
	if elapsed<.25:return
	elapsed=0.0;update_lamps()
func update_lamps():
	var night=Settings.values.get("world_lighting","day")=="night"
	var camera=get_viewport().get_camera_3d()
	var lamps=get_tree().get_nodes_in_group("night_lamps").filter(func(n):return get_parent().is_ancestor_of(n))
	if camera:
		lamps.sort_custom(func(a,b):
			var ap=int(a.get_meta("priority",0));var bp=int(b.get_meta("priority",0))
			if ap!=bp:return ap>bp
			return a.global_position.distance_squared_to(camera.global_position)<b.global_position.distance_squared_to(camera.global_position))
	var budget=int(Settings.values.light_budget)
	var cozy=bool(Settings.values.get("shaders",true))
	var allocated={};var used=0
	for i in range(lamps.size()):
		var light=lamps[i];light.light_energy=float(light.get_meta("night_energy",1.6)) if night else float(light.get_meta("day_energy",.12))
		var group=light.get_parent().get_instance_id() if light.get_meta("occluded_beam",false) else light.get_instance_id()
		if not allocated.has(group):
			var cost=2 if light.get_meta("occluded_beam",false) else 1
			allocated[group]=used+cost<=budget and light.light_energy>0 and light.get_parent().is_visible_in_tree()
			if allocated[group]:used+=cost
		light.visible=allocated[group]
		# The full-size HQ slightly overlaps its cover tile. A source inside intact
		# cover must not illuminate the far side; each real lamp is checked separately.
		var board=get_parent()
		if light.get_meta("occluded_beam",false) and board.has_method("wall_contacts"):
			var forward=-light.global_basis.z.normalized()
			if not board.wall_contacts(light.global_position,forward,.04).is_empty():light.visible=false
		light.shadow_enabled=light.visible and (light.get_meta("occluded_beam",false) or (cozy and i<3))
		light.light_volumetric_fog_energy=1.5 if cozy else 0.0
		if light is SpotLight3D and not light.get_meta("occluded_beam",false):
			if not light.has_node("SoftCone"):add_cone(light)
			var cone=light.get_node("SoftCone");cone.visible=light.visible
			cone.material_override.set_shader_parameter("density",.012 if night else .0035)
	var pickups=get_tree().get_nodes_in_group("pickup_lights").filter(func(n):return get_parent().is_ancestor_of(n))
	if camera:pickups.sort_custom(func(a,b):return a.global_position.distance_squared_to(camera.global_position)<b.global_position.distance_squared_to(camera.global_position))
	for i in range(pickups.size()):
		pickups[i].visible=cozy and i<4
		pickups[i].light_energy=.85 if night else .4
static func lamp(parent:Node3D,position:Vector3):
	var light=OmniLight3D.new();light.name="NightLamp";parent.add_child(light);light.position=position
	light.light_color=Color("ffcc83");light.light_energy=1.6;light.omni_range=7;light.omni_attenuation=1.3;light.shadow_enabled=false
	light.add_to_group("night_lamps");light.visible=Settings.values.get("world_lighting","day")=="night"

static func beam(parent:Node3D,pos:Vector3,always=false,priority=1)->SpotLight3D:
	var light=SpotLight3D.new();light.name="Headlight";parent.add_child(light);light.position=pos;light.rotation.x=deg_to_rad(-16)
	light.light_color=Color("ffe1ad");light.light_energy=2.1;light.spot_range=3.8;light.spot_angle=31;light.spot_attenuation=1.0;light.shadow_enabled=false
	light.set_meta("day_energy",.65 if always else 0.0);light.set_meta("night_energy",2.1);light.set_meta("priority",priority)
	light.add_to_group("night_lamps");light.visible=always or Settings.values.world_lighting=="night";return light

static func headlights(parent:Node3D,vehicle=false,always=false):
	if parent.has_node("HeadlightRig"):return
	var rig=Node3D.new();rig.name="HeadlightRig";parent.add_child(rig)
	if vehicle:
		var lamps=parent.find_children("Amber headlamp*","MeshInstance3D",true,false)
		if not lamps.is_empty():
			# Authored HQ points +Z; attach to the actual lamp surfaces, including map scale.
			for fixture in lamps:
				var pos=parent.to_local(fixture.global_position)+Vector3(0,0,.025)
				var light=beam(rig,pos,always,5);light.rotation.y=PI
				light.set_meta("occluded_beam",true);light.shadow_enabled=true
		else:
			var body=parent.find_child(str(parent.get("kind"))+"_body",true,false)
			var bounds=AABB(Vector3(-.3,.15,-.45),Vector3(.6,.4,.9))
			if body is MeshInstance3D:
				var transform=body.transform;var ancestor=body.get_parent()
				while ancestor!=parent and ancestor is Node3D:
					transform=ancestor.transform*transform;ancestor=ancestor.get_parent()
				bounds=transform*body.get_aabb()
			for side in [-1,1]:
				var pos=Vector3(bounds.get_center().x+side*bounds.size.x*.34,bounds.position.y+bounds.size.y*.48,bounds.position.z-.025)
				Visuals.box(rig,pos,Vector3(.095,.065,.035),Color("ffe6a8")).material_override=Visuals.material(Color("ffe6a8"),true)
				var light=beam(rig,pos+Vector3(0,0,-.025),always,3)
				light.set_meta("occluded_beam",true);light.shadow_enabled=true
	else:beam(rig,Vector3(.12,.65,-.24),false,4)

static func floodlight(parent:Node3D,pos:Vector3,yaw:float):
	var rig=Node3D.new();rig.name="Floodlight";parent.add_child(rig);rig.position=pos;rig.rotation.y=yaw
	Visuals.box(rig,Vector3(0,.12,0),Vector3(.07,.24,.07),Color("535e54"))
	Visuals.box(rig,Vector3(0,.28,0),Vector3(.30,.18,.17),Color("687366"))
	Visuals.box(rig,Vector3(0,.28,-.09),Vector3(.23,.11,.025),Color("ffe0a0")).material_override=Visuals.material(Color("ffe0a0"),true)
	var light=beam(rig,Vector3(0,.28,-.12),true,1);light.rotation.x=deg_to_rad(-35);light.spot_range=4.5;light.spot_angle=42;light.set_meta("day_energy",.22)

static func field(arena):
	var rng=RandomNumberGenerator.new();rng.seed=arena.run_seed+arena.room_index*3907+711
	var candidates=arena.walls.keys().filter(func(c):return arena.walls[c].hp<0 and not arena.walls[c].has("half_side") and c.y>1 and c.y<arena.grid_size-2)
	# Fixtures sit on existing solid cover; no new collision or pathfinding cells.
	var count=mini(candidates.size(),rng.randi_range(2,4))
	for i in range(count):
		var index=rng.randi_range(0,candidates.size()-1);var cell=candidates.pop_at(index)
		preload("res://scripts/base_surroundings.gd").lamp(arena.walls[cell].node,Vector3(0,1.0,0))
	for i in range(mini(2,candidates.size())):
		var index=rng.randi_range(0,candidates.size()-1);var cell=candidates.pop_at(index)
		floodlight(arena.walls[cell].node,Vector3(0,1.02,0),rng.randf()*TAU)

static func add_cone(light:SpotLight3D):
	var cone=MeshInstance3D.new();cone.name="SoftCone";cone.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh=CylinderMesh.new();mesh.top_radius=.018;mesh.bottom_radius=tan(deg_to_rad(light.spot_angle))*light.spot_range*.68;mesh.height=light.spot_range*.8;mesh.radial_segments=16;mesh.rings=1;mesh.cap_top=false;mesh.cap_bottom=false
	cone.mesh=mesh;cone.rotation.x=PI*.5;cone.position.z=-mesh.height*.5
	var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/world/light_cone.gdshader");cone.material_override=mat;light.add_child(cone)
