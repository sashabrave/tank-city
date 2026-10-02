class_name WaveDirector
extends RefCounted
static var COST=Balance.CONFIG.wave_costs()
const PEOPLE=["soldier","shield","grenadier","sniper"]  # draw order matters for seeded waves; same set as UnitKinds.INFANTRY
const LIGHT=["buggy","mortar","apc"]
const HEAVY=["rpg","tank"]
const MACHINES=["buggy","apc","mortar","tank"]
static func allowed(kind:String,rank:int,room:int)->bool:
	return kind in PEOPLE+MACHINES and rank>=1 and rank<=max_rank(room)
static func max_rank(_room:int)->int:
	return mini(3,1+Campaign.cycle) if Campaign.endless else Campaign.world
static func rank_cost(kind:String,rank:int)->int:return ceili(COST[kind]*[1.0,1.65,2.25][clampi(rank-1,0,2)])
static func build(seed_value:int,room:int,wave:int,difficulty:int=0,node_id:String="")->Array:
	if room in Campaign.BOSSES:return [{"kind":"boss","rank":1}]
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+room*7919+wave*317+Campaign.world*991+Campaign.cycle*65537
	if node_id!="":rng.seed+=node_id.hash()
	var target=wave_size(room,wave,difficulty)
	var tier=content_tier(room)
	var infantry=["soldier","shield"] if wave==0 else PEOPLE
	var light=["buggy","apc"] if wave==0 else LIGHT
	var groups=[{"pool":infantry,"count":target if tier==1 else 3 if tier==2 else 2}]
	if tier>=2:groups.append({"pool":light,"count":target-3 if tier==2 else 2})
	if tier==3:groups.append({"pool":HEAVY,"count":mini(6,target-4)})
	var types=[]
	for group in groups:
		var counts={}
		for i in range(group.count):
			var candidates=group.pool.filter(func(k):return int(counts.get(k,0))<(1 if k in ["mortar","sniper"] else 3 if k in HEAVY else group.count))
			var kind=group.pool[posmod(seed_value+room+wave,group.pool.size())] if i==0 else candidates[rng.randi_range(0,candidates.size()-1)]
			if group.pool==HEAVY and i<2:kind=HEAVY[posmod(seed_value+room+wave+i,2)]
			if wave==1 and i==0:
				if group.pool==PEOPLE:kind="sniper" if tier==3 else "grenadier"
				elif group.pool==LIGHT:kind="mortar"
			types.append(kind);counts[kind]=int(counts.get(kind,0))+1
	# Shuffle with this local RNG, preserving preview/combat determinism.
	for i in range(types.size()-1,0,-1):
		var j=rng.randi_range(0,i);var swap=types[i];types[i]=types[j];types[j]=swap
	var result=[]
	for type in types:
		var kind="grenadier" if type=="rpg" else str(type)
		var rank=max_rank(room)
		var weapon=EnemyLoadouts.BASIC[rng.randi_range(0,3)] if kind=="soldier" else EnemyLoadouts.default_for(kind)
		if type=="rpg":weapon="rpg"
		result.append({"kind":kind,"rank":rank,"weapon":weapon})
	return result
## Enemies in one wave: base + field × step + wave + stars (+ endless sectors); vehicle fields have a minimum.
## All numbers live in Balance.CONFIG.campaign.
static func wave_size(room:int,wave:int,difficulty:int=0)->int:
	var t=Balance.CONFIG.campaign
	var size=t.wave_base_size+floori(room*t.wave_size_per_field)+wave*t.wave_size_per_wave+mini(t.endless_size_cap,Campaign.cycle*t.endless_size_per_sector)+clampi(difficulty,0,2)*t.wave_size_per_star
	size+=1 if Campaign.challenge_level()>=3 else 0  # challenge III: one more enemy per wave
	return maxi(t.vehicle_wave_minimum,size) if content_tier(room)==2 else size
static func generate(seed_value:int,room:int,wave:int,_baseline:Array=[])->Array:return build(seed_value,room,wave).map(func(entry):return entry.kind)

# Content tiers are local to every world, independent of enemy stat ranks.
static func content_tier(room:int)->int:return clampi(1+int(room/2),1,3)
static func tanks_in_wave(room:int,_wave:int)->bool:return room>=4
static func tank_limit(room:int,wave:int)->int:return 3 if tanks_in_wave(room,wave) else 0
static func commander_entry(seed_value:int,room:int,node_id:String="")->Dictionary:
	var pool=["shield","grenadier","sniper"] if room==0 else ["buggy","apc"] if room<=2 else HEAVY
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+room*92821+node_id.hash()
	var type=pool[rng.randi_range(0,pool.size()-1)]
	var kind="boss" if room in Campaign.BOSSES else "grenadier" if type=="rpg" else str(type)
	return {"kind":kind,"weapon":"rpg" if type=="rpg" and kind!="boss" else EnemyLoadouts.default_for(kind)}

static func wave_hint(wave:int)->String:return ["Угроза впереди · изучи противника","Основные силы под прикрытием","Заходы с двух сторон · меняй позицию"][clampi(wave,0,2)]
static func side_spawn_cells(size:int,wave:int)->Array:
	var sides=[]
	for row in [2,4].slice(0,clampi(wave,0,2)):
		sides.append(Vector2i(0,row));sides.append(Vector2i(size-1,row))
	return sides
static func spawn_cells(size:int,wave:int,columns:Array=[])->Array:
	var front=[]
	if columns.is_empty():columns=[1,int(size/2),size-2]
	for x in columns:front.append(Vector2i(x,0))
	return side_spawn_cells(size,wave)+front
