class_name AbilityCatalog
extends RefCounted
static var DATA:Dictionary=build()
static func build()->Dictionary:
	var result=Balance.CONFIG.ability_data()
	result["field_repair"]={"name":"Полевой ремонт","price":0,"cooldown":35.0,"power":3.0,"description":"Восстанавливает 3 брони своей машины или 1 HP пешком."}
	result["grenade"].description="Бросок на 5 клеток перед собой. Граната отскакивает от препятствий и взрывается после короткого запала."
	return result
