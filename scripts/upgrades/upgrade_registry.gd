class_name UpgradeRegistry
extends RefCounted
## All run upgrade cards, loaded from assets/balance/upgrades. Adding a card means adding one .tres file.
const DIR="res://assets/balance/upgrades"
static var _defs:Dictionary={}
static func _load():
	if not _defs.is_empty():return
	var files=Array(ResourceLoader.list_directory(DIR))
	files.sort()
	for file in files:
		# Exported builds list converted resources as *.tres.remap or *.res.
		file=file.trim_suffix(".remap")
		if not (file.ends_with(".tres") or file.ends_with(".res")):continue
		var def=load(DIR.path_join(file))
		if def is UpgradeDef and def.id!="":_defs[def.id]=def
		else:push_error("Invalid upgrade definition: "+file)
static func all()->Array:
	_load();return _defs.values()
static func has(id:String)->bool:
	_load();return _defs.has(id)
static func get_def(id:String)->UpgradeDef:
	_load();return _defs.get(id)
static func ids_with_effect()->Array:
	return all().filter(func(def):return def.effect!=null).map(func(def):return def.id)
