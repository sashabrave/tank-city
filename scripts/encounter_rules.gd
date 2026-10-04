class_name EncounterRules
extends RefCounted
const NAMES=["Простая","Средняя ★","Сложная ★★"]
const STARS=["","★","★★"]
const KILL_ALLOY={"soldier":1,"drone":2,"apc":3,"tank":5,"boss":25,"grenadier":2,"buggy":2,"mortar":4,"shield":3,"sniper":4,"flyer":2}
static func difficulty(value)->int:return clampi(int(value),0,2)
static func reward_text(level:int)->String:
	return ["Обычные усиления","Чертёж в сундуке · редкие усиления","Редкий чертёж · эпические усиления"][difficulty(level)]
static func chest_alloy(stage:int,level:int)->int:
	var full=Balance.CONFIG.economy.chest_alloy+Campaign.progress_index(stage)*Balance.CONFIG.economy.chest_alloy_per_room
	return roundi(full*[.3,.65,1.0][difficulty(level)]*Campaign.alloy_multiplier())
static func kill_alloy(kind:String,rank:int,stage:int,commander:bool=false,level:int=0)->int:
	var amount=int(KILL_ALLOY.get(kind,KILL_ALLOY.get("soldier",1)))  # a new kind without its own price pays like a soldier
	if rank>=2:amount=ceili(amount*(2.0 if rank==3 else 1.5))
	if commander:amount+=[3+stage,5+stage*2,8+stage*3][difficulty(level)]
	return roundi(amount*Balance.CONFIG.economy.kill_alloy_scale*(1+(Campaign.world-1)*.35+(Campaign.cycle*.15 if Campaign.endless else 0))*Campaign.reward_multiplier()*Campaign.alloy_multiplier())
static func recipe_pool(level:int,pending:Array,stage:int,include_owned:bool=false)->Array:
	if level==0:return []
	var options=[]
	for category in ["research","weapon","bonus","ability","hq","garage"]:
		for id in Game.recipe_catalog(category):
			if (not include_owned and id in Game.recipe_owned(category)) or pending.any(func(r):return r.id==id and r.category==category):continue
			if category=="research" and id in Game.RETIRED_BUILDINGS:continue
			# Class skills are purchases, never a blueprint reward.
			if category=="ability" and id not in ["barrier","mine","laser","airstrike"]:continue
			if category=="weapon" and Campaign.recipe_world()<Campaign.weapon_world(id):continue
			if category=="garage" and GarageCatalog.weight(id,stage)==0:continue
			var tier=Game.TIERS.tier(id)
			if (level==1 and tier>1) or (level==2 and tier<2):continue
			if Campaign.unified_content() and tier>Game.TIERS.unlocked(stage):continue
			options.append({"category":category,"id":id})
	return options
## 0.8 (author): key buildings come on a fixed beat of world 1 — the HQ blueprint in the commander chest at the
## end of the first segment (field 2), the Garage in the middle segment (field 4) — whatever the node's
## stars, until owned. Everything else stays random.
const GUARANTEED={1:"headquarters",3:"garage"}
static func guaranteed(stage:int,pending:Array)->Dictionary:
	if Campaign.endless or Campaign.world!=1 or not GUARANTEED.has(stage):return {}
	var id=str(GUARANTEED[stage])
	if id in Game.recipe_owned("research") or id in Game.RETIRED_BUILDINGS or pending.any(func(r):return r.id==id and r.category=="research"):return {}
	return {"category":"research","id":id}
## The first stations (Арсенал, Штаб, Стоянка) come early: while one is not owned, any chest — simple fields
## too — holds its blueprint with FIRST_BUILDING_CHANCE. Once owned it leaves the pool for good.
const FIRST_BUILDINGS=["weapons","headquarters","garage"]
const FIRST_BUILDING_CHANCE=.6
static func first_building(rng:RandomNumberGenerator,pending:Array)->Dictionary:
	if Campaign.endless:return {}
	for id in FIRST_BUILDINGS:
		if id in Game.recipe_owned("research") or id in Game.RETIRED_BUILDINGS or pending.any(func(r):return r.id==id and r.category=="research"):continue
		return {"category":"research","id":id} if rng.randf()<FIRST_BUILDING_CHANCE else {}
	return {}
## Weights inside the pool (author, 4 Oct 2026): what changes the game — guns, HQ tech, vehicles, gadgets,
## blueprint insurance and rerolls — drops about twice as often as small things (field bonuses, vehicle
## equipment, the test range).
static func recipe_weight(option:Dictionary)->float:
	var id=str(option.id)
	match str(option.category):
		"weapon","hq","ability":return 2.0
		"research":return .5 if id=="range" else 2.0
		"garage":return 2.0 if id.begins_with("vehicle_") else 1.0
	return 1.0
static func weighted_pick(options:Array,rng:RandomNumberGenerator)->Dictionary:
	var total=0.0
	for option in options:total+=recipe_weight(option)
	var roll=rng.randf()*total
	for option in options:
		roll-=recipe_weight(option)
		if roll<0:return option
	return options[-1]
static func recipe(level:int,rng:RandomNumberGenerator,pending:Array,stage:int)->Dictionary:
	var options=recipe_pool(level,pending,stage)
	# The common path supplies construction prerequisites before optional gear.
	if level==1:
		for id in ["weapons","headquarters","garage"]:
			for option in options:
				if option.category=="research" and option.id==id:return option
	if options.is_empty():options=recipe_pool(level,pending,stage,true)
	var result={} if options.is_empty() else weighted_pick(options,rng).duplicate()
	if not result.is_empty() and result.id in Game.recipe_owned(result.category):result["duplicate"]=true
	return result
