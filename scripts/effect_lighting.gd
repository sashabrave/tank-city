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
	var light=OmniLight3D.new();light.name="ProjectileLight";light.add_to_group("projectile_lights");light.light_color=color;light.light_energy=.55;light.omni_range=1.15;light.shadow_enabled=false;parent.add_child(light)
static func pickup(parent:Node3D,color:Color):
	var pool=OmniLight3D.new();pool.name="PickupGlow";parent.add_child(pool);pool.position.y=.15;pool.omni_range=1.5;pool.light_color=color;pool.shadow_enabled=false;pool.light_volumetric_fog_energy=0.0
	pool.add_to_group("pickup_lights")

	var ring=Visuals.ring(parent,color.lightened(.15),.30);ring.position.y=-.4
	# Soft dark contact disc: the bonus reads against any floor without glowing harder.
	var disc=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=.3;mesh.bottom_radius=.3;mesh.height=.004;mesh.radial_segments=20;disc.mesh=mesh
	var shade=StandardMaterial3D.new();shade.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;shade.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;shade.albedo_color=Color(0,0,0,.28)
	disc.material_override=shade;disc.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(disc);disc.position.y=-.52
	for node in parent.find_children("*","MeshInstance3D",true,false):
		if node==ring or node==disc:continue
		for i in range(node.mesh.get_surface_count()):
			var source=node.get_active_material(i)
			if source is StandardMaterial3D:
				var mat=source.duplicate();mat.emission_enabled=true;mat.emission=mat.albedo_color;mat.emission_texture=mat.albedo_texture;mat.emission_energy_multiplier=.4;node.set_surface_override_material(i,mat)

static func refresh_projectile_halos():
	var factor=.7 if Settings.values.world_lighting=="night" else .2
	for mat in trail_materials.values():mat.set_shader_parameter("energy",trail_energy())
	for mat in materials.values():
		if mat.get_meta("projectile_halo",false):mat.albedo_color.a=.12*factor
		if mat.get_meta("projectile_core",false):mat.emission_energy_multiplier=1.8*factor

static var laser_materials:={}
## Animated sight/telegraph line: pulses travel along the box's local Z.
static func laser(color:Color,halo:bool)->ShaderMaterial:
	var key=[color.to_html(),halo]
	if not laser_materials.has(key):
		var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/fx/laser.gdshader")
		mat.set_shader_parameter("color",color);mat.set_shader_parameter("halo",1.0 if halo else 0.0)
		laser_materials[key]=mat
	return laser_materials[key]

## One projectile family: round glowing core, soft halo, fading trail.
## Size and trail length follow the weapon class; colour follows the side.
const PROJECTILES={
	"bullet":{"core":Vector3(.08,.08,.2),"trail":.55,"width":.06},
	"shell":{"core":Vector3(.13,.13,.26),"trail":1.0,"width":.1},
	"sniper":{"core":Vector3(.05,.05,.3),"trail":1.8,"width":.04},
	"rocket":{"core":Vector3(.1,.1,.14),"trail":.85,"width":.1},
	"orb":{"core":Vector3(.3,.3,.3),"trail":.45,"width":.2},
}
static var trail_materials:={}
static var projectile_sphere:SphereMesh
static var projectile_box:BoxMesh
static func trail_energy()->float:return 1.0 if Settings.values.world_lighting=="night" else .75
## Warm inverted-hull rim around the player's rounds (T-177): pale tracers vanished on light day maps. A deep
## amber edge, not black (author, 2026-10-03: the black outline looked wrong) — it reads as a hot rim.
static var rim_material:StandardMaterial3D
static var rim_outlines:=true
static func projectile_rim()->StandardMaterial3D:
	if rim_material==null:
		rim_material=StandardMaterial3D.new();rim_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;rim_material.cull_mode=BaseMaterial3D.CULL_FRONT
		rim_material.albedo_color=Color(.86,.36,.05)
	return rim_material
static func projectile_visual(parent:Node3D,kind:String,color:Color,rim:=false)->Node3D:
	var spec:Dictionary=PROJECTILES.get(kind,PROJECTILES.bullet)
	if projectile_sphere==null:projectile_sphere=SphereMesh.new();projectile_sphere.radius=.5;projectile_sphere.height=1.0;projectile_sphere.radial_segments=10;projectile_sphere.rings=5
	var root=Node3D.new();root.name="ProjectileVisual";parent.add_child(root)
	var core=MeshInstance3D.new();core.mesh=projectile_sphere;core.scale=spec.core;core.material_override=glow(color.lightened(.25),false,true)
	var halo=MeshInstance3D.new();halo.mesh=projectile_sphere;halo.scale=spec.core*Vector3(2.4,2.4,1.6);halo.material_override=glow(color,true,true)
	var key=[color.to_html(),kind=="rocket"]
	if not trail_materials.has(key):
		var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/fx/tracer.gdshader")
		mat.set_shader_parameter("color",color);mat.set_shader_parameter("flicker",1.0 if kind=="rocket" else 0.0);mat.set_shader_parameter("energy",trail_energy())
		trail_materials[key]=mat
	# One shared unit box for every trail (scaled per node): a new mesh per round was built on every shot.
	if projectile_box==null:projectile_box=BoxMesh.new();projectile_box.size=Vector3.ONE
	var trail=MeshInstance3D.new();trail.mesh=projectile_box
	trail.scale=Vector3(spec.width,spec.width*.6,spec.trail);trail.position.z=spec.trail*.5;trail.material_override=trail_materials[key]
	for node in [trail,halo,core]:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(node)
	if rim and rim_outlines:
		var outline=MeshInstance3D.new();outline.name="Rim";outline.mesh=projectile_sphere;outline.scale=spec.core*Vector3(1.7,1.7,1.35);outline.material_override=projectile_rim()
		outline.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(outline)
	if kind=="rocket":
		# Light rocket body ahead of the flame core.
		# Finned RPG body ahead of the exhaust flame.
		preload("res://scripts/ordnance.gd").rocket(root,color.g>.6)
	return root
