class_name WaveDirectorBeforeInfantryV5
extends RefCounted
static var COST=Balance.CONFIG.wave_costs()
static var BUDGETS=Balance.CONFIG.campaign.wave_budgets.map(func(v):return [v.x,v.y,v.z])
static var COUNTS=Balance.CONFIG.campaign.wave_counts.map(func(v):return [v.x,v.y,v.z])
static var CAPS=Balance.CONFIG.campaign.active_enemy_caps
const PEOPLE=["soldier","grenadier","shield","sniper"]
const MACHINES=["buggy","apc","mortar","tank"]
static func allowed(kind: String,rank: int,room: int) -> bool:
	if kind in ["drone","flyer"]:return false
	if kind in MACHINES and room<int(Balance.CONFIG.campaign.vehicle_first_room[kind]):return false
	if rank==2:return room>=5 if kind in MACHINES else room>=3
	return true
static func rank_cost(kind: String,rank: int) -> int:return ceili(COST[kind]*(1.65 if rank==2 else 1.0))
static func build(seed_value: int,room: int,wave: int) -> Array:
	if room in Campaign.BOSSES:return [{"kind":"boss","rank":1}]
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+room*7919+wave*317
	var budget=(BUDGETS[mini(room,5)][wave]+(Balance.CONFIG.campaign.zone_two_budget_bonus if room>=7 else 0))
	var exact=COUNTS[mini(room,5)][wave]*(Balance.CONFIG.campaign.zone_two_population if room>=7 else 1.0)
	var target=floori(exact)+(1 if rng.randf()<fmod(exact,1.0) else 0)
	var result=[];var counts={};var kinds=PEOPLE+MACHINES
	# First buggy is guaranteed before any heavy vehicle can unlock.
	if room==1 and wave==0:
		result.append({"kind":"buggy","rank":1});counts["buggy"]=1;budget-=COST.buggy
	while result.size()<target:
		var options=[];var reserved=(target-result.size()-1)*2
		for kind in kinds:
			if kind!="soldier" and counts.get(kind,0)>=2:continue
			if kind in ["sniper","mortar"] and counts.get(kind,0)>=1:continue
			if kind in ["drone","flyer"] and counts.get("drone",0)+counts.get("flyer",0)>=2:continue
			for rank in [1,2]:
				if rank_cost(kind,rank)>budget-reserved or not allowed(kind,rank,room):continue
				var weight=3 if counts.get(kind,0)==0 else 1
				if kind in MACHINES:weight=maxi(1,roundi(weight*Balance.CONFIG.campaign.machine_weights[mini(room,5)]))
				elif room>=4:weight=1
				if rank==2:weight=1
				for i in range(weight):options.append({"kind":kind,"rank":rank})
		if options.is_empty():break
		var pick=options[rng.randi_range(0,options.size()-1)]
		result.append(pick);counts[pick.kind]=counts.get(pick.kind,0)+1;budget-=rank_cost(pick.kind,pick.rank)
	for entry in result:
		var extra=rank_cost(entry.kind,2)-COST[entry.kind]
		if allowed(entry.kind,2,room) and entry.rank==1 and budget>=extra:entry.rank=2;budget-=extra
	if rng.randf()<target*Balance.CONFIG.campaign.extra_soldier_chance:result.append({"kind":"soldier","rank":1})
	for i in range(result.size()-1,0,-1):
		var j=rng.randi_range(0,i);var swap=result[i];result[i]=result[j];result[j]=swap
	return result
static func generate(seed_value: int,room: int,wave: int,_baseline: Array=[]) -> Array:
	return build(seed_value,room,wave).map(func(entry):return entry.kind)
