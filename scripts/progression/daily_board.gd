class_name DailyBoard
extends RefCounted
## Local daily leaderboard: the best daily attempts of every profile on this computer, top 10 per UTC day.
## Lives next to the profiles (user://daily_board.json), not inside one, so profiles compete with each other.
## Writes follow Game.save_enabled; tests point `directory` at a temporary folder.
const TOP=10
const KEEP_DAYS=30
static var directory="user://"
static func path()->String:return directory.path_join("daily_board.json")
static func load_all()->Dictionary:
	if not FileAccess.file_exists(path()):return {}
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path()))
	return parsed if parsed is Dictionary else {}
static func top(key:String)->Array:
	var day=load_all().get(key,[])
	return day if day is Array else []
## Place a score would take today (1-based), counting ties in favour of the earlier attempt.
static func place(key:String,score:int)->int:
	return top(key).filter(func(e):return int(e.get("score",0))>=score).size()+1
## Adds one finished attempt; returns its place (0 when it did not make the top).
static func add(key:String,entry:Dictionary)->int:
	var all=load_all();var day:Array=all.get(key,[]) if all.get(key,[]) is Array else []
	day.append(entry)
	day.sort_custom(func(a,b):return int(a.get("score",0))>int(b.get("score",0)))
	var rank=day.find(entry)+1
	day=day.slice(0,TOP);all[key]=day
	var days=all.keys();days.sort()
	while days.size()>KEEP_DAYS:all.erase(days.pop_front())
	if Game.save_enabled:
		var file=FileAccess.open(path(),FileAccess.WRITE)
		if file:file.store_string(JSON.stringify(all,"\t"))
	return rank if rank<=TOP else 0
static func entry_for(cycle:int,field:int,kills:int,elapsed:float)->Dictionary:
	return {"score":DailyRun.score(cycle,field,kills),"cycle":cycle,"field":field,"kills":kills,"elapsed":roundf(elapsed),"slot":Game.profiles.active,"class":Game.selected_class,"weapon":Game.selected_weapon,"at":Time.get_time_string_from_system(true).substr(0,5)}
