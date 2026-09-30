extends RefCounted
const VERSION=12
const ARRAYS=["duplicate_recipes","notifications","class_first_slots","purchased_gadgets","purchased_hq","class_second_slots","research","built","abilities","branch_unlocks","weapon_unlocks","bonus_unlocks"]
const MAPS=["garage","headquarters","progression","v09","bonus_levels","stat_levels"]
static func validate(data:Dictionary)->Dictionary:
	var version=data.get("version",0)
	if not numeric(version) or int(version)<1:return bad("Нет версии профиля")
	if int(version)>VERSION:return {"ok":false,"future":true,"error":"Профиль создан более новой версией игры"}
	if int(version)>=10:
		for key in ["credits","health","garage","progression","v09","headquarters","class_first_slots","purchased_gadgets","purchased_hq"]:
			if not data.has(key):return bad("Отсутствует раздел: "+key)
	for key in ARRAYS:
		if data.has(key) and not data[key] is Array:return bad("Неверный список: "+key)
	for key in MAPS:
		if data.has(key) and not data[key] is Dictionary:return bad("Неверный раздел: "+key)
	for key in ["credits","health","damage","luck","turret","rarity","base","heal","mobility","recovery","pressure_level","camp_level","backpack_slots","reroll_level"]:
		if data.has(key) and not numeric(data[key]):return bad("Неверное число: "+key)
	for key in ["selected_weapon","selected_ability","gadget"]:
		if data.has(key) and not data[key] is String:return bad("Неверное имя: "+key)
	var specs={"garage":{"arrays":["unlocks","owned"],"maps":["levels"]},"headquarters":{"arrays":["unlocks","modules"],"maps":["levels"]},"v09":{"arrays":["classes","equipped"],"maps":["class_levels","specializations"]},"progression":{"arrays":["accepted","worlds","tracked","completed_orders","recent_sorties","seen","claimed","boss_classes","telegram_options"],"maps":["viewed_updates","sortie_counts","weapons","counters","telegram"]}}
	for section in specs:
		var value=data.get(section,{})
		for key in specs[section].arrays:
			if value.has(key) and not value[key] is Array:return bad(section+"."+key)
		for key in specs[section].maps:
			if value.has(key) and not value[key] is Dictionary:return bad(section+"."+key)
	# Reject nested garbage before any live state is changed.
	for key in ARRAYS:
		if key in ["notifications","duplicate_recipes"]:continue
		for id in data.get(key,[]):
			if not id is String:return bad(key+": неверный идентификатор")
	for section in ["garage","headquarters","v09","progression"]:
		var value=data.get(section,{})
		for key in specs[section].arrays:
			for item in value.get(key,[]):
				if key in ["recent_sorties","telegram_options"]:
					if not item is Dictionary:return bad(key)
				elif key=="worlds":
					if not numeric(item):return bad(key)
				elif not item is String:return bad(key)
		for key in specs[section].maps:
			if key in ["telegram","viewed_updates"]:continue
			for n in value.get(key,{}).values():
				if not numeric(n):return bad(key)
		var numeric_keys={"garage":[],"headquarters":["slots"],"v09":["cores","slots","rescue","shield_capacity"],"progression":["order_wait","order_serial","level","xp","insurance"]}[section]
		for key in numeric_keys:
			if value.has(key) and not numeric(value[key]):return bad(section+"."+key)
		var string_keys={"garage":["selected"],"headquarters":["active"],"v09":["class"],"progression":["telegram_result"]}[section]
		for key in string_keys:
			if value.has(key) and not value[key] is String:return bad(section+"."+key)
		for key in ["collapsed","sortie_active","combat_entered","superboss_defeated"]:
			if value.has(key) and not value[key] is bool:return bad(section+"."+key)
		for key in value:
			if key in specs[section].arrays or key in specs[section].maps:continue
			if value[key] is Array or value[key] is Dictionary:return bad(section+"."+key)
	for entry in data.get("notifications",[]):
		if not entry is Dictionary or not entry.get("text") is String or not entry.get("sender") is String or not numeric(entry.get("time")) or not entry.get("read") is bool:return bad("notifications")
	for entry in data.get("duplicate_recipes",[]):
		if not entry is Dictionary or not entry.get("category") is String or not entry.get("id") is String:return bad("duplicate_recipes")
	var progress=data.get("progression",{})
	var orders=progress.get("telegram_options",[]).duplicate()
	if not progress.get("telegram",{}).is_empty():orders.append(progress.telegram)
	for order in orders:
		for key in ["id","text","event"]:
			if not order.get(key) is String:return bad("telegram."+key)
		for key in ["goal","alloy","xp"]:
			if not numeric(order.get(key)):return bad("telegram."+key)
	for order in orders:
		for key in ["progress","runs_left","run_limit"]:
			if order.has(key) and not numeric(order[key]):return bad("telegram."+key)
	for values in progress.get("recent_sorties",[]):
		for number in values.values():
			if not numeric(number):return bad("recent_sorties")
	for number in data.get("bonus_levels",{}).values():
		if not numeric(number):return bad("bonus_levels")
	for value in progress.get("viewed_updates",{}).values():
		if not value is String:return bad("viewed_updates")
	# An outdated run snapshot is completed first; if still broken, only the unfinished run is dropped.
	if data.get("run_checkpoint") is Dictionary:preload("res://scripts/profile/run_checkpoint.gd").upgrade(data.run_checkpoint)
	if data.has("run_checkpoint") and (not data.run_checkpoint is Dictionary or not preload("res://scripts/profile/run_checkpoint.gd").valid(data.run_checkpoint)):
		push_warning("Run checkpoint is incompatible and was discarded")
		data.run_checkpoint={}
	return {"ok":true,"data":migrate(data)}
static func numeric(value)->bool:return (value is int or value is float) and is_finite(float(value))
static func bad(message:String)->Dictionary:return {"ok":false,"error":"Повреждён профиль: "+message}
static func migrate(source:Dictionary)->Dictionary:
	var data=source.duplicate(true)
	# Versions 1–7 shared the legacy loader's default-based layout. Preserve
	# missing fields until application, rather than inventing historical data.
	while int(data.version)<VERSION:
		match int(data.version):
			11:data.run_checkpoint={}
			7:
				data.research=["character","weapons","bonuses","garage","range"]
				data.built=data.research.duplicate()
			10:
				if not data.has("duplicate_recipes"):data.duplicate_recipes=[]
			9:
				var extra=data.get("v09",{})
				if not data.has("class_first_slots"):data.class_first_slots=extra.get("classes",["recruit"]).duplicate()
				if not data.has("purchased_gadgets"):data.purchased_gadgets=data.get("abilities",["barrier","shield"]).filter(func(id):return id in ["barrier","mine","laser","airstrike"])
				if not data.has("purchased_hq"):data.purchased_hq=HQCatalog.DEFAULT_UNLOCKS.duplicate()+data.get("headquarters",{}).get("unlocks",[]).filter(func(id):return id not in HQCatalog.DEFAULT_UNLOCKS)
				# Retired upgrades refund exactly once during 9 -> 10.
				var shield=clampi(int(extra.get("shield_capacity",0)),0,2)
				var recovery=clampi(int(data.get("recovery",0)),0,Game.MAX_LEVEL)
				data.credits=maxi(0,int(data.get("credits",0)))+350*shield*(shield+1)/2
				for level in range(recovery):data.credits+=Balance.CONFIG.economy.upgrade_base_cost+Balance.CONFIG.economy.upgrade_step_cost*level
				if "recovery" in data.get("branch_unlocks",[]):data.credits+=Game.UNLOCK_COSTS.get("recovery",140);data.branch_unlocks.erase("recovery")
				extra.shield_capacity=0;data.v09=extra;data.recovery=0
		data.version=int(data.version)+1
	return data
