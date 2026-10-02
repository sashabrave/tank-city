extends Node
## Tactile feedback, visual only (own RNG, never the fight's): camera shake via frame offset, a short hit-stop,
## muzzle flashes, ejected casings for the soldier's guns, sparks on armour and dust on infantry.
## Shake and hit-stop follow the «Анимации интерфейса» setting (ui_motion).
const MAX_CASINGS=24
var arena
var rng=RandomNumberGenerator.new()
var trauma=0.0
var stop_left=0.0
var casings:Array=[]
static var meshes:={}
func setup(context):
	arena=context;name="CombatFeel";rng.seed=hash([context.run_seed,"combat_feel"]);process_mode=Node.PROCESS_MODE_ALWAYS
func enabled()->bool:return bool(Settings.values.get("ui_motion",true))
## Trauma-style shake: strength 0..1 adds up, decays fast, offset is trauma² so small hits stay subtle.
func shake(strength:float):
	if enabled():trauma=minf(1.0,trauma+strength)
## Short freeze of the whole fight (Engine.time_scale), measured in real time.
func hit_stop(seconds:float):
	if not enabled() or seconds<=0 or arena.phase!="combat":return
	stop_left=maxf(stop_left,seconds);Engine.time_scale=.05
func _process(delta):
	var real=delta/maxf(.01,Engine.time_scale)
	if stop_left>0:
		stop_left-=real
		if stop_left<=0:Engine.time_scale=1.0
	if trauma>0 and is_instance_valid(arena.camera):
		trauma=maxf(0,trauma-real*1.8)
		var amount=trauma*trauma*.35
		arena.camera.h_offset=rng.randf_range(-1,1)*amount;arena.camera.v_offset=rng.randf_range(-1,1)*amount
		if trauma<=0:arena.camera.h_offset=0;arena.camera.v_offset=0
func _exit_tree():Engine.time_scale=1.0
static func mesh(kind:String)->Array:
	if meshes.has(kind):return meshes[kind]
	var m:Mesh;var mat:StandardMaterial3D
	match kind:
		"flash":m=SphereMesh.new();m.radius=.09;m.height=.18;m.radial_segments=8;m.rings=4;mat=Visuals.material(Color("ffd98a"),true)
		"casing":m=CylinderMesh.new();m.top_radius=.016;m.bottom_radius=.016;m.height=.05;m.radial_segments=6;m.rings=1;mat=Visuals.material(Color("c9a24a"))
	mat.metallic=.6 if kind=="casing" else 0.0
	meshes[kind]=[m,mat];return meshes[kind]
## Bright flash at the muzzle, gone in 0.06 s.
func muzzle(shooter,pos:Vector3,direction:Vector3):
	var data=mesh("flash");var flash=MeshInstance3D.new();flash.mesh=data[0];flash.material_override=data[1];flash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(flash);flash.global_position=pos+direction*.08;flash.scale=Vector3.ONE*(1.6 if shooter!=null and UnitKinds.is_vehicle(shooter.kind) else 1.0)
	var tween=flash.create_tween();tween.tween_property(flash,"scale",Vector3.ZERO,.06);tween.tween_callback(flash.queue_free)
## A brass casing flies out to the right of the gun, bounces once and fades.
func casing(shooter,direction:Vector3):
	if casings.size()>=MAX_CASINGS:
		var oldest=casings.pop_front()
		if is_instance_valid(oldest):oldest.queue_free()
	var data=mesh("casing");var shell=MeshInstance3D.new();shell.mesh=data[0];shell.material_override=data[1];shell.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(shell);casings.append(shell)
	var start=shooter.position+Vector3.UP*.5;shell.global_position=start
	var side=Vector3(-direction.z,0,direction.x).normalized()
	var land=Vector3(start.x,0.02,start.z)+side*rng.randf_range(.3,.55)-direction*rng.randf_range(.0,.15)
	var tween=shell.create_tween()
	tween.tween_property(shell,"global_position",start+side*.2+Vector3.UP*.25,.09).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(shell,"rotation",Vector3(rng.randf()*TAU,rng.randf()*TAU,rng.randf()*TAU),.3)
	tween.tween_property(shell,"global_position",land,.16).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(shell,"global_position",land+side*.06+Vector3.UP*.05,.06)
	tween.tween_property(shell,"global_position",land+side*.09,.06)
	tween.tween_interval(1.4);tween.tween_property(shell,"scale",Vector3.ZERO,.3)
	tween.tween_callback(func():casings.erase(shell);shell.queue_free())
## Hit reaction: sparks on armour, dust on infantry.
func impact(target,pos:Vector3):
	arena.burst(pos+Vector3.UP*.45,Color("ffd27a") if UnitKinds.is_vehicle(target.kind) or target.kind in ["mortar","boss"] else Color("c9b99a"),.18)
