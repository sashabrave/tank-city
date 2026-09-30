extends RunEffect
## Смена позиции: leaving a vehicle gives +25% speed for 3 s, cooldown 8 s.
func on_vehicle_exit(_data:Dictionary):
	if arena.run.elapsed<arena.run.dash_ready_at:return
	arena.run.dash_until=arena.run.elapsed+3;arena.run.dash_ready_at=arena.run.elapsed+8
	arena.toast("Смена позиции · рывок 3 с")
func modify_move_speed(value:float,_data:Dictionary)->float:
	return value*1.25 if arena.run.elapsed<arena.run.dash_until else value
