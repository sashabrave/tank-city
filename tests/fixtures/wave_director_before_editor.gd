extends RefCounted
const COST={"drone":2,"flyer":2,"soldier":2,"grenadier":3,"shield":3,"sniper":4,"buggy":3,"apc":4,"mortar":4,"tank":6,"boss":30}
const BUDGETS=[[10,13,16],[15,18,21],[20,23,26],[20,23,26],[20,23,26],[20,23,26]]
const COUNTS=[[4,5,6],[5,6,7],[6,7,8],[6,7,8],[6,7,8],[6,7,8]]
const CAPS=[2,3,4,4,4,4,3,5,5,5,5,5,5,5,5,3,4]
const PEOPLE=["soldier","grenadier","shield","sniper"]
const MACHINES=["buggy","apc","mortar","tank"]
static func allowed(kind: String,rank: int,room: int) -> bool:
	if kind in MACHINES and room<1:return false
	if rank==2:return room>=5 if kind in MACHINES else room>=3
	return true
static func rank_cost(kind: String,rank: int) -> int:return ceili(COST[kind]*(1.65 if rank==2 else 1.0))
static func build(seed_value: int,room: int,wave: int) -> Array:
	if room in Campaign.BOSSES:return [{"kind":"boss","rank":1}]
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+room*7919+wave*317
	var budget=(BUDGETS[mini(room,5)][wave]+(8 if room>=7 else 0))
	var exact=COUNTS[mini(room,5)][wave]*(1.2 if room>=7 else 1.0)
	var target=floori(exact)+(1 if rng.randf()<fmod(exact,1.0) else 0)
	var result=[];var counts={};var kinds=COST.keys();kinds.erase("boss")
	if rng.randf()<.72:
		var surprise="flyer" if rng.randf()<.5 else "drone"
		result.append({"kind":surprise,"rank":1});counts[surprise]=1;budget-=COST[surprise]
	while result.size()<target:
		var options=[];var reserved=(target-result.size()-1)*2
		for kind in kinds:
			if kind!="soldier" and counts.get(kind,0)>=2:continue
			if kind in ["sniper","mortar"] and counts.get(kind,0)>=1:continue
			if kind in ["drone","flyer"] and counts.get("drone",0)+counts.get("flyer",0)>=2:continue
			for rank in [1,2]:
				if rank_cost(kind,rank)>budget-reserved or not allowed(kind,rank,room):continue
				var weight=3 if counts.get(kind,0)==0 else 1
				if rank==2:weight+=1
				for i in range(weight):options.append({"kind":kind,"rank":rank})
		if options.is_empty():break
		var pick=options[rng.randi_range(0,options.size()-1)]
		result.append(pick);counts[pick.kind]=counts.get(pick.kind,0)+1;budget-=rank_cost(pick.kind,pick.rank)
	for entry in result:
		var extra=rank_cost(entry.kind,2)-COST[entry.kind]
		if allowed(entry.kind,2,room) and entry.rank==1 and budget>=extra:entry.rank=2;budget-=extra
	if rng.randf()<target*.075:result.append({"kind":"soldier","rank":1})
	for i in range(result.size()-1,0,-1):
		var j=rng.randi_range(0,i);var swap=result[i];result[i]=result[j];result[j]=swap
	return result
static func generate(seed_value: int,room: int,wave: int,_baseline: Array=[]) -> Array:
	return build(seed_value,room,wave).map(func(entry):return entry.kind)
