extends RunEffect
## Последний рубеж (Стрелок, class path level 20): at 25% health or less every shot crits — on foot by the
## soldier's health, in a vehicle by its armour (the same threshold as the run card of that name).
func modify_sure_crit(value:float,data:Dictionary)->float:
	var shooter=data.get("shooter")
	if shooter==null or not is_instance_valid(shooter) or arena.run==null:return value
	var in_vehicle=shooter.kind in GarageCatalog.VEHICLES
	var ratio=(shooter.hp/maxf(1.0,shooter.max_hp)) if in_vehicle else (arena.run.soldier_hp/maxf(1.0,float(arena.run.soldier_max_hp)))
	return 1.0 if ratio<=.25 else value
