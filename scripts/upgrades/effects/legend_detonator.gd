extends RunEffect
## Детонатор: enemies the hero kills burst and hit enemies within 1.2 tiles for 1.5 damage.
func on_kill(data:Dictionary):
	var dead=data.get("actor")
	if dead==null:return
	var at:Vector3=dead.position
	arena.burst(at+Vector3.UP*.3,Color("ff9a4a"),.9);Game.sound("explosion_small",arena)
	for other in arena.room.actors.duplicate():
		if is_instance_valid(other) and other!=dead and not other.dead and not other.player_owned and not other.allied and arena.flat_distance(other.position,at)<1.2:
			other.take_damage(1.5,Vector3.ZERO,"","")
