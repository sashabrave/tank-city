extends RunEffect
## Таран: the hero's vehicle crushes enemy infantry it drives into.
func on_tick(_data:Dictionary):
	var vehicle=arena.room.player
	if not is_instance_valid(vehicle) or vehicle.kind=="soldier" or not vehicle.moving:return
	for other in arena.room.actors.duplicate():
		if is_instance_valid(other) and not other.dead and not other.player_owned and not other.allied and UnitKinds.is_infantry(other.kind) and arena.flat_distance(other.position,vehicle.position)<.55*vehicle.footprint+.25:
			other.take_damage(other.max_hp*3,Vector3.ZERO,vehicle.kind,"")
			arena.burst(other.position+Vector3.UP*.2,Color("8a7a66"),.5);Game.sound("hit_body",arena)
