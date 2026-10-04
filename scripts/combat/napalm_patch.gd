extends Node3D
## Napalm charge (T-114): a burning patch on the floor that sets enemies inside on fire for a few seconds.
## Visual only besides the burn; it never blocks movement.
var arena
var radius:=1.0
var seconds:=3.0
var damage:=1.0
var tick:=0.0
func _ready():
	var disc=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=.02;mesh.radial_segments=24;disc.mesh=mesh
	var mat=StandardMaterial3D.new();mat.albedo_color=Color(1,.42,.1,.55);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.emission_enabled=true;mat.emission=Color("ff6a1a");mat.emission_energy_multiplier=1.4;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override=mat;disc.position.y=.03;disc.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(disc)
	var glow=OmniLight3D.new();glow.light_color=Color("ff8a3d");glow.light_energy=1.2;glow.omni_range=radius+1.0;glow.position.y=.4;add_child(glow)
	var flames=CPUParticles3D.new();add_child(flames);flames.amount=18;flames.lifetime=.6;flames.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;flames.emission_sphere_radius=radius*.8
	flames.direction=Vector3.UP;flames.initial_velocity_min=.6;flames.initial_velocity_max=1.2;flames.gravity=Vector3.ZERO
	var dot=BoxMesh.new();dot.size=Vector3.ONE*.07;var fm=StandardMaterial3D.new();fm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;fm.albedo_color=Color("ffb347");dot.material=fm;flames.mesh=dot
func _physics_process(delta):
	if not is_instance_valid(arena) or arena.phase!="combat":return
	seconds-=delta;tick-=delta
	if seconds<=0:queue_free();return
	if tick>0:return
	tick=.5
	# Practice fields (hub range, rooms) have no enemies: the patch only burns for the look.
	var room=arena.get("room")
	if room==null or not room.get("actors") is Array:return
	for enemy in room.actors:
		if is_instance_valid(enemy) and not enemy.dead and not enemy.player_owned and not enemy.allied and arena.flat_distance(enemy.position,position)<=radius:
			CombatMods.ignite(enemy,damage,arena.run)
