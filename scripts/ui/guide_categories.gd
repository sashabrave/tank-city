extends RefCounted
static func fallback_category()->String:
	for category in Texts.document.categories:
		if category.builtin:return category.name
	return "Основы"
static func sync(draft:Dictionary):
	if not draft.has("categories"):draft.categories=[]
	for article in draft.articles:
		var category=draft.categories.filter(func(c):return c.name==article.category)
		if category.is_empty():
			draft.categories.append({"name":article.category,"builtin":false,"sections":[]});category=[draft.categories.back()]
		if not category[0].sections.any(func(s):return s.name==article.section):category[0].sections.append({"name":article.section,"builtin":false})
static func edit(action:String,name:String,parent:String="",value:String="",path:String=Texts.PATH)->String:
	var draft=Texts.document.duplicate(true);sync(draft)
	var list=draft.categories
	if parent!="":
		var matches=list.filter(func(c):return c.name==parent)
		if matches.is_empty():return "Раздел не найден."
		list=matches[0].sections
	var found=list.filter(func(c):return c.name==name)
	value=value.strip_edges()
	if action in ["add","rename"]:
		if value.is_empty() or value.length()>36 or value in ["Все","Все подразделы"]:return "Название: от 1 до 36 символов."
		if list.any(func(c):return c.name.to_lower()==value.to_lower() and (action=="add" or c.name!=name)):return "Такое название уже есть."
	if action=="add":
		var entry={"name":value,"builtin":false}
		if parent=="":entry.sections=[]
		list.append(entry)
	elif action=="rename":
		if found.is_empty():return "Категория не найдена."
		found[0].name=value
		for article in draft.articles:
			if parent=="" and article.category==name:article.category=value
			elif article.category==parent and article.section==name:article.section=value
	elif action=="delete":
		if found.is_empty() or found[0].builtin:return "Удалять можно только созданные в Edit dev категории."
		list.erase(found[0])
		for article in draft.articles:
			if (parent=="" and article.category==name) or (article.category==parent and article.section==name):
				article.category=fallback_category() if parent=="" else parent;article.section="Без подраздела"
	else:return "Неизвестное действие."
	sync(draft)
	return Texts.save_document(draft,path)
