extends Node
var errors=0
func check(value:bool,message:String):
	if not value:errors+=1;push_error(message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	var label=Label.new();add_child(label)
	for language in ["ru","en","ru"]:
		Settings.change("language",language)
		for i in range(40):
			Texts.set_text(label,"пистолет");check(label.text==("Pistol" if language=="en" else "Пистолет"),"Canonical text at assignment")
			var before=label.text;NumberDisplay.refresh();check(label.text==before,"No pre-draw case changes")
	Settings.change("language","en")
	for text in ["База отремонтирована: +1.5 HP","Доставка: 2.5 с · лимит 3","Командир · 420 / 700","+1000 Сплава","Генерал II · 4×4"]:
		var rendered=Texts.render(text);var regex=RegEx.new();regex.compile("[А-Яа-яЁё]");check(regex.search(rendered)==null,"English template: "+rendered)
	check(Texts.render("Генерал II · 4×4")=="General II · 4×4","Roman numerals preserved")
	var hub=load("res://scenes/hub.tscn").instantiate();hub.arrival_reason="wake";add_child(hub)
	await get_tree().create_timer(.7).timeout
	check(hub.phase=="intro","Dialogue blocks hub controls")
	var dialogs=hub.find_children("*","Control",true,false).filter(func(n):return n.get_script()==load("res://scripts/ui/arrival_dialog.gd"))
	check(dialogs.size()==1,"Exactly one arrival dialog")
	if not dialogs.is_empty():dialogs[0].dismiss();check(hub.phase=="combat","Immediate control return")
	hub.queue_free();label.queue_free();await get_tree().process_frame
	print("ARRIVAL/DRONES/TEXT: failures ",errors);get_tree().quit(1 if errors else 0)
