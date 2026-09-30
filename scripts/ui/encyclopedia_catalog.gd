extends RefCounted
static func entries()->Array:return Texts.document.articles
static func normalized(value:String)->String:return value.to_lower().replace("ё","е").strip_edges()
static func sections(category:String)->Array:
	var result=["Все подразделы"]
	for c in Texts.document.get("categories",[]):
		if category=="Все" or c.name==category:
			for section in c.sections:
				if section.name not in result:result.append(section.name)
	for entry in entries():
		if (category=="Все" or entry.category==category) and entry.section not in result:result.append(entry.section)
	return result
static func search(query:String,category:String="Все",section:String="Все подразделы")->Array:
	var result=[]
	var words=normalized(query).split(" ",false)
	for entry in entries():
		if category!="Все" and entry.category!=category:continue
		if section!="Все подразделы" and entry.section!=section:continue
		var haystack=normalized(Texts.render(entry.title+" "+entry.text+" "+entry.category+" "+entry.section)+( " "+Texts.term_name(entry.term)+" "+Texts.description(entry.term) if entry.term!="" else ""))
		var matches=true
		for word in words:
			if not haystack.contains(word):matches=false;break
		if matches:result.append(entry)
	return result

static func categories()->Array:
	var result=["Все"]
	for c in Texts.document.get("categories",[]):result.append(c.name)
	for entry in entries():
		if entry.category not in result:result.append(entry.category)
	return result
