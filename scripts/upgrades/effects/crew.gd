extends RunEffect
## Экипаж: on foot the soldier fires 10% faster (the vehicle damage half lives in CombatMods).
func modify_fire_rate(value:float,_data:Dictionary)->float:return value*1.1
