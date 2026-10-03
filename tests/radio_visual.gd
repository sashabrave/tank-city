extends Node3D
## Windowed check of the two-pane radio: folder tree, theme folder, archive.
var failures=0
func check(ok:bool,message:String):
	if not ok:failures+=1;push_error("FAIL "+message)
	else:print("PASS "+message)
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS;call_deferred("run")
func shot(path:String):
	await get_tree().create_timer(.5).timeout;RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png(path)
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	var out=OS.get_environment("RADIO_SHOTS") if OS.get_environment("RADIO_SHOTS")!="" else "/tmp"
	Game.music_controller=load("res://scripts/music_controller.gd").new();Game.add_child(Game.music_controller)
	var c=Game.music_controller;c.context="battle";c.pick_battle_theme()
	var layer=CanvasLayer.new();layer.layer=110;add_child(layer)
	var tablet=load("res://scripts/ui/field_tablet.gd").new();tablet.tab="music";layer.add_child(tablet)
	for folder in ["main","theme:"+c.battle_theme,"singles"]:
		tablet.music_folder=folder;tablet.refresh()
		await shot(out+"/radio-"+folder.replace(":","-")+".png")
		var titles=[]
		for node in tablet.find_children("*","Button",true,false):titles.append(node.text)
		if folder.begins_with("theme:"):
			check("Бой" in titles and "Босс" in titles and titles.filter(func(t):return t.begins_with("♪")).is_empty(),"theme folder lists its five tracks, no fanfares")
		elif folder=="singles":check("Азимут" in titles and "Квартет" in titles,"single tracks listed")
		else:check("Главная тема" in titles and "Полустанок" in titles and "Маяки" in titles,"main theme lists all sub-themes")
	check(not tablet.find_children("*","Button",true,false).any(func(b):return b.text in ["♥","−","Архив","Избранное"]),"no ratings, favourites or archive")
	get_tree().quit(failures)
