extends Node
## Daily run: one seed per UTC day, pinned enemy strength, per-room offer seeds, local records,
## checkpoint round trip and a profile that validates. Saves stay disabled.
var errors=0
func check(value:bool,message:String):
	if value:print("PASS ",message)
	else:errors+=1;push_error("FAIL: "+message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	var saved_daily=Game.progression.daily.duplicate(true);Game.progression.daily={}
	var key=DailyRun.today_key()
	check(key.length()==10 and key[4]=="-","UTC date key")
	check(DailyRun.seed_for(key)==DailyRun.seed_for(key) and DailyRun.seed_for(key)!=0,"same day → same non-zero seed")
	check(DailyRun.seed_for("2026-09-30")!=DailyRun.seed_for("2026-10-01"),"another day → another seed")
	Campaign.configure(1,true,true)
	check(Campaign.daily and Campaign.endless and Campaign.daily_key==key,"daily configures endless")
	check(is_equal_approx(Campaign.endless_strength,DailyRun.STRENGTH),"enemy strength pinned for everyone")
	check(Campaign.title(2).begins_with("Забег дня"),"daily title")
	check(DailyRun.room_seed(77,1,3)==DailyRun.room_seed(77,1,3) and DailyRun.room_seed(77,1,3)!=DailyRun.room_seed(77,1,4),"room offer seeds")
	# Same seed and room → same offers regardless of what happened before.
	var a=RandomNumberGenerator.new();a.seed=DailyRun.room_seed(77,0,2);var b=RandomNumberGenerator.new();b.seed=DailyRun.room_seed(77,0,2)
	check(a.randf()==b.randf(),"offer rng repeats")
	check(DailyRun.score(1,2,30)>DailyRun.score(0,6,999),"depth beats kills")
	check(DailyRun.record(key,0,3,12,200.0),"first attempt is a record")
	check(not DailyRun.record(key,0,2,40,300.0),"shallower attempt is not")
	var best=DailyRun.best(key)
	check(int(best.attempts)==2 and int(best.field)==3 and int(best.kills)==12,"best kept, attempts counted")
	check(DailyRun.describe(best)=="сектор 1 · поле 4 · врагов 12","record text")
	for i in range(40):Game.progression.daily["2020-01-%02d" % (i%28+1)+("x" if i>=28 else "")]={"score":i}
	DailyRun.record(key,0,1,1,1.0)
	check(Game.progression.daily.size()<=DailyRun.KEEP_DAYS and Game.progression.daily.has(key),"history trimmed, today kept")
	# Profile schema accepts the daily map and rejects garbage in it.
	var profile=Game.serialize_progress()
	check(preload("res://scripts/profile/schema.gd").validate(profile).ok,"profile with daily validates")
	var broken=profile.duplicate(true);broken.progression.daily={"2026-01-01":5}
	check(not preload("res://scripts/profile/schema.gd").validate(broken).ok,"garbage daily rejected")
	# Checkpoint carries the daily flag and key.
	var cp=preload("res://scripts/profile/run_checkpoint.gd").capture(null,0,"map",{})
	check(cp.daily==true and cp.daily_key==key and preload("res://scripts/profile/run_checkpoint.gd").valid(cp),"checkpoint round trip")
	Campaign.configure(1,true)
	check(not Campaign.daily and Campaign.daily_key=="","plain endless is not daily")
	Game.progression.daily=saved_daily
	# from daily_board_revision: local top 10 across profiles, written only into a fresh temporary folder.
	var dir=OS.get_temp_dir().path_join("warcats_daily_board_%d" % Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(dir)
	var saved=[DailyBoard.directory,Game.profiles.directory,Game.profiles.active]
	DailyBoard.directory=dir;Game.profiles.directory=dir;Game.save_enabled=true
	check(DailyBoard.top(key).is_empty(),"empty board in a fresh folder")
	for i in range(12):
		Game.profiles.active=1+i%3
		DailyBoard.add(key,DailyBoard.entry_for(i%3,i%7,i*5,60.0+i))
	Game.save_enabled=false
	var rows=DailyBoard.top(key)
	check(rows.size()==10,"board keeps the top 10")
	check(rows.size()==10 and int(rows[0].score)>=int(rows[9].score),"best first")
	check(not rows.is_empty() and DailyBoard.place(key,int(rows[0].score)+1)==1,"a better score takes first place")
	check(FileAccess.file_exists(dir.path_join("daily_board.json")),"board file lands in the temp folder")
	for file in DirAccess.get_files_at(dir):DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
	DailyBoard.directory=saved[0];Game.profiles.directory=saved[1];Game.profiles.active=saved[2]
	# from daily_board_revision: the daily run and its table are open before world 1 is cleared (0.8.0).
	var cleared=Game.progression.cleared_worlds.duplicate();Game.progression.cleared_worlds.clear()
	var early=load("res://scripts/ui/world_select.gd").new();add_child(early);await get_tree().process_frame
	check(early.find_child("DailyRun",true,false)!=null and early.find_child("DailyBoard",true,false)!=null,"daily run and table open from the start")
	early.queue_free();await get_tree().process_frame
	Game.progression.cleared_worlds=cleared
	print("DAILY RUN: %d failures" % errors)
	get_tree().quit(1 if errors else 0)
