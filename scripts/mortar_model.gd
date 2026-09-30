extends "res://scripts/kit_model.gd"
## Mortar emplacement (tools/build_mortar_v6.py). States are read from the actor, nothing is scripted by
## the combat systems except lob():
##   idle      — the table scans slowly, the tube breathes;
##   warning   — last second before a shot: tube lifts, the lamp blinks faster and faster, the nest crouches;
##   fire      — tube kicks back, the whole piece squashes and pops, a puff leaves the muzzle;
##   reload    — tube dips to take a round and comes back up;
##   hit       — short wobble;  death — the tube topples, the lamp goes dark.
const REST=.95
const WARN=.9
var table_yaw:Node3D
var elev:Node3D
var tube:Node3D
var lamp_mat:StandardMaterial3D
var tube_home:=Vector3.ZERO
var fired_at=-10.0
var hit_at=-10.0
var elevation=REST
var target_yaw=0.0
var has_target=false
var preview_left=-1.0  # galleries: seconds to a pretend shot

func _ready():
	super._ready()
	table_yaw=find_child("mortar_yaw",true,false);elev=find_child("mortar_elev",true,false);tube=find_child("mortar_tube",true,false)
	yaws.erase(table_yaw)  # turned here, with its own scan and lob logic
	if tube:tube_home=tube.position
	var lamp:MeshInstance3D=find_child("mortar_lamp",true,false)
	if lamp:
		lamp_mat=StandardMaterial3D.new();lamp_mat.albedo_color=Color("5a1c18");lamp_mat.emission_enabled=true;lamp_mat.emission=Color("ff3a26");lamp_mat.emission_energy_multiplier=0
		lamp.material_override=lamp_mat
	if elev:elev.rotation.x=REST
	clock=fmod(absf(float(hash(get_instance_id()))),7000.0)/1000.0  # visual phase only

func muzzle_point()->Vector3:
	return tube.global_transform*Vector3(0,0,-.36) if tube else global_position+Vector3.UP*.9

## Called when a round leaves: face the target, kick.
func lob(target:Vector3):
	var d=target-global_position
	target_yaw=wrapf(atan2(-d.x,-d.z)-global_rotation.y,-PI,PI);has_target=true
	fired_at=clock;recoil=1.0
	if table_yaw:table_yaw.rotation.y=rotate_toward(table_yaw.rotation.y,target_yaw,.6)
	puff()

func kick():
	fired_at=clock;recoil=1.0

func flinch():
	hit_at=clock

func has_death()->bool:return elev!=null
func play_death()->bool:
	dying=true
	if lamp_mat:lamp_mat.emission_energy_multiplier=0;lamp_mat.albedo_color=Color("2a1a18")
	var tween=create_tween().set_parallel()
	if elev:tween.tween_property(elev,"rotation:x",-.25,.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if table_yaw:tween.tween_property(table_yaw,"rotation:z",.28,.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if tube:tween.tween_property(tube,"position:z",tube_home.z+.08,.3)
	return true

## Seconds left before the next shot, or -1 outside combat (galleries, previews).
func until_shot()->float:
	var actor=get_parent()
	if actor is CombatActor and is_instance_valid(actor.arena) and actor.arena.phase=="combat":return actor.fire_cooldown
	return preview_left

func _process(delta):
	if dying:return
	var actor=get_parent()
	if actor is CombatActor:
		if actor.dead:return
		if is_instance_valid(actor.arena):
			if actor.arena.phase not in ["combat","countdown"]:return
			if not actor.player_owned and not actor.allied and (actor.stun_time>0 or actor.arena.freeze_time>0):return
	clock+=delta
	var left=until_shot()
	var warning=left>0 and left<WARN
	var since=clock-fired_at
	# Elevation: breathe at rest, lift before the shot, dip to reload after it.
	var goal=REST+.03*sin(clock*1.7)
	if warning:goal=REST+.22*(1.0-left/WARN)
	if since<.9:goal=REST-.4*sin(clampf((since-.15)/.75,0,1)*PI)
	if elev:elev.rotation.x=lerpf(elev.rotation.x,goal,minf(1,delta*(14 if warning else 7)))
	# Traverse: face the last target, otherwise a slow lazy scan.
	if table_yaw:
		var aim_to=target_yaw if has_target else .35*sin(clock*.45)
		table_yaw.rotation.y=rotate_toward(table_yaw.rotation.y,aim_to,delta*(2.4 if has_target else .5))
		var wobble=.09*sin((clock-hit_at)*38)*maxf(0,1-(clock-hit_at)/.3) if clock-hit_at<.3 else 0.0
		table_yaw.rotation.z=wobble
	# Squash: crouch while warning, pop on the shot, settle back.
	recoil=maxf(0,recoil-delta*4.5)
	var squash=(-.06*(1.0-left/WARN) if warning else 0.0)+(.08*recoil*sin(recoil*PI) if recoil>0 else 0.0)
	scale=Vector3(1-squash*.5,1+squash,1-squash*.5)
	if tube:tube.position=tube_home+Vector3(0,0,recoil*recoil*.07)
	# Lamp: slow idle pulse, fast blink in the last second.
	if lamp_mat:
		var on=fmod(clock,2.4)<.12 if not warning else fmod(clock,lerpf(.3,.08,1.0-left/WARN))<.05
		lamp_mat.emission_energy_multiplier=5.0 if on else .3
		lamp_mat.albedo_color=Color("ff4a3a") if on else Color("5a1c18")

## Short smoke ring at the muzzle (visual only, no randomness).
func puff():
	if not tube:return
	var ring=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=.09;mesh.height=.12;mesh.radial_segments=10;mesh.rings=4;ring.mesh=mesh
	var mat=StandardMaterial3D.new();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=Color(.93,.9,.84,.75);ring.material_override=mat;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var root=get_tree().current_scene if get_tree() else null
	if root==null:return
	root.add_child(ring)
	var muzzle=muzzle_point()
	ring.global_position=muzzle
	var tween=ring.create_tween().set_parallel()
	tween.tween_property(ring,"scale",Vector3.ONE*2.4,.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(ring,"global_position",muzzle+Vector3.UP*.35,.45).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat,"albedo_color:a",0.0,.45)
	tween.chain().tween_callback(ring.queue_free)
