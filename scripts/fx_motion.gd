extends Node3D
## Tiny visual motion for props and ordnance: blinking lights, tumbling, facing the flight direction.
## Blink rate can be driven by the owner (a bomb blinks faster as its timer runs out).
var blink_rate=0.0
var spin=Vector3.ZERO
var align_to_velocity=false
var clock=0.0
var last=Vector3.INF

func _process(delta):
	clock+=delta
	if blink_rate>0:visible=fposmod(clock*blink_rate,1.0)<.55
	if spin!=Vector3.ZERO:rotation+=spin*delta
	if align_to_velocity:
		var now=global_position
		if last!=Vector3.INF and now.distance_to(last)>.0005:
			var dir=(now-last).normalized()
			# Local +Y is the nose.
			var axis=Vector3.UP.cross(dir)
			if axis.length()>.0001:global_basis=Basis(axis.normalized(),Vector3.UP.angle_to(dir))
			else:global_basis=Basis.IDENTITY if dir.y>0 else Basis(Vector3.RIGHT,PI)
		last=now
