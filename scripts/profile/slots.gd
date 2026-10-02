extends RefCounted
const Store=preload("res://scripts/profile/store.gd")
const Schema=preload("res://scripts/profile/schema.gd")
const COUNT=3
var directory="user://"
var active=1
var selected=false
var error=""
func path(slot:int)->String:return directory.path_join("progress_v1.json" if slot==1 else "profile_%d.json" % slot)
func index_path()->String:return directory.path_join("profiles.json")
func initialize():
	var result=Store.load_file(index_path(),validate_index)
	if result.ok:
		active=maxi(1,int(result.data.active));selected=int(result.data.active)>0 and exists(active)
	else:
		for slot in range(1,COUNT+1):
			if exists(slot):active=slot;selected=true;break
	Game.save_path=path(active)
func validate_index(data:Dictionary)->Dictionary:
	if not Schema.numeric(data.get("active")) or int(data.active) not in range(0,COUNT+1):return {"ok":false,"error":"Неверная активная ячейка"}
	return {"ok":true,"data":data}
func exists(slot:int)->bool:return FileAccess.file_exists(path(slot)) or FileAccess.file_exists(path(slot)+".bak")
func summary(slot:int)->Dictionary:
	if not exists(slot):return {"empty":true}
	var result=Store.load_file(path(slot),Schema.validate)
	if not result.ok:return {"empty":false,"error":result.error}
	return {"empty":false,"level":int(result.data.get("progression",{}).get("level",1)),"credits":int(result.data.get("credits",0)),"class":result.data.get("v09",{}).get("class","recruit"),"recovered":result.get("recovered",false),"runs":int(result.data.get("progression",{}).get("counters",{}).get("runs",0)),"play_seconds":float(result.data.get("progression",{}).get("counters",{}).get("play_seconds",0))}
func choose(slot:int,create:bool=false)->bool:
	if slot not in range(1,COUNT+1):return false
	if selected and slot==active and not create and not Game.save_blocked:return true
	if create and exists(slot):error="Ячейка уже занята";return false
	# Keep the current profile recoverable before leaving it.
	if selected and not Game.save_blocked and not Game.save_progress():error=Game.save_error;return false
	var result={"ok":true,"data":Game.fresh_profile.duplicate(true)} if create else Store.load_file(path(slot),Schema.validate)
	if not result.ok:error=result.error;return false
	if create:
		var written=Store.write_file(path(slot),result.data,Schema.validate)
		if not written.ok:error=written.error;return false
	var indexed=Store.write_file(index_path(),{"active":slot},validate_index)
	if not indexed.ok:error=indexed.error;return false
	active=slot;selected=true;Game.save_path=path(slot);Game.save_blocked=false
	Game.apply_profile(result.data);Game.new_recipes.clear();Game.reset_input();Game.return_through_gate=false
	if is_instance_valid(Game.notifications):
		Game.notifications.pending.clear();Game.notifications.dirty=false
		for child in Game.notifications.feed.get_children():child.queue_free()
	Game.save_error="Восстановлена резервная копия" if result.get("recovered",false) else ""
	Campaign.configure(1);error="";Game.profile_changed.emit();return true
func remove(slot:int)->bool:
	if slot not in range(1,COUNT+1):return false
	var moved=[]
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		var file=ProjectSettings.globalize_path(path(slot)+suffix)
		if FileAccess.file_exists(file):
			if DirAccess.rename_absolute(file,file+".deleted")!=OK:
				for previous in moved:DirAccess.rename_absolute(previous+".deleted",previous)
				error="Не удалось удалить ячейку";return false
			moved.append(file)
	for file in moved:DirAccess.remove_absolute(file+".deleted")
	if slot==active and selected:
		Game.apply_profile(Game.fresh_profile.duplicate(true));Game.new_recipes.clear()
		Game.save_blocked=false;Game.save_error="";Game.reset_input();Campaign.configure(1)
		if is_instance_valid(Game.notifications):Game.notifications.pending.clear();Game.notifications.dirty=false
		selected=false
		var indexed=Store.write_file(index_path(),{"active":0},validate_index)
		if not indexed.ok:Game.save_error=indexed.error
		# No implicit new profile: return to slot selection until the user chooses one.
		Game.profile_changed.emit()
	error="";return true
