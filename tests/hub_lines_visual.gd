extends Node
## Hub greeting: key caps, «Ещё» shows three more lines, then the closing line leaves only «Продолжить».
## Window run saves /tmp/r13-hub-lines-*.png. No profile or settings writes.
var failures=0
func check(ok,message):
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func _ready():call_deferred("run")
func shot(name:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;get_viewport().get_texture().get_image().save_png("/tmp/r13-hub-lines-"+name+".png")
func run():
	Game.save_enabled=false;Settings.persistence_enabled=false;Game.sound_enabled=false
	var Lines=preload("res://scripts/ui/hub_lines.gd")
	var dashes=(Lines.STORIES+Lines.TIPS).filter(func(l):return "—" in l)
	check(dashes.is_empty(),"no long dashes in hub lines")
	check(Lines.STORIES.size()>=20 and Lines.TIPS.size()>=50,"20 stories and 50+ tips")
	var dialog=preload("res://scripts/ui/arrival_dialog.gd").new();add_child(dialog)
	# Force a line with keys to check the caps.
	dialog.show_line(Lines.TIPS[0]);await get_tree().process_frame;await get_tree().process_frame
	check(dialog.words.find_children("Key","Panel",true,false).size()==2,"two key caps in the trench tip")
	check(dialog.answers[0].visible and dialog.answers[1].visible,"«Ещё» and «Продолжить» visible")
	for i in 20:await get_tree().process_frame
	await shot("keys")
	for i in 3:dialog.more()
	for i in 30:await get_tree().process_frame
	check(not dialog.answers[0].visible,"after three more lines «Ещё» is gone")
	var text=" ".join(dialog.words.get_children().map(func(s):return s.get_child(-1).text))
	check(text==Texts.render(Lines.ENOUGH),"closing line sends to battle")
	await shot("enough")
	Texts.set_language("en");dialog.show_line(Lines.TIPS[4]);for i in 30:await get_tree().process_frame
	check(dialog.words.find_children("Key","Panel",true,false).size()==3,"English line keeps three key caps")
	var en=" ".join(dialog.words.get_children().map(func(s):return s.get_child(-1).text));check(en.begins_with("Ability on"),"English line is translated: "+en)
	await shot("en");Texts.set_language("ru")
	print("HUB LINES: %d failures" % failures);get_tree().quit(1 if failures else 0)
