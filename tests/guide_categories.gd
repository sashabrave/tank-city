extends Node
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false
	var original=Texts.document.duplicate(true);var service=preload("res://scripts/ui/guide_categories.gd");var path="/tmp/tank-categories-test.json"
	assert(service.edit("add","","","Тест",path)=="")
	assert(service.edit("add","","","тест",path)!="")
	assert(service.edit("add","","Тест","Раздел",path)=="")
	assert(service.edit("rename","Тест","","Новая категория",path)=="")
	assert(JSON.parse_string(FileAccess.get_file_as_string(path)).categories.any(func(c):return c.name=="Новая категория"))
	var view=load("res://scripts/ui/field_tablet.gd").new();view.tab="guide";view.dev_edit=true;view.nav_collapsed=true;view.guide_category="Новая категория";view.guide_section="Раздел";add_child(view)
	assert(view.content.size.x==932)
	preload("res://scripts/ui/encyclopedia_editor.gd").open_new(view)
	var editor=view.get_child(view.get_child_count()-1);editor.save_path=path;editor.fields.title.text="Проверка";editor.fields.text.text="Сохранённая новая статья";editor.save()
	assert(Texts.document.articles.size()==original.articles.size()+1)
	assert(service.edit("rename","Раздел","Новая категория","Переименован",path)=="")
	assert(Texts.document.articles.back().section=="Переименован")
	assert(service.edit("delete","Новая категория","","",path)=="")
	assert(Texts.document.articles.back().category=="Основы" and Texts.document.articles.back().section=="Без подраздела")
	assert(service.edit("delete","Основы","","",path)!="")
	assert(Texts.document.articles.size()==original.articles.size()+1)
	view.guide_category="Все";view.guide_section="Все подразделы";view.refresh();view.guide_tree.save_path=path
	var header=view.guide_tree.box.find_children("*","Button",true,false).filter(func(b):return b.text=="Основы")[0]
	var double_click=InputEventMouseButton.new();double_click.button_index=MOUSE_BUTTON_LEFT;double_click.pressed=true;double_click.double_click=true
	header.gui_input.emit(double_click)
	var rename=view.guide_tree.box.find_children("*","LineEdit",true,false)[0]
	assert(rename.text=="Основы");rename.text="Базовые правила"
	var ok=rename.get_parent().get_child(1);ok.pressed.emit()
	assert(Texts.document.categories.any(func(c):return c.name=="Базовые правила"))
	Texts.document=original;Texts.rebuild()
	print("PASS category create/rename/duplicate checks/persistence; new article save; rename propagation; custom deletion retains articles; built-ins protected; compact layout")
	get_tree().quit()
