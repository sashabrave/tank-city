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
	print("DAILY RUN: %d failures" % errors)
	get_tree().quit(errors)
