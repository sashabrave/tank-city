extends Node
## Tester task board: add, move, inbox of an exported build, board and quick form UI.
## All files go to a fresh temporary folder. Window shots /tmp/r13-board-*.png.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func shot(path):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png(path)
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	get_window().size=Vector2i(1600,900)
	var dir="user://test_board_%d" % Time.get_ticks_usec()
	var B=TaskBoard
	B.repo_path=dir.path_join("board.json");B.inbox_path=dir.path_join("inbox.json");B.shots_dir=dir.path_join("shots");B.repo_shots_dir=dir.path_join("repo_shots")
	B.write_json(B.repo_path,{"next_id":1,"tasks":[]})
	var image=Image.create(64,32,false,Image.FORMAT_RGBA8);image.fill(Color.ORANGE)
	var a=B.add("Враги стреляют через полублок","у базы","bug",1,image)
	check(a.id=="T-001" and B.column("backlog").size()==1,"task added to the project board")
	check(FileAccess.file_exists(a.shot),"screenshot saved with the task")
	check(B.move(a.id,"doing") and B.column("doing").size()==1 and B.column("backlog").is_empty(),"task moves between columns")
	B.add("Вопрос про ящик","","question",3)
	B.add("Важная идея","","idea",1)
	check(B.column("backlog")[0].type=="question","questions to the developer come first")
	# Exported build: the pack is read-only, so new tasks and moves go to the inbox.
	B.force_inbox=true
	var b=B.add("Из сборки","","polish",2,image)
	B.move(a.id,"review")
	check(b.id.begins_with("I-") and B.inbox().size()==2,"exported build writes to the inbox")
	check(B.tasks().any(func(t):return t.id==b.id) and B.column("review").any(func(t):return t.id==a.id),"inbox shows on the board")
	check(B.repo().tasks.size()==3,"project board untouched by the exported build")
	B.force_inbox=false
	# UI: board columns, then the quick form saves a task.
	preload("res://scripts/ui/task_board_view.gd").open(get_tree(),"board")
	await get_tree().create_timer(.4).timeout
	var view=get_tree().root.get_node_or_null("TaskBoardView")
	check(view!=null and get_tree().paused,"board opens and pauses the game")
	check(view.find_child("Column_backlog",true,false)!=null and view.find_child("Task_T-001",true,false)!=null,"columns and cards render")
	await shot("/tmp/r13-board-columns.png")
	view.find_child("AddTask",true,false).pressed.emit();await get_tree().process_frame
	view.title_edit.text="Новая из формы";view.save();await get_tree().process_frame
	check(B.column("backlog").any(func(t):return t.title=="Новая из формы") and view.mode=="board","quick form adds to the backlog")
	await shot("/tmp/r13-board-after.png")
	view.close();await get_tree().process_frame
	check(not get_tree().paused,"closing resumes the game")
	for sub in ["shots","repo_shots",""]:
		var d=dir.path_join(sub)
		for f in DirAccess.get_files_at(d):DirAccess.remove_absolute(d.path_join(f))
		DirAccess.remove_absolute(d)
	print("TASK BOARD: %d failures" % failures);get_tree().quit(1 if failures else 0)
