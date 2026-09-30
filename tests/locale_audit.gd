extends SceneTree
func _initialize():
	var locale=load("res://scripts/ui/localization.gd").new()
	var candidates=JSON.parse_string(FileAccess.get_file_as_string("res://tmp/locale-candidates.json"))
	var missing=[];var cyrillic=RegEx.new();cyrillic.compile("[А-Яа-яЁё]")
	for source in candidates:
		source=source.replace("\\n","\n")
		var result=locale.render(source)
		if cyrillic.search(result):missing.append({"source":source,"result":result})
	for source in locale.exact:
		if "%" not in source:continue
		var sample:String=source
		var matches=locale.placeholder.search_all(sample);matches.reverse()
		for token in matches:
			var value="Пистолет" if token.get_string().ends_with("s") else "1.25" if token.get_string().ends_with("f") else "3"
			sample=sample.substr(0,token.get_start())+value+sample.substr(token.get_end())
		sample=sample.replace("%%","%")
		var result=locale.render(sample)
		if cyrillic.search(result):missing.append({"source":sample,"result":result})
	var file=FileAccess.open("res://tmp/locale-missing.json",FileAccess.WRITE);file.store_string(JSON.stringify(missing,"  "))
	print("Missing translations: ",missing.size());quit()
