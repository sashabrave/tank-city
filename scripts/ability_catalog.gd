class_name AbilityCatalog
extends RefCounted
static var DATA:Dictionary=build()
static func build()->Dictionary:
	var result=Balance.CONFIG.ability_data()
	result["field_repair"]={"name":"Полевой ремонт","price":0,"cooldown":35.0,"power":3.0,"description":"Восстанавливает 3 брони своей машины или 1 HP пешком."}
	result["grenade"].description="Бросок на 5 клеток перед собой. Граната отскакивает от препятствий и взрывается после короткого запала."
	# Sandbox tuning saved by the author (Песочница → Класс): cooldown/power on top of the balance resources.
	var tuned=read_json(OVERRIDES)
	for id in tuned:
		if result.has(id):
			for key in ["cooldown","power"]:
				if tuned[id].has(key):result[id][key]=float(tuned[id][key])
	return result

## Sandbox tuning (author, 2026-10-03): sliders change DATA live; «Сохранить» keeps the values (user file, and
## the balance .tres when running from the project), «Сбросить» returns the original values of DEFAULTS.
const OVERRIDES:="user://ability_tuning.json"
const DEFAULTS:="res://data/ability_defaults.json"
const TUNABLE:=["cooldown","power"]
## Tests switch writing off: tuning then changes only the live values, never files or resources.
static var write_enabled:=true
static func read_json(path:String)->Dictionary:
	if not FileAccess.file_exists(path):return {}
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
static func default_value(id:String,key:String)->float:
	return float(read_json(DEFAULTS).get(id,{}).get(key,DATA.get(id,{}).get(key,1.0)))
static func tune(id:String,key:String,value:float):
	if DATA.has(id):DATA[id][key]=value
static func save_tuning(id:String)->bool:
	if not write_enabled:return true
	var all=read_json(OVERRIDES);all[id]={}
	for key in TUNABLE:all[id][key]=float(DATA[id][key])
	var file=FileAccess.open(OVERRIDES,FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(all,"\t"));file.close()
	write_resource(id);return true
static func reset_tuning(id:String):
	for key in TUNABLE:tune(id,key,default_value(id,key))
	if not write_enabled:return
	var all=read_json(OVERRIDES);all.erase(id)
	var file=FileAccess.open(OVERRIDES,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(all,"\t"));file.close()
	write_resource(id)
## From the project (not an exported build) the balance resource itself is updated, so the change reaches git.
static func write_resource(id:String):
	if OS.has_feature("template"):return
	for entry in Balance.CONFIG.abilities:
		if entry.id==id:
			entry.cooldown=float(DATA[id].cooldown);entry.power=float(DATA[id].power)
			if entry.resource_path!="":ResourceSaver.save(entry,entry.resource_path)
