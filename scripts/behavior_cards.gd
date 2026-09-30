class_name BehaviorCards
extends RefCounted
## Compatibility view of behaviour cards. Definitions live in assets/balance/upgrades,
## live behaviour in scripts/upgrades/effects via arena.effects.
static var DATA:Dictionary:
	get:
		var result={}
		for id in UpgradeRegistry.ids_with_effect():
			var def=UpgradeRegistry.get_def(id);result[id]={"name":def.title,"text":def.detail}
		return result
static func shot_multiplier(arena)->float:return arena.effects.modify("shot_damage",1.0)
static func rate_multiplier(arena)->float:return arena.effects.modify("fire_rate",1.0)
static func exited_vehicle(arena):arena.effects.emit("vehicle_exit")
static func speed_multiplier(arena)->float:return arena.effects.modify("move_speed",1.0)
