extends Node3D
var arena
var timer=1.35
var damage=3.0
var spent=false
var label: Label3D
var model: Node3D
const FUSE=1.35
## The drone that planted the bomb (T-071): when set, its model moves here and burrows halfway into the ground.
var drone_model:Node3D
const DIG_TIME=.3
func _ready():
	if is_instance_valid(drone_model):dig_in()
	else:
		model=preload("res://scripts/ordnance.gd").drone_bomb(self);model.rotation.y=fposmod(position.x*1.7+position.z*3.1,TAU)
		preload("res://scripts/battle_stage.gd").pop(model,.18)
	label=Visuals.label3d(self,"",Vector3(0,.8,0),Color("ffbd84"),24)
## Burrowing: the wheels spin hard, dust and pebbles fly up, and the drone sinks to about half its height in
## DIG_TIME; a red light on top keeps the fuse readable.
func dig_in():
	var held=drone_model.global_transform
	drone_model.get_parent().remove_child(drone_model);add_child(drone_model);drone_model.global_transform=held
	model=drone_model;model.name="BombModel"
	var height=maxf(.2,Visuals.mesh_bounds(model,Transform3D.IDENTITY).size.y*model.scale.y)
	var tween=create_tween().set_parallel(true)
	tween.tween_property(model,"position:y",model.position.y-height*.5,DIG_TIME).set_ease(Tween.EASE_IN)
	tween.tween_property(model,"rotation:z",model.rotation.z+.12,DIG_TIME*.5).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_property(model,"rotation:z",model.rotation.z,DIG_TIME*.5)
	var spin=0.0
	for wheel in (model.get("wheels") if model.get("wheels")!=null else []):
		if is_instance_valid(wheel):create_tween().tween_property(wheel,"rotation:x",wheel.rotation.x-TAU*3.0,DIG_TIME+.2)
	preload("res://scripts/ordnance.gd").blink(self,Vector3(0,height*.55,0),3.0,.06)
	dirt_spray()
	Game.sound("mine_arm",self)
func dirt_spray():
	for spec in [[Color("b9a27a"),.05,26,2.2],[Color("6d6252"),.035,14,3.2]]:
		var p=CPUParticles3D.new();add_child(p);p.one_shot=true;p.emitting=true;p.amount=int(spec[2]);p.lifetime=.7;p.explosiveness=.7
		p.direction=Vector3.UP;p.spread=55.0;p.initial_velocity_min=spec[3]*.5;p.initial_velocity_max=spec[3];p.gravity=Vector3(0,-9.0,0)
		var cube=BoxMesh.new();cube.size=Vector3.ONE*float(spec[1]);p.mesh=cube
		var mat=StandardMaterial3D.new();mat.albedo_color=spec[0];mat.roughness=1.0;cube.material=mat
		get_tree().create_timer(1.2).timeout.connect(p.queue_free)
	if is_instance_valid(arena):arena.burst(position+Vector3.UP*.15,Color("cdb894"),.45)
func _physics_process(delta):
	if spent or arena.phase!="combat":return
	timer-=delta
	Texts.set_text(label,"%.1f" % maxf(0,timer))
	# The red light blinks faster as the fuse runs out.
	var light=get_node_or_null("Blink") if has_node("Blink") else model.get_node_or_null("Blink") if is_instance_valid(model) else null
	if light:light.blink_rate=lerpf(3.0,16.0,clampf(1.0-timer/FUSE,0,1))
	if timer<=0:detonate()
func detonate():
	if spent:return
	spent=true;arena.bombs.erase(self)
	arena.set_meta("attacker","drone");arena.explosion(position,damage);arena.set_meta("attacker","")
	queue_free()
