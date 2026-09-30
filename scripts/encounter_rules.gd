class_name EncounterRules
extends RefCounted
const NAMES=["Простая","Средняя ★","Сложная ★★"]
const STARS=["","★","★★"]
const KILL_ALLOY={"soldier":1,"drone":2,"apc":3,"tank":5,"boss":25,"grenadier":2,"buggy":2,"mortar":4,"shield":3,"sniper":4,"flyer":2}
static func difficulty(value)->int:return clampi(int(value),0,2)
static func reward_text(level:int)->String:
	return ["Без чертежей · обычные усиления","Частые чертежи · редкие усиления","Редкие чертежи · эпические усиления"][difficulty(level)]
static func chest_alloy(stage:int,level:int)->int:
	var full=Balance.CONFIG.economy.chest_alloy+Campaign.progress_index(stage)*Balance.CONFIG.economy.chest_alloy_per_room
	return roundi(full*[.3,.65,1.0][difficulty(level)])
static func kill_alloy(kind:String,rank:int,stage:int,commander:bool=false,level:int=0)->int:
	var amount=int(KILL_ALLOY[kind])
	if rank>=2:amount=ceili(amount*(2.0 if rank==3 else 1.5))
	if commander:amount+=[3+stage,5+stage*2,8+stage*3][difficulty(level)]
	return roundi(amount*2*(1+(Campaign.world-1)*.35+(Campaign.cycle*.15 if Campaign.endless else 0)))
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
static func recipe(level:int,rng:RandomNumberGenerator,pending:Array,stage:int)->Dictionary:
	var options=recipe_pool(level,pending,stage)
	# The common path supplies construction prerequisites before optional gear.
	if level==1:
		for id in ["weapons","headquarters","garage"]:
			for option in options:
				if option.category=="research" and option.id==id:return option
	if options.is_empty():options=recipe_pool(level,pending,stage,true)
	var result={} if options.is_empty() else options[rng.randi_range(0,options.size()-1)].duplicate()
	if not result.is_empty() and result.id in Game.recipe_owned(result.category):result["duplicate"]=true
	return result
