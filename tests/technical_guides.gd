extends Node
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	Settings.values.fullscreen=false;Settings.apply()
	var tablet=load("res://scripts/ui/field_tablet.gd").new();tablet.tab="tech";add_child(tablet)
	await get_tree().process_frame
	var view=find_reader(tablet)
	check(view!=null,"technical tab opens")
	if view:
		check(view.documents.size()>=12,"guide folders scanned")
		var path=view.documents.back().path;view.open_document(path);view.reload()
		check(view.selected_path==path and view.body.get_parsed_text().length()>100,"refresh preserves document and reads content")
		# Use a temporary source to test rescan without modifying the user's documents.
		var folder="/tmp/tank-guides-"+str(Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(folder)
		var file=FileAccess.open(folder.path_join("added.md"),FileAccess.WRITE);file.store_string("# Added document\nNew contents");file.close()
		view.documents.clear();view.tree.clear();view.scan(folder,view.tree.create_item(),0)
		check(view.documents.size()==1,"new folder structure discovered")
		view.open_document(view.documents[0].path);check("New contents" in view.body.get_parsed_text(),"new document readable")
		view.reload()
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://screenshots/technical-guides.png")
	tablet.queue_free();await get_tree().process_frame
	print("TECHNICAL GUIDES: ",failures," failures");get_tree().quit(failures)
func find_reader(node):
	if node.get_script()==load("res://scripts/ui/technical_guides.gd"):return node
	for child in node.get_children():
		var found=find_reader(child)
		if found:return found
	return null
