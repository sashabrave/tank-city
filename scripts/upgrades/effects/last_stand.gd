extends RunEffect
## Последний рубеж: infantry fires 25% faster at 25% HP or less.
func modify_fire_rate(value:float,_data:Dictionary)->float:
	var run=arena.run
	return value*1.25 if run.soldier_hp>0 and run.soldier_hp<=run.soldier_max_hp*.25 else value
