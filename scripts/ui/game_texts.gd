extends Node
signal changed
const PATH="res://data/encyclopedia.json"
var document:Dictionary={}
var replacements:Array=[]
var revision=0
var language="ru"
var localization=preload("res://scripts/ui/localization.gd").new()
func set_language(value:String):
	if language==value:return
	language=value;revision+=1;changed.emit()
func localized(value:String)->String:return localization.render(value) if language=="en" else value
var tooltips:Dictionary={}
func _init():
	document=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	rebuild()
func dev_enabled()->bool:return OS.has_feature("editor") or OS.has_feature("dev")
func term_name(id:String)->String:return document.terms.get(id,{}).get("name",id)
func description(id:String)->String:return document.terms.get(id,{}).get("description","")
func rebuild():
	replacements.clear();tooltips.clear();revision+=1
	for id in document.terms:
		var term=document.terms[id]
		tooltips[term.source.to_lower()]=term.description
		if term.name==term.source:continue
		var pattern=RegEx.new();pattern.compile("(?<![А-Яа-яЁёA-Za-z])(?:"+term.source+"|"+term.source.to_upper()+"|"+term.source.to_lower()+")(?![А-Яа-яЁёA-Za-z])")
		replacements.append({"pattern":pattern,"name":term.name})
func render(value:String)->String:
	for id in (document.terms if "{{" in value else {}):
		value=value.replace("{{"+id+".description}}",description(id)).replace("{{"+id+".name}}",term_name(id))
	# Single pass over original text prevents replacements cascading into other terms.
	var matches=[]
	for replacement in replacements:
		for found in replacement.pattern.search_all(value):
			var original=found.get_string();var name=replacement.name
			if original==original.to_upper():name=name.to_upper()
			elif original==original.to_lower():name=name.to_lower()
			matches.append({"start":found.get_start(),"end":found.get_end(),"text":name})
	matches.sort_custom(func(a,b):return a.start>b.start)
	for found in matches:value=value.substr(0,found.start)+found.text+value.substr(found.end)
	return SentenceCase.normalize(NumberDisplay.clean(localized(value)))
# Dynamic labels are formatted before assignment, so layout never sees a temporary case/language.
func set_text(node:Node,value:String):
	if node is LineEdit or node is TextEdit:
		node.text=value;return
	var parent=node
	while parent!=null:
		if parent.has_meta("text_editor"):node.text=value;return
		parent=parent.get_parent()
	var rendered=render(value)
	node.set_meta("text_source",value);node.set_meta("text_rendered",rendered);node.set_meta("text_revision",revision)
	if node.text!=rendered:node.text=rendered
func update_widget(node):
	if not node is OptionButton and node.get_meta("text_revision",-1)==revision and node.text==node.get_meta("text_rendered",null):return
	var parent=node
	while parent!=null:
		if parent.has_meta("text_editor"):return
		parent=parent.get_parent()
	if node is OptionButton:
		for i in range(node.item_count):
			var key="locale_item_"+str(i);var original_item=node.get_meta(key,node.get_item_text(i));node.set_meta(key,original_item);node.set_item_text(i,localized(original_item))
		return
	var current=node.text
	var original=node.get_meta("text_source",current)
	if current!=node.get_meta("text_rendered",current):original=current
	var rendered=render(original)
	if node is Control and tooltips.has(original.to_lower()):node.tooltip_text=render(tooltips[original.to_lower()])
	node.set_meta("text_revision",revision)
	node.set_meta("text_source",original);node.set_meta("text_rendered",rendered)
	if current!=rendered:node.text=rendered
func update_hints(node:Control):
	var parent:Node=node
	while parent!=null:
		if parent.has_meta("text_editor"):return
		parent=parent.get_parent()
	for key in (["tooltip_text","placeholder_text"] if node is LineEdit or node is TextEdit else ["tooltip_text"]):
		var current:String=node.get(key)
		var source:String=node.get_meta("source_"+key,current)
		if current!=node.get_meta("rendered_"+key,current):source=current
		var result=render(source)
		node.set_meta("source_"+key,source);node.set_meta("rendered_"+key,result)
		if result!=current:node.set(key,result)
func validate(draft:Dictionary)->String:
	if not draft.has("articles") or not draft.has("terms"):return "Нет статей или словаря."
	var ids={}
	for article in draft.articles:
		for key in ["id","category","section","title","text","image","term"]:
			if not article.has(key) or not article[key] is String:return "Некорректное поле статьи: "+key
		if article.id in ids or article.id.is_empty():return "Повторяющийся или пустой ID."
		ids[article.id]=true
		if article.category.strip_edges().is_empty() or article.section.strip_edges().is_empty() or article.title.strip_edges().is_empty() or article.text.strip_edges().is_empty():return "Заголовок и текст не должны быть пустыми."
		if article.term!="" and not draft.terms.has(article.term):return "Неизвестный общий термин."
	for term in draft.terms.values():
		if term.name.strip_edges().is_empty() or term.description.strip_edges().is_empty():return "Заполни название и короткое описание."
		if term.name.length()>48 or term.description.length()>150:return "Название — до 48 символов, короткое описание — до 150."
	return ""
func save_document(draft:Dictionary,path:String=PATH)->String:
	if not dev_enabled():return "Редактирование доступно только в dev-сборке."
	preload("res://scripts/ui/guide_categories.gd").sync(draft)
	var error=validate(draft)
	if error!="":return error
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return "Не удалось записать файл: "+str(FileAccess.get_open_error())
	file.store_string(JSON.stringify(draft,"  ")+"\n");file.flush();var write_error=file.get_error();file.close()
	if write_error!=OK:return "Ошибка записи: "+str(write_error)
	if FileAccess.file_exists(path):
		var backup=DirAccess.copy_absolute(path,path+".bak")
		if backup!=OK:return "Не удалось сохранить резервную копию."
	var result=DirAccess.rename_absolute(path+".tmp",path)
	if result!=OK:return "Не удалось заменить файл: "+str(result)
	document=draft.duplicate(true);rebuild();changed.emit();return ""
