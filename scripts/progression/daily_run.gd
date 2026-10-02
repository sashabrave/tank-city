class_name DailyRun
extends RefCounted
## Daily run: the endless mode on one shared seed per UTC day. Everybody gets the same fields, waves,
## generals, service stops and — room by room — the same card and chest offers. Enemy strength is pinned
## instead of following the player's meta, so results compare fairly; the loadout stays the player's own.
## Records live in Game.progression.daily: {date: {score, cycle, field, kills, elapsed, class, weapon, attempts}}.
const STRENGTH=1.3
const KEEP_DAYS=30

static func today_key()->String:return Time.get_date_string_from_system(true)

static func seed_for(key:String)->int:
	var value=absi(hash(["war-cats-daily",key]))
	return value if value!=0 else 1  # the arena rerolls a zero seed

## Depth first (sector, then field), kills break ties.
static func score(cycle:int,field:int,kills:int)->int:return (cycle*7+field)*100000+mini(kills,9999)*10

## Room-level generator for daily offers: same room of the same day → same cards and chests,
## however the player spent the previous rooms.
static func room_seed(run_seed:int,cycle:int,room:int)->int:return hash([run_seed,cycle,room,"daily-offers"])

static func best(key:String)->Dictionary:
	var value=Game.progression.daily.get(key,{})
	return value if value is Dictionary else {}

## Writes one finished daily attempt; returns true when it beat the day's best.
static func record(key:String,cycle:int,field:int,kills:int,elapsed:float)->bool:
	var entry=best(key).duplicate()
	var result=score(cycle,field,kills)
	var improved=result>int(entry.get("score",-1))
	entry.attempts=int(entry.get("attempts",0))+1
	if improved:
		entry.merge({"score":result,"cycle":cycle,"field":field,"kills":kills,"elapsed":roundf(elapsed),"class":Game.selected_class,"weapon":Game.selected_weapon},true)
	Game.progression.daily[key]=entry
	DailyBoard.add(key,DailyBoard.entry_for(cycle,field,kills,elapsed))
	var days=Game.progression.daily.keys();days.sort()
	while days.size()>KEEP_DAYS:Game.progression.daily.erase(days.pop_front())
	return improved

## Newest first: [[date, entry], …].
static func history()->Array:
	var days=Game.progression.daily.keys();days.sort();days.reverse()
	return days.map(func(day):return [day,Game.progression.daily[day]])

## Source (Russian) text; UI labels localize it through Texts.set_text and the en.tsv template.
static func describe(entry:Dictionary)->String:
	if entry.is_empty() or not entry.has("score"):return "Ещё не сыграно"
	return "сектор %d · поле %d · врагов %d" % [int(entry.cycle)+1,int(entry.field)+1,int(entry.get("kills",0))]
