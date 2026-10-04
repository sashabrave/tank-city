extends RefCounted
## Event bus of one run. Gameplay code emits events and queries modifiers; active card effects answer.
## Active effects follow run.behavior_cards, so checkpoints and tests only need that list.
## Events: shot, kill, player_damaged, vehicle_enter, vehicle_exit, wave_start, room_start, enemy_hit
## {target,bullet,damage}, vehicle_shot {actor}, tick {delta} (combat only).
## Modifiers: shot_damage, fire_rate, move_speed, incoming_damage {actor}, second_wind (>0 saves a lethal hit),
## sure_crit {shooter} (>0: the hit always crits).
var arena
var instances:Dictionary={}
var class_key=""
var class_effects:Array=[]
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
	# Class path perks (ClassCatalog.PATHS) are permanent effects of the class, not cards of the run.
	var key="%s:%d" % [Game.selected_class,ClassCatalog.level(Game.selected_class)]
	if key!=class_key:
		class_key=key;class_effects=[]
		for entry in ClassCatalog.perk_effects(Game.selected_class):
			var effect=entry[1].new();effect.arena=arena;effect.id=entry[0];class_effects.append(effect)
	result.append_array(class_effects)
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
