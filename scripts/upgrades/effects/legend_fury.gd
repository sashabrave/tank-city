extends RunEffect
## Ярость: every kill gives +5% damage until the end of the field, up to +50%.
var stacks=0
func on_room_start(_data:Dictionary):stacks=0
func on_kill(_data:Dictionary):
	stacks=mini(10,stacks+1)
	if stacks%5==0:arena.toast("Ярость · +%d%%" % (stacks*5))
func modify_shot_damage(value:float,_data:Dictionary)->float:return value*(1.0+stacks*.05)
