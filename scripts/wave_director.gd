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
	# Squads, not a random pile: pick weighted squads until the wave is full, respecting kind caps.
	var options=SquadCatalog.pool(tier,wave);var counts={};var types=[];var guard=0
	# Tank pacing: no tank squads before tanks are introduced; from then on every wave opens with one.
	var has_tank=func(sq):return sq.members.any(func(m):return m[0]=="tank")
	if not tanks_in_wave(room,wave):options=options.filter(func(sq):return not has_tank.call(sq))
	var lead=options.filter(has_tank) if tanks_in_wave(room,wave) else []
	while types.size()<target and guard<40:
		guard+=1
		var allowed=(lead if not lead.is_empty() and guard==1 else options).filter(func(sq):return sq.members.all(func(m):return int(counts.get(m[0],0))+sq.members.filter(func(o):return o[0]==m[0]).size()<=int(SquadCatalog.CAPS.get(m[0],99))))
		if allowed.is_empty():allowed=SquadCatalog.pool(1,wave).filter(func(sq):return not has_tank.call(sq))
		var total=0.0
		for sq in allowed:total+=SquadCatalog.weight(sq,tier)
		var pick=rng.randf()*total;var squad=allowed.back()
		for sq in allowed:
			pick-=SquadCatalog.weight(sq,tier)
			if pick<0:squad=sq;break
		for member in squad.members:
			if types.size()>=target:break
			types.append({"type":member[0],"weapon":member[1],"squad":squad.id});counts[member[0]]=int(counts.get(member[0],0))+1
	var result=[]
	for entry in types:
		var type=str(entry.type)
		var kind="grenadier" if type=="rpg" else type
		var rank=max_rank(room)
		var weapon="rpg" if type=="rpg" else EnemyLoadouts.BASIC[rng.randi_range(0,3)] if entry.weapon=="*" else str(entry.weapon) if entry.weapon!="" else EnemyLoadouts.default_for(kind)
		result.append({"kind":kind,"rank":rank,"weapon":weapon,"squad":entry.squad})
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
