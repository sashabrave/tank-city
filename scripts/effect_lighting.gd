class_name EffectLighting
extends RefCounted
static var materials:Dictionary={}
static func glow(color:Color,soft=false,projectile=false)->StandardMaterial3D:
	var key=str(color)+str(soft)+str(projectile)
	if not materials.has(key):
		var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled=true;mat.emission=color;mat.emission_energy_multiplier=1.8
		if soft:mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;mat.albedo_color.a=.12;mat.no_depth_test=false
		if projectile:
			mat.set_meta("projectile_halo",soft);mat.set_meta("projectile_core",not soft)
			var factor=.7 if Settings.values.world_lighting=="night" else .2
			if soft:mat.albedo_color.a=.12*factor
			else:mat.emission_energy_multiplier=1.8*factor
		materials[key]=mat
	return materials[key]
static func tracer(parent:Node3D,color:Color,size:Vector3):
	var core=Visuals.box(parent,Vector3.ZERO,size,color);core.material_override=glow(color,false,true);core.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo=Visuals.box(parent,Vector3.ZERO,size*Vector3(2.2,2.2,1.1),color);halo.material_override=glow(color,true,true);halo.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return core
static func projectile_light(parent:Node3D,color:Color):
	# Independent of the scenery budget: at most two tiny moving light pools.
	if Settings.values.world_lighting!="night" or parent.get_tree().get_nodes_in_group("projectile_lights").size()>=2:return
	var light=OmniLight3D.new();light.add_to_group("projectile_lights");light.light_color=color;light.light_energy=.55;light.omni_range=1.15;light.shadow_enabled=false;parent.add_child(light)
static func pickup(parent:Node3D,color:Color):
	var pool=OmniLight3D.new();pool.name="PickupGlow";parent.add_child(pool);pool.position.y=.15;pool.omni_range=1.5;pool.light_color=color;pool.shadow_enabled=false;pool.light_volumetric_fog_energy=0.0
	pool.add_to_group("pickup_lights")

	var ring=Visuals.ring(parent,color,.30);ring.position.y=-.4;ring.material_override=glow(color)
	for node in parent.find_children("*","MeshInstance3D",true,false):
		if node==ring:continue
		for i in range(node.mesh.get_surface_count()):
			var source=node.get_active_material(i)
			if source is StandardMaterial3D:
				var mat=source.duplicate();mat.emission_enabled=true;mat.emission=mat.albedo_color;mat.emission_texture=mat.albedo_texture;mat.emission_energy_multiplier=1.35;node.set_surface_override_material(i,mat)

static func refresh_projectile_halos():
	var factor=.7 if Settings.values.world_lighting=="night" else .2
	for mat in materials.values():
		if mat.get_meta("projectile_halo",false):mat.albedo_color.a=.12*factor
		if mat.get_meta("projectile_core",false):mat.emission_energy_multiplier=1.8*factor
