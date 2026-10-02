extends Node
## Profile cards show total play time and the number of runs; a fanfare ducks the music bed, not itself.
## Reads the slot summaries only; profile and settings writes stay disabled.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false
	var P=preload("res://scripts/ui/profile_picker.gd")
	check(P.runs_text(1)=="1 забег" and P.runs_text(3)=="3 забега" and P.runs_text(12)=="12 забегов" and P.runs_text(21)=="21 забег","run count words")
	check(P.play_time_text(30)=="меньше минуты" and P.play_time_text(125)=="2 мин" and P.play_time_text(3*3600+12*60)=="3 ч 12 мин","play time text")
	var runs=int(Game.progression.counters.get("runs",0))
	Game.progression.begin_run();check(int(Game.progression.counters.runs)==runs+1,"starting a sortie counts a run")
	Game.progression.counters.runs=runs
	var picker=P.new();add_child(picker);await get_tree().process_frame;await get_tree().process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-profiles.png")
	var music=Game.music_controller
	if is_instance_valid(music):
		check(AudioServer.get_bus_index(music.BED_BUS)>=0 and music.backgrounds[0].bus==music.BED_BUS and music.stinger.bus!=music.BED_BUS,"background on the bed bus, fanfare above it")
	print("PROFILE STATS: %d failures" % failures);get_tree().quit(1 if failures else 0)
