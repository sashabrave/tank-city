extends RefCounted
## Seen-aware notices for hub stations. One rule everywhere (author, 0.8.0): an item is NEW when it is unlocked
## and was never selected, or it just became affordable and was not selected since. Its card carries the
## «Новое» chip; a tab dot and the hub station dot are lit while ANY item of that tab / station is new, and go
## out as soon as the last one is selected. On the first run of this system everything already in the profile
## counts as seen, so an old profile is not flooded with badges.
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
	var key=seen_key(kind,tab+":"+id);var changed=false
	if key not in Game.progression.seen:Game.progression.seen.append(key);changed=true
	var viewed:Array=viewed_affordable(kind)
	if tab+":"+id in actionable(kind) and tab+":"+id not in viewed:viewed.append(tab+":"+id);changed=true
	if changed:Game.save_progress()

## Affordable items already selected. Items that stopped being affordable drop out, so they turn new again
## when the player can afford them once more.
static func viewed_affordable(kind:String)->Array:
	var now=actionable(kind)
	var viewed:Array=Game.progression.viewed_updates.get("station:"+kind,[]).filter(func(id):return id in now)
	Game.progression.viewed_updates["station:"+kind]=viewed
	return viewed
static func item_new(kind:String,full_id:String,status:String)->bool:
	ensure_baseline()
	if status in ["locked","soon","done","goal","later"]:return false
	if seen_key(kind,full_id) not in Game.progression.seen:return true
	return status in ["buy","upgrade"] and full_id not in viewed_affordable(kind)
static func tab_new(kind:String,tab:String)->bool:
	if kind=="fighter" and tab=="shells" and class_ready():return true
	return scan(kind).any(func(i):return i.tab==tab and item_new(kind,i.id,i.status))
## A class whose condition is met and that is not opened yet (T-224): an action available now, so its card, the
## «Классы» tab and the Barracks carry the green dot until the class is opened — seen or not.
static func class_ready()->bool:
	return ClassCatalog.ROSTER.any(func(id):return id not in Game.class_unlocks and Game.can_select_class(id))
## Every item of a station as viewed (profile migrations, tests).
static func mark_all_seen(kind:String):
	for i in scan(kind):
		if i.status in ["locked","soon"]:continue  # a still-closed item becomes news when it opens
		var key=seen_key(kind,i.id)
		if key not in Game.progression.seen:Game.progression.seen.append(key)
	Game.progression.viewed_updates["station:"+kind]=actionable(kind)
	Game.save_progress()
static func has_dot(kind:String)->bool:
	if kind=="fighter" and class_ready():return true
	return scan(kind).any(func(i):return item_new(kind,i.id,i.status))

## First run: whatever the profile already has is not news.
static func ensure_baseline():
	if BASELINE in Game.progression.seen:return
	Game.progression.seen.append(BASELINE)
	for kind in STATIONS:
		for id in unlocked(kind):
			var key=seen_key(kind,id)
			if key not in Game.progression.seen:Game.progression.seen.append(key)
		Game.progression.viewed_updates["station:"+kind]=actionable(kind)
