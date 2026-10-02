class_name TaskBoard
extends RefCounted
## Mini task board (tester tools). The board lives in the project: tasks/board.json (in git, shipped
## read-only inside builds). Running from source the game edits it directly; an exported build cannot
## write into its own pack, so its new tasks and status moves go to an inbox next to the saves
## (user://task_inbox.json, screenshots in user://task_shots/). tools/board.py sync folds the inbox
## into tasks/board.json at the start of every work session.
## Task: {id, title, note, type, priority 1–3, status, version, created, source, shot}.
const STATUSES=["backlog","doing","review","done"]
const STATUS_NAMES={"backlog":"Бэклог","doing":"В работе","review":"Проверить","done":"Готово"}
const TYPES=["bug","idea","polish","question"]
const TYPE_NAMES={"bug":"Баг","idea":"Идея","polish":"Полировка","question":"Вопрос ко мне"}
const PRIORITY_NAMES={1:"Высокая",2:"Обычная",3:"Низкая"}
## Tests point these at a temporary folder.
static var repo_path="res://tasks/board.json"
static var inbox_path="user://task_inbox.json"
static var shots_dir="user://task_shots"
static var repo_shots_dir="res://tasks/shots"
## Running from source: the project folder is writable. Exported builds carry the "template" feature.
## force_inbox: tests imitate an exported build.
static var force_inbox=false
static func repo_writable()->bool:return not OS.has_feature("template") and not force_inbox

static func read_json(path:String,fallback):
	if not FileAccess.file_exists(path):return fallback
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed)==typeof(fallback) else fallback
static func write_json(path:String,value)->bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(value,"\t"));return true

static func repo()->Dictionary:return read_json(repo_path,{"next_id":1,"tasks":[]})
static func inbox()->Array:return read_json(inbox_path,[])
## Board as the player sees it: the project board with this computer's inbox applied on top.
static func tasks()->Array:
	var list:Array=repo().get("tasks",[]).duplicate(true)
	for event in inbox():
		if event.get("op","")=="add":list.append(event.task)
		elif event.get("op","")=="move":
			for task in list:
				if task.id==event.id:task.status=event.status
	return list
static func column(status:String)->Array:
	var list=tasks().filter(func(t):return t.get("status","backlog")==status)
	# Questions to the developer first, then by priority, newest last.
	list.sort_custom(func(a,b):return [0 if a.type=="question" else 1,int(a.priority),str(a.id)]<[0 if b.type=="question" else 1,int(b.priority),str(b.id)])
	return list

## New task from the game. `shot` is a screenshot taken before the form opened (may be null).
static func add(title:String,note:String,type:String,priority:int,shot:Image=null)->Dictionary:
	var task={"title":title.strip_edges(),"note":note.strip_edges(),"type":type if type in TYPES else "idea","priority":clampi(priority,1,3),"status":"backlog","version":str(ProjectSettings.get_setting("application/config/version","")),"created":Time.get_date_string_from_system(),"source":"game","scene":scene_name(),"shot":""}
	if repo_writable():
		var board=repo();var number=int(board.get("next_id",1))
		task.id="T-%03d" % number;board.next_id=number+1
		if shot:task.shot=save_shot(shot,repo_shots_dir,task.id)
		board.tasks.append(task);write_json(repo_path,board)
	else:
		task.id="I-%d" % Time.get_unix_time_from_system()
		if shot:task.shot=save_shot(shot,shots_dir,task.id)
		var events=inbox();events.append({"op":"add","task":task});write_json(inbox_path,events)
	return task
static func move(id:String,status:String)->bool:
	if status not in STATUSES:return false
	if repo_writable() and not id.begins_with("I-"):
		var board=repo()
		for task in board.tasks:
			if task.id==id:task.status=status;return write_json(repo_path,board)
		return false
	var events=inbox();events.append({"op":"move","id":id,"status":status});return write_json(inbox_path,events)
static func save_shot(shot:Image,dir:String,id:String)->String:
	DirAccess.make_dir_recursive_absolute(dir)
	var small=shot.duplicate();if small.get_width()>1280:small.resize(1280,int(1280.0*small.get_height()/small.get_width()))
	var path=dir.path_join(id+".png");small.save_png(path);return path
static func scene_name()->String:
	var tree=Engine.get_main_loop() as SceneTree
	if tree==null or tree.current_scene==null:return ""
	var scene=tree.current_scene
	for child in scene.get_children():
		if child.get_script() and child.get_script().resource_path.get_file() in ["hub.gd","arena.gd","route_map.gd","merchant_room.gd","service_room.gd"]:return child.get_script().resource_path.get_file().get_basename()
	return scene.name
## Tasks that need the author: "decide" — open questions; "check" — work waiting in «Проверить».
static func for_me(kind:String)->Array:
	if kind=="decide":return tasks().filter(func(t):return t.get("type","")=="question" and t.get("status","")!="done")
	return column("review")
