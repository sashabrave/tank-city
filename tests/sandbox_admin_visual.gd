extends Node
## Sandbox admin layout (2026-10-03): every tab at three window sizes — no button wider than the panel, the
## tab list never runs into «Выйти», the random weapon / ammo buttons open the first page. Window only.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func settle():
	for i in range(6):await get_tree().process_frame
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Settings.values.fullscreen=false;Settings.apply()
	Game.profiles.selected=true
	var main=load("res://scenes/main.tscn").instantiate();add_child(main);await settle()
	main.current.sandbox_requested.emit();await settle()
	var arena=main.run_arena;var admin=arena.playground.admin
	var out=OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR")!="" else "/tmp"
	for size in [Vector2i(1600,900),Vector2i(1280,720),Vector2i(960,600)]:
		get_window().size=size;await settle()
		for entry in admin.TABS:
			admin.close_panel();admin.tab=entry[0];admin.tuning="shield" if entry[0]=="class" else "";admin.open_panel();await settle()
			var limit=admin.scroll.size.x
			var wide=admin.body.find_children("*","Button",true,false).filter(func(b):return b.size.x>limit+1)
			check(wide.is_empty(),"%s %dx%d: buttons fit the panel" % [entry[0],size.x,size.y])
			var last=admin.panel.get_node("Tab_"+admin.TABS.back()[0]);var leave=admin.panel.get_node("ExitSandbox")
			check(last.position.y+last.size.y<=leave.position.y,"%s %dx%d: tabs above «Выйти»" % [entry[0],size.x,size.y])
			if entry[0]=="field":check(admin.body.find_child("RandomWeapon",true,false)!=null and admin.body.find_child("RandomAmmo",true,false)!=null,"random weapon and ammo on the first page")
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/admin-%s-%d.png" % [out,entry[0],size.x])
	admin.close_panel();admin.tab="field";admin.open_panel();await settle()
	var before=arena.room.pickups.size();admin.body.find_child("RandomWeapon",true,false).pressed.emit();admin.body.find_child("RandomAmmo",true,false).pressed.emit()
	check(arena.room.pickups.size()==before+2,"both random events drop an item from the HQ")
	print("ADMIN VISUAL: %d failures" % failures);get_tree().quit(1 if failures else 0)
