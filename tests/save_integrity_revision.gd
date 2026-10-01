extends Node
## Regression: opening hub stations stored lists in viewed_updates, the schema rejected them and every
## later save silently failed (progress «reset» after restart). Writes only into a fresh temp folder.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Settings.persistence_enabled=false;Game.sound_enabled=false
	var dir="/tmp/r13-save-integrity-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	var restore={"path":Game.save_path,"selected":Game.profiles.selected,"blocked":Game.save_blocked,"enabled":Game.save_enabled}
	Game.save_path=dir.path_join("profile.json");Game.profiles.selected=true;Game.save_blocked=false;Game.save_enabled=true
	var N=preload("res://scripts/ui/station_notices.gd")
	Game.credits=100000;Game.cores=50
	for kind in N.STATIONS:N.mark_viewed(kind)
	check(Game.progression.viewed_updates.get("station:fighter") is Array,"stations keep their seen lists")
	check(Game.save_progress(),"save succeeds after visiting every station")
	check(Game.save_error=="","no save error is shown")
	var schema=preload("res://scripts/profile/schema.gd")
	var loaded=preload("res://scripts/profile/store.gd").load_file(Game.save_path,schema.validate)
	check(loaded.ok and int(loaded.data.credits)==100000,"written profile loads back with the new credits")
	check(loaded.ok and loaded.data.progression.viewed_updates.get("station:fighter") is Array,"station lists survive the round trip")
	Game.credits=4242;check(Game.save_progress(),"second save rotates the backup")
	var backup=preload("res://scripts/profile/store.gd").read_json(Game.save_path+".bak",schema.validate)
	check(backup.ok and int(backup.data.credits)==100000,"backup keeps the previous good save")
	var broken=Game.serialize_progress();broken.progression.viewed_updates["station:x"]=[1]
	check(not schema.validate(broken).ok,"non-string ids in a station list are still rejected")
	for file in DirAccess.get_files_at(dir):DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
	Game.save_path=restore.path;Game.profiles.selected=restore.selected;Game.save_blocked=restore.blocked;Game.save_enabled=false
	print("SAVE INTEGRITY: %d failures" % failures);get_tree().quit(1 if failures else 0)
