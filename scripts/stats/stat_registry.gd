class_name StatRegistry
extends RefCounted
## All characteristics from assets/balance/stats. Station levels live in Game.stat_levels (or a legacy
## profile field named by StatDef.meta_field) and are added to the run when it starts.
const DIR="res://assets/balance/stats"
static var _defs:Dictionary={}
static func _load():
	if not _defs.is_empty():return
	var files=Array(ResourceLoader.list_directory(DIR));files.sort()
	for file in files:
		file=file.trim_suffix(".remap")
		if not (file.ends_with(".tres") or file.ends_with(".res")):continue
		var def=load(DIR.path_join(file))
		if def is StatDef and def.id!="":_defs[def.id]=def
		else:push_error("Invalid stat definition: "+file)
static func all()->Array:
	_load();var list=_defs.values()
	list.sort_custom(func(a,b):return [RunUpgrades.FAMILIES.keys().find(a.family),a.order]<[RunUpgrades.FAMILIES.keys().find(b.family),b.order])
	return list
static func has(id:String)->bool:_load();return _defs.has(id)
static func get_def(id:String)->StatDef:_load();return _defs.get(id)
static func family(key:String)->Array:return all().filter(func(def):return def.family==key)
static func run_fields()->Array:return all().filter(func(def):return def.run_field!="").map(func(def):return def.run_field)
## Station level of a stat.
static func level(id:String)->int:
	var def=get_def(id)
	if def==null:return 0
	if def.meta_field!="":return int(Game.get(def.meta_field))
	return int(Game.stat_levels.get(id,0))
static func cost(id:String)->int:
	var def=get_def(id);return Game.nice_price(def.cost_base+def.cost_step*level(id))
static func unlocked(id:String)->bool:
	var def=get_def(id)
	return def!=null and (def.requires=="" or level(def.requires)>=def.requires_level)
static func can_buy(id:String)->bool:
	var def=get_def(id)
	return def!=null and def.step>0 and def.meta_field=="" and unlocked(id) and level(id)<def.max_level and Game.credits>=cost(id)
static func buy(id:String)->bool:
	if not can_buy(id):return false
	Game.credits-=cost(id);Game.stat_levels[id]=level(id)+1;Game.save_progress();return true
## Value a run starts with: RunState default plus station levels.
static func base_value(def:StatDef)->float:
	var defaults=preload("res://scripts/state/run_state.gd").new()
	return float(defaults.get(def.run_field))+(def.step*level(def.id) if def.meta_field=="" else 0.0)
static func apply_meta(run):
	for def in all():
		if def.run_field=="" or def.meta_field!="" or def.step<=0:continue
		var value=float(run.get(def.run_field))+def.step*level(def.id)
		run.set(def.run_field,int(round(value)) if typeof(run.get(def.run_field))==TYPE_INT else value)
## Current value: from the running arena when there is one, otherwise what a run would start with.
static func value(def:StatDef,arena=null)->float:
	if arena!=null and arena.run!=null:
		if def.id=="crit_chance":return CombatMods.crit_chance(arena)
		if def.id=="luck":return float(CombatMods.luck(arena))
		return float(arena.run.get(def.run_field))
	if def.id=="luck":return float(Game.luck_level)
	return base_value(def)
static func text(def:StatDef,amount:float)->String:
	match def.format:
		"percent":return "%d%%" % roundi(amount*100)
		"multiplier":return "×"+UiKit.number(amount)
		"integer":return str(roundi(amount))
	return UiKit.number(amount)
