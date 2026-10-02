extends Node
## Local daily leaderboard: top 10 across profiles, places, file in a temporary folder.
## Writes go to a fresh temporary directory only. Window shot /tmp/r13-daily-board.png.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Settings.persistence_enabled=false;Game.sound_enabled=false
	get_window().size=Vector2i(1600,900)
	var dir="user://test_daily_board_%d" % Time.get_ticks_usec();DirAccess.make_dir_recursive_absolute(dir)
	DailyBoard.directory=dir;Game.save_enabled=true;Game.profiles.directory=dir
	var key=DailyRun.today_key()
	check(DailyBoard.top(key).is_empty(),"empty board in a fresh folder")
	for i in range(12):
		Game.profiles.active=1+i%3
		DailyBoard.add(key,DailyBoard.entry_for(i%3,i%7,i*5,60.0+i))
	var rows=DailyBoard.top(key)
	check(rows.size()==10,"keeps the top 10")
	check(rows[0].score>=rows[9].score,"best first")
	check(DailyBoard.place(key,rows[0].score+1)==1,"a better score takes first place")
	check(FileAccess.file_exists(dir.path_join("daily_board.json")),"board file next to profiles, in the temp folder")
	Game.save_enabled=false
	Game.profiles.active=2
	if 1 not in Game.progression.cleared_worlds:Game.progression.cleared_worlds.append(1)
	var picker=load("res://scripts/ui/world_select.gd").new();add_child(picker);await get_tree().create_timer(.6).timeout
	var board=picker.find_child("DailyBoard",true,false)
	check(board!=null,"world card has the table button")
	if board:board.pressed.emit()
	await get_tree().create_timer(.4).timeout
	check(picker.has_node("DailyBoardView"),"table opens")
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-daily-board.png")
	var esc=InputEventAction.new();esc.action="pause";esc.pressed=true;picker._input(esc);await get_tree().process_frame
	check(not picker.has_node("DailyBoardView") and is_instance_valid(picker),"Esc closes only the table")
	for file in DirAccess.get_files_at(dir):DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
	print("DAILY BOARD: %d failures" % failures);get_tree().quit(1 if failures else 0)
