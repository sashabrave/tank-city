extends RefCounted
## Event bus of one run. Gameplay code emits events and queries modifiers; active card effects answer.
## Active effects follow run.behavior_cards, so checkpoints and tests only need that list.
## Events: shot, kill, player_damaged, vehicle_enter, vehicle_exit, wave_start, room_start.
## Modifiers: shot_damage, fire_rate, move_speed.
var arena
var instances:Dictionary={}
func _init(context):
	arena=context
func active()->Array:
	var result=[]
	for id in arena.run.behavior_cards:
		if not instances.has(id):
			var def=UpgradeRegistry.get_def(id)
			if def==null or def.effect==null:continue
			var effect=def.effect.new();effect.arena=arena;effect.id=id;instances[id]=effect
		result.append(instances[id])
	return result
func emit(event:String,data:Dictionary={}):
	var method="on_"+event
	for effect in active():
		if effect.has_method(method):effect.call(method,data)
func modify(key:String,value:float,data:Dictionary={})->float:
	var method="modify_"+key
	for effect in active():
		if effect.has_method(method):value=effect.call(method,value,data)
	return value
