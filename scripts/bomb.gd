extends Node3D
var arena
var timer=1.35
var damage=3.0
var spent=false
var label: Label3D
var model: Node3D
const FUSE=1.35
func _ready():
	model=preload("res://scripts/ordnance.gd").drone_bomb(self);model.rotation.y=fposmod(position.x*1.7+position.z*3.1,TAU)
	preload("res://scripts/battle_stage.gd").pop(model,.18)
	label=Visuals.label3d(self,"",Vector3(0,.8,0),Color("ffbd84"),24)
func _physics_process(delta):
	if spent or arena.phase!="combat":return
	timer-=delta
	Texts.set_text(label,"%.1f" % maxf(0,timer))
	# The red light blinks faster as the fuse runs out.
	var light=model.get_node_or_null("Blink") if is_instance_valid(model) else null
	if light:light.blink_rate=lerpf(3.0,16.0,clampf(1.0-timer/FUSE,0,1))
	if timer<=0:detonate()
func detonate():
	if spent:return
	spent=true;arena.bombs.erase(self)
	arena.explosion(position,damage)
	queue_free()
