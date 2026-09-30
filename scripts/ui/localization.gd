extends RefCounted
var entries:Array=[]
var exact:Dictionary={}
var cache:Dictionary={}
var placeholder=RegEx.new()
func _init():
	placeholder.compile("%(?:[0-9]+)?(?:\\.[0-9]+)?[dsf]")
	var file=FileAccess.open("res://data/locales/en.tsv",FileAccess.READ)
	while not file.eof_reached():
		var row=file.get_line().split("\t")
		if row.size()!=2 or row[0].is_empty():continue
		row[0]=row[0].replace("\\n","\n");row[1]=row[1].replace("\\n","\n")
		exact[row[0].to_lower()]=row[1]
		var pattern="";var cursor=0;var captures=0
		for token in placeholder.search_all(row[0]):
			pattern+=escape_regex(row[0].substr(cursor,token.get_start()-cursor).replace("%%","%"))
			pattern+="(.+?)" if token.get_string().ends_with("s") else "(-?[0-9]+(?:[.,][0-9]+)?)"
			captures+=1;cursor=token.get_end()
		pattern+=escape_regex(row[0].substr(cursor).replace("%%","%"))
		var regex=RegEx.new();regex.compile("(?i)(?<![a-zа-яё])"+pattern.to_lower()+"(?![a-zа-яё0-9])")
		entries.append({"regex":regex,"output":row[1],"length":row[0].length(),"captures":captures})
	entries.sort_custom(func(a,b):return a.length>b.length)
func escape_regex(value:String)->String:
	var result=""
	for ch in value:
		if ch in "\\.+*?[](){}^$|":result+="\\"
		result+=ch
	return result
func render(source:String,depth:int=0)->String:
	if source in cache:return cache[source]
	if exact.has(source.to_lower()):return exact[source.to_lower()]
	if depth>4:return source
	var edits=[]
	# Match only against the original. Never translate already translated fragments again.
	for entry in entries:
		for found in entry.regex.search_all(source.to_lower()):
			var occupied=false
			for edit in edits:
				if found.get_start()<edit.end and found.get_end()>edit.start:occupied=true;break
			if occupied:continue
			var translated:String=entry.output;var tokens=placeholder.search_all(translated)
			if tokens.size()!=entry.captures:continue
			for i in range(tokens.size()-1,-1,-1):
				var replacement=render(source.substr(found.get_start(i+1),found.get_end(i+1)-found.get_start(i+1)),depth+1)
				translated=translated.substr(0,tokens[i].get_start())+replacement+translated.substr(tokens[i].get_end())
			edits.append({"start":found.get_start(),"end":found.get_end(),"text":translated.replace("%%","%")})
	var result=source
	edits.sort_custom(func(a,b):return a.start>b.start)
	for edit in edits:result=result.substr(0,edit.start)+edit.text+result.substr(edit.end)
	if cache.size()>4096:cache.clear()
	cache[source]=result;return result
