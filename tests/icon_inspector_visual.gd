extends Node3D
## Icon inspector (scripts/tools/icon_inspector.gd): right click on a run-card icon opens its card with the name
## from data/icon_catalog.json; «На доску задач» files a task. The board is redirected to a temporary folder.
## Window shot /tmp/r13-icon-inspector.png. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Campaign.configure(1)
	var temp=OS.get_user_data_dir().path_join("icon_inspector_test_%d" % Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(temp)
	TaskBoard.repo_path=temp.path_join("board.json");TaskBoard.inbox_path=temp.path_join("inbox.json");TaskBoard.shots_dir=temp.path_join("shots");TaskBoard.repo_shots_dir=temp.path_join("repo_shots")
	get_window().size=Vector2i(1600,900)
	var arena=load("res://scenes/arena.tscn").instantiate();arena.run_seed=4;add_child(arena);arena.auto_pause_enabled=false
	await get_tree().create_timer(1.0).timeout;arena.set_physics_process(false)
	arena.room.upgrade_offers=[{"id":"health","tier":1},{"id":"burn_long","tier":2},{"id":"luck","tier":0}]
	arena.hud._show_upgrades_now()
	await get_tree().create_timer(1.0).timeout
	var icon:TextureRect=arena.hud.modal.find_children("Icon","TextureRect",true,false)[0]
	var inspector=get_tree().root.get_node("IconInspector")
	var point=icon.get_global_rect().get_center()
	var hit=inspector.picture_at(point)
	check(hit.get("node")==icon,"right click finds the card icon")
	var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_RIGHT;click.pressed=true;click.position=point;click.global_position=point
	Input.parse_input_event(click)
	await get_tree().create_timer(.3).timeout
	check(inspector.root!=null,"inspector window opens")
	var texts=inspector.root.find_children("*","Label",true,false).map(func(l):return l.text)
	check(texts.any(func(t):return "Здоровье" in t),"shows the catalogue name (Здоровье)")
	check(texts.any(func(t):return "upgrades/health" in t),"shows the id")
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-icon-inspector.png")
	inspector.note_edit.text="Сердце крупнее"
	inspector.send()
	await get_tree().process_frame
	var tasks=TaskBoard.tasks()
	check(tasks.size()==1 and "Здоровье" in str(tasks[0].title) and "Сердце крупнее" in str(tasks[0].get("note","")),"task filed with the name and the comment")
	check(inspector.root==null and not get_tree().paused,"window closed, game resumed")
	print("ICON INSPECTOR: %d failures" % failures);get_tree().quit(1 if failures else 0)
