extends RunEffect
## Второе дыхание: once per field a lethal hit leaves the soldier at 1 HP with 2 s of invulnerability.
var used=false
func on_room_start(_data:Dictionary):used=false
func modify_second_wind(value:float,_data:Dictionary)->float:
	if used:return value
	used=true;return 1.0
