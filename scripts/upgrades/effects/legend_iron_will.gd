extends RunEffect
## Стальная воля: for 1 s after each vehicle shot the hero's vehicle takes 70% less damage.
var firing_until=-10.0
func on_vehicle_shot(_data:Dictionary):firing_until=arena.run.elapsed+1.0
func modify_incoming_damage(value:float,data:Dictionary)->float:
	var actor=data.get("actor")
	if actor==null or actor.kind=="soldier" or arena.run.elapsed>firing_until:return value
	return value*.3
