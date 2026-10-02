extends RunEffect
## Мастерская на колёсах: the hero's vehicle repairs 1 armour every 3 s.
var clock=0.0
func on_tick(data:Dictionary):
	var vehicle=arena.room.player
	if not is_instance_valid(vehicle) or vehicle.kind=="soldier" or vehicle.hp>=vehicle.max_hp:clock=0.0;return
	clock+=float(data.get("delta",0.0))
	if clock<3.0:return
	clock=0.0;vehicle.hp=minf(vehicle.max_hp,vehicle.hp+1.0);vehicle.refresh_health()
	arena.burst(vehicle.position+Vector3.UP*.7,Color("8fe895"),.3)
