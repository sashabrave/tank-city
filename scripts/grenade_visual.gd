class_name GrenadeVisual
extends RefCounted
static func projectile(parent:Node3D,friendly:bool,source:=""):
	# Mortars and the allied turret lob finned rounds; everyone else throws a hand grenade.
	if source=="mortar":preload("res://scripts/ordnance.gd").mortar_round(parent,friendly)
	else:preload("res://scripts/ordnance.gd").grenade(parent,friendly)
static func marker(parent:Node3D,target:Vector3,radius:float,friendly:bool)->Node3D:
	var ring=Visuals.ring(parent,Color("e5b455") if friendly else Color("d5573c"),radius,0.0 if friendly else 1.0)
	ring.name="GrenadeRadius";ring.position=target+Vector3.UP*.06
	ring.set_meta("blast_radius",radius)
	return ring
static func explode(parent:Node3D,target:Vector3,radius:float,friendly:bool):
	preload("res://scripts/combat_effect.gd").spawn(parent,target+Vector3.UP*.2,Color("efae55") if friendly else Color("e78331"),minf(radius,1.6))
	var wave=marker(parent,target,radius,friendly);wave.name="GrenadeShockwave";wave.scale=Vector3.ONE*.15
	var tween=parent.create_tween()
	tween.tween_property(wave,"scale",Vector3.ONE,.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(.1);tween.tween_property(wave,"scale",Vector3.ONE*1.04,.12)
	tween.tween_callback(wave.queue_free)
