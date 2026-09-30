extends Control
var view
var article_id=""
var save_path=Texts.PATH
var new_article:Dictionary={}
var fields:Dictionary={}
var status:Label
var dirty=false
static func open(owner,entry_id:String):
	if not Texts.dev_enabled():return
	var editor=load("res://scripts/ui/encyclopedia_editor.gd").new();editor.view=owner;editor.article_id=entry_id;owner.add_child(editor)
static func open_new(owner):
	if not Texts.dev_enabled():return
	var editor=load("res://scripts/ui/encyclopedia_editor.gd").new();editor.view=owner
	editor.article_id="custom_"+str(Time.get_unix_time_from_system()).replace(".","_")+"_"+str(Time.get_ticks_usec())
	editor.new_article={"id":editor.article_id,"category":preload("res://scripts/ui/guide_categories.gd").fallback_category() if owner.guide_category=="Все" else owner.guide_category,"section":"Без подраздела" if owner.guide_section=="Все подразделы" else owner.guide_section,"title":"Новая статья","text":"","image":"","term":""}
	owner.add_child(editor)
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);set_meta("text_editor",true);add_to_group("selection_scope")
	var dim=ColorRect.new();add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,0,0,.7)
	var panel=UiKit.glass(self,(get_viewport_rect().size-Vector2(930,690))*.5,Vector2(930,690))
	UiKit.label(panel,"Редактор · DEV",Vector2(24,16),Vector2(860,40),24)
	var entry=new_article if not new_article.is_empty() else Texts.document.articles.filter(func(a):return a.id==article_id)[0]
	var linked=entry.term!=""
	UiKit.label(panel,"Общий термин: название и краткое описание обновятся в игре." if linked else "Статья энциклопедии. Правки вступят в силу после сохранения.",Vector2(24,61),Vector2(880,28),15,UiKit.MUTED)
	add_field(panel,"title","Заголовок статьи",entry.title,100)
	if linked:
		add_field(panel,"term_name","Название во всей игре",Texts.term_name(entry.term),153)
		add_field(panel,"description","Короткое описание для карточек",Texts.description(entry.term),206)
	else:
		add_field(panel,"category","Раздел",entry.category,153)
		add_field(panel,"section","Подраздел",entry.section,206)
	add_field(panel,"image","Картинка · res://… (необязательно)",entry.image,259)
	UiKit.label(panel,"Текст статьи",Vector2(24,315),Vector2(850,28),16)
	var body=TextEdit.new();panel.add_child(body);body.position=Vector2(24,350);body.size=Vector2(882,206);body.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;body.text=entry.text;body.add_theme_font_size_override("font_size",17);body.text_changed.connect(func():dirty=true);fields.text=body
	status=UiKit.label(panel,"Сохранение: data/encyclopedia.json · предыдущая версия остаётся в .bak",Vector2(24,565),Vector2(882,45),14,UiKit.MUTED);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	UiKit.button(panel,"Отмена · без сохранения",Vector2(24,622),Vector2(410,42),queue_free).add_theme_font_size_override("font_size",16)
	UiKit.button(panel,"Сохранить и применить",Vector2(450,622),Vector2(456,42),save,true).add_theme_font_size_override("font_size",16)
func add_field(panel,key:String,title:String,value:String,y:int):
	UiKit.label(panel,title,Vector2(24,y),Vector2(325,36),16)
	var input=LineEdit.new();panel.add_child(input);input.position=Vector2(357,y);input.size=Vector2(549,38);input.text=value;input.add_theme_font_size_override("font_size",17);input.text_changed.connect(func(_v):dirty=true);fields[key]=input
func save():
	var draft=Texts.document.duplicate(true)
	if not new_article.is_empty():draft.articles.append(new_article.duplicate(true))
	var entry=draft.articles.filter(func(a):return a.id==article_id)[0]
	for key in ["title","text","image","category","section"]:
		if fields.has(key):entry[key]=fields[key].text.strip_edges()
	if entry.term!="":
		draft.terms[entry.term].name=fields.term_name.text.strip_edges()
		draft.terms[entry.term].description=fields.description.text.strip_edges()
	var error=Texts.save_document(draft,save_path)
	if error!="":status.text=error;return
	view.guide_category="Все";view.guide_section="Все подразделы";view.refresh()
func _input(event):
	if event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if dirty:status.text="Есть несохранённые изменения. Нажми «Сохранить» или «Отмена · без сохранения»."
		else:queue_free()
