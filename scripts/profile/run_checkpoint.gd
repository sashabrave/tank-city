extends RefCounted
const VERSION=1
const RUN_KEYS=["run_seed","upgrade_history","soldier_hp","soldier_max_hp","damage_bonus","fire_multiplier","speed_multiplier","earned","kills","elapsed","weapon","rerolls_left","weapon_mods","recovery_bonus","run_bonus_levels","pending_recipes","vehicle_mods","pending_vehicle","visited_services","intercept_chance","route_choices","range_multiplier","healing_multiplier","ability_power_multiplier","ability_cooldown_multiplier","behavior_cards","tokens","burn_duration","kills_by"]
## Checkpoint fields: the fixed list plus every registry stat, so a new stat file is saved automatically.
static func keys()->Array:
	var result=RUN_KEYS.duplicate()
	for field in StatRegistry.run_fields():
		if field not in result:result.append(field)
	return result
static func capture(arena,index:int,mode:String,choices:Dictionary)->Dictionary:
	var data={"version":VERSION,"world":Campaign.world,"endless":Campaign.endless,"cycle":Campaign.cycle,"strength":Campaign.endless_strength,"index":index,"mode":mode,"seed":Game.visual_run_seed,"choices":choices.duplicate(true),"run":{},"abilities":{},"hq":{},"hero":{},"class":Game.selected_class,"start_documents":Game.cores,"daily":Campaign.daily,"daily_key":Campaign.daily_key}
	if not is_instance_valid(arena):return data
	for key in keys():data.run[key]=arena.run.get(key)
	data.run=data.run.duplicate(true)
	data.start_documents=arena.get_meta("start_documents",Game.cores)
	data.abilities={"slots":arena.abilities.slots.duplicate(),"selected":arena.abilities.selected,"levels":{}}
	for id in arena.abilities.states:data.abilities.levels[id]=arena.abilities.states[id].level.duplicate()
	data.abilities.levels[arena.abilities.selected]=arena.abilities.level.duplicate()
	data.hq={"modules":arena.headquarters.modules.duplicate(),"active":arena.headquarters.active,"levels":arena.headquarters.levels.duplicate(),"basic_hp":arena.headquarters.basic_hp}
	var p=arena.player
	if is_instance_valid(p):data.hero={"kind":p.kind,"hp":p.hp,"salvaged":p.salvaged,"origin":p.vehicle_origin,"zone":p.vehicle_zone}
	elif not arena.resume_checkpoint.is_empty():data.hero=arena.resume_checkpoint.get("hero",{}).duplicate(true)
	return data
static func integer_keys(source:Dictionary)->Dictionary:
	var result={}
	for key in source:result[int(key)]=source[key]
	return result
static func restore(arena,data:Dictionary):
	for key in keys():
		if data.run.has(key):arena.run.set(key,data.run[key])
	arena.run.route_choices=integer_keys(data.choices)
	arena.run.visited_services=integer_keys(arena.run.visited_services)
	arena.run.combat_rng.seed=int(data.seed)+int(data.index)*100003
	arena.run.last_player_shot=-10;arena.run.dash_until=0;arena.run.dash_ready_at=0
	arena.set_meta("start_documents",data.start_documents)
	if not data.abilities.is_empty():
		arena.abilities.slots=data.abilities.slots.duplicate();arena.abilities.states.clear()
		for id in data.abilities.levels:arena.abilities.states[id]={"cooldown":0.0,"level":data.abilities.levels[id].duplicate()}
		arena.abilities.selected="";arena.abilities.select(data.abilities.selected)
	if not data.hq.is_empty():
		for key in ["modules","active","levels","basic_hp"]:arena.headquarters.set(key,data.hq[key])
## Completes a snapshot written by an older build: new RunState fields, weapons and vehicles get
## their defaults, removed weapons fall back to the first one. Structural damage is still rejected by valid().
static func upgrade(data:Dictionary)->Dictionary:
	if data.is_empty() or not data.get("run") is Dictionary or data.run.is_empty():return data
	var run=data.run;var defaults=preload("res://scripts/state/run_state.gd").new()
	for key in keys():
		if not run.has(key):run[key]=defaults.get(key) if not defaults.get(key) is Dictionary and not defaults.get(key) is Array else defaults.get(key).duplicate(true)
	if run.get("weapon_mods") is Dictionary:
		for id in Game.LOOT.WEAPONS:
			if not run.weapon_mods.get(id) is Dictionary:run.weapon_mods[id]={"damage":0.0,"interval":1.0,"intercept":0.0}
	if run.get("weapon") not in Game.LOOT.WEAPONS:run.weapon=Game.LOOT.WEAPONS.keys()[0]
	if run.get("vehicle_mods") is Dictionary:
		for id in ["buggy","apc","tank"]:
			if not run.vehicle_mods.get(id) is Dictionary:run.vehicle_mods[id]=defaults.vehicle_mods[id].duplicate()
	if run.get("behavior_cards") is Array:run.behavior_cards=run.behavior_cards.filter(func(id):return UpgradeRegistry.has(str(id)))
	return data
static func valid(data:Dictionary)->bool:
	if data.is_empty():return true
	for key in ["version","world","cycle","strength","index","seed","start_documents"]:
		if not number(data.get(key)):return false
	if data.version!=VERSION or int(data.world) not in [1,2,3] or int(data.index) not in range(8 if int(data.world)==3 and not data.get("endless",false) else 7) or data.cycle<0:return false
	if not data.get("endless") is bool or data.get("mode") not in ["map","room"] or not data.get("class") is String:return false
	if not data.get("daily",false) is bool or not data.get("daily_key","") is String:return false
	for key in ["choices","run","abilities","hq","hero"]:
		if not data.get(key) is Dictionary:return false
	for key in data.choices:
		if not str(key).is_valid_int() or int(key) not in range(8 if int(data.world)==3 and not data.endless else 7) or not data.choices[key] is String:return false
	if data.mode=="room" and (data.run.is_empty() or data.hero.is_empty()):return false
	var defaults=preload("res://scripts/state/run_state.gd").new()
	if not data.run.is_empty():
		for key in keys():
			if not data.run.has(key):return false
			var value=data.run[key];var example=defaults.get(key)
			if example is int or example is float:
				if not number(value):return false
			elif typeof(value)!=typeof(example):return false
		if data.run.weapon not in Game.LOOT.WEAPONS:return false
		if data.run.pending_vehicle not in ["","buggy","apc","tank"]:return false
		for id in Game.LOOT.WEAPONS:
			var stats=data.run.weapon_mods.get(id)
			if not stats is Dictionary:return false
			for key in ["damage","interval","intercept"]:
				if not number(stats.get(key)):return false
		for id in ["buggy","apc","tank"]:
			var stats=data.run.vehicle_mods.get(id)
			if not stats is Dictionary:return false
			for key in ["damage","hp","speed"]:
				if not number(stats.get(key)):return false
		for key in ["weapon_mods","vehicle_mods"]:
			for stats in data.run[key].values():
				if not stats is Dictionary:return false
				for value in stats.values():
					if not number(value):return false
		for value in data.run.run_bonus_levels.values():
			if not number(value):return false
		for key in data.run.visited_services:
			if not str(key).is_valid_int() or not data.run.visited_services[key] is String:return false
		for recipe in data.run.pending_recipes:
			if not recipe is Dictionary or not recipe.get("category") is String or not recipe.get("id") is String:return false
		for entry in data.run.upgrade_history:
			if not entry is Dictionary or not entry.get("id") is String or not number(entry.get("tier")):return false
		for id in data.run.behavior_cards:
			if not id is String:return false
		for key in ["pending_recipes","upgrade_history"]:
			for item in data.run[key]:
				if not item is Dictionary:return false
	if not data.hero.is_empty():
		if data.hero.get("kind") not in ["soldier","buggy","apc","tank"] or data.hero.get("origin") not in ["owned","captured"]:return false
		if not number(data.hero.get("hp")) or not number(data.hero.get("zone")) or not data.hero.get("salvaged") is bool:return false
	if not data.abilities.is_empty():
		if not data.abilities.get("slots") is Array or not data.abilities.get("selected") is String or not data.abilities.get("levels") is Dictionary:return false
		for id in data.abilities.slots:
			if not id is String:return false
		for level in data.abilities.levels.values():
			if not level is Dictionary:return false
			for key in ["cooldown","power","utility"]:
				if not number(level.get(key)):return false
	if not data.hq.is_empty():
		if not data.hq.get("modules") is Array or not data.hq.get("active") is String or not data.hq.get("levels") is Dictionary or not number(data.hq.get("basic_hp")):return false
		for id in data.hq.modules:
			if not id is String:return false
		for value in data.hq.levels.values():
			if not number(value):return false
	return true
static func number(value)->bool:return (value is int or value is float) and is_finite(float(value))
