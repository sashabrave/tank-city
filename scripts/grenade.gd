extends Node3D
var arena
var friendly=false
var damage=1.0
var blast_radius=0.0
var target=Vector3.ZERO
var velocity=Vector3.ZERO
var gravity=9.8
var flight_time=2.0
var elapsed=0.0
var fuse=0.0
var marker: Node3D
var spent=false
var landed_audio=false
var motion
func _ready():
	if friendly:
		motion=preload("res://scripts/grenade_motion.gd").new(position,target,flight_time,func(probe):
			var cell=arena.grid_pos(probe)
			return not arena.inside(cell) or (probe.y < 1.15 and (arena.walls.has(cell) or cell==arena.base_cell)))
	velocity=(target-position)/flight_time+Vector3.UP*(gravity*flight_time*.5)
	GrenadeVisual.projectile(self,friendly)
	marker=GrenadeVisual.marker(arena,target,blast_radius if blast_radius>0 else 1.15,friendly)
	marker.visible=not friendly
func _physics_process(delta):
	if spent or not is_instance_valid(arena) or arena.phase not in ["combat","countdown"]:return
	if friendly:
		motion.advance(delta);position=motion.position;elapsed+=delta
		if motion.landed and not landed_audio:Game.sound("grenade_land",self);landed_audio=true
		target=Vector3(position.x,0,position.z)
		marker.visible=motion.landed
		marker.position=target+Vector3.UP*.06
		if elapsed>=flight_time+fuse:arena.grenade_explosion(target,damage,friendly,blast_radius);consume()
		return
	var step=minf(delta,flight_time-elapsed)
	position+=velocity*step+Vector3.DOWN*(gravity*step*step*.5)
	velocity.y-=gravity*step;elapsed+=step
	if elapsed>=flight_time:
		if not landed_audio:Game.sound("grenade_land",self);landed_audio=true
		position=target
		fuse-=maxf(0,delta-step)
		if fuse<=0:arena.grenade_explosion(target,damage,friendly,blast_radius);consume()
func consume():
	if spent:return
	spent=true
	if is_instance_valid(marker):marker.queue_free()
	if is_instance_valid(arena):arena.grenades.erase(self)
	queue_free()

func _exit_tree():
	if is_instance_valid(marker):marker.queue_free()
