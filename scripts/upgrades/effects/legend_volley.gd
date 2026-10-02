extends RunEffect
## Залп: the hero's vehicle fires two extra shells in a fan, each for 50% damage.
func on_vehicle_shot(data:Dictionary):
	var vehicle=data.get("actor")
	if vehicle==null:return
	for side in [-1,1]:
		var shell=arena.spawn_bullet(vehicle,vehicle.position,vehicle.facing,vehicle.damage*.5,true)
		if shell==null:continue
		shell.travel_direction=shell.travel_direction.rotated(Vector3.UP,side*.22);shell.rotation.y=atan2(-shell.travel_direction.x,-shell.travel_direction.z)
