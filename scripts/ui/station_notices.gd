extends RefCounted
## Seen-aware notices for hub stations.
## A station dot means "something you can buy or upgrade appeared since your last visit" — opening the
## station clears it until a new affordable item shows up. A card gets a «Новое» chip when the item was
## unlocked and never selected. On the first run of this system everything already in the profile counts
## as seen, so an old profile is not flooded with badges.
const STATIONS={"fighter":"res://scripts/ui/stations/fighter_station.gd","arsenal":"res://scripts/ui/stations/arsenal_station.gd","hq":"res://scripts/ui/stations/hq_station.gd","garage":"res://scripts/ui/stations/garage_station.gd","wardrobe":"res://scripts/ui/stations/wardrobe_station.gd"}
## World benches in the hub → the station they open.
const BENCHES={"character":"fighter","weapons":"arsenal","bonuses":"arsenal","headquarters":"hq"}
const BASELINE="notice_baseline_v1"
static var cache:={}
static var cache_key:=""

## Items of a station with their status: [{id, status, tab}], computed by the same rules the station screen shows.
static func scan(kind:String)->Array:
	var key=state_key()
	if key!=cache_key:cache.clear();cache_key=key
	if cache.has(kind):return cache[kind]
	if not STATIONS.has(kind):return []
	var screen=preload("res://scripts/ui/station_screen.gd").new()
	screen.provider=load(STATIONS[kind]).new()
	var result=[]
	for tab in screen.provider.tabs():
		screen.tab=tab[0]
		for item in screen.provider.items(tab[0]):result.append({"id":str(tab[0])+":"+str(item.id),"status":screen.status(item),"tab":tab[0]})
	screen.free()
	cache[kind]=result
	return result

## Anything that changes what is affordable or unlocked invalidates the cache.
static func state_key()->String:
	return "%d|%d|%d|%d|%d|%d" % [Game.credits,Game.cores,Game.built_workshops.size(),Game.research_unlocks.size(),Game.weapon_unlocks.size(),Game.progression.seen.size()]

static func actionable(kind:String)->Array:
	return scan(kind).filter(func(i):return i.status in ["buy","upgrade"]).map(func(i):return i.id)

static func unlocked(kind:String)->Array:
	return scan(kind).filter(func(i):return i.status not in ["locked","soon"]).map(func(i):return i.id)

static func seen_key(kind:String,item:String)->String:return "item:%s:%s" % [kind,item]

static func is_new(kind:String,tab:String,id:String)->bool:
	ensure_baseline()
	return seen_key(kind,tab+":"+id) not in Game.progression.seen

static func mark_item_seen(kind:String,tab:String,id:String):
	var key=seen_key(kind,tab+":"+id)
	if key not in Game.progression.seen:Game.progression.seen.append(key);Game.save_progress()

static func has_dot(kind:String)->bool:
	ensure_baseline()
	var viewed:Array=Game.progression.viewed_updates.get("station:"+kind,[])
	for id in actionable(kind):
		if id not in viewed:return true
	for id in unlocked(kind):
		if seen_key(kind,id) not in Game.progression.seen:return true
	return false

static func mark_viewed(kind:String):
	Game.progression.viewed_updates["station:"+kind]=actionable(kind)
	Game.save_progress()

## First run: whatever the profile already has is not news.
static func ensure_baseline():
	if BASELINE in Game.progression.seen:return
	Game.progression.seen.append(BASELINE)
	for kind in STATIONS:
		for id in unlocked(kind):
			var key=seen_key(kind,id)
			if key not in Game.progression.seen:Game.progression.seen.append(key)
		Game.progression.viewed_updates["station:"+kind]=actionable(kind)
