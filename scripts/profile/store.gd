extends RefCounted
## No destructive writes to the main file until a complete replacement exists.
static func read_json(path:String,validator:Callable=Callable())->Dictionary:
	if not FileAccess.file_exists(path):return {"ok":false,"error":"missing"}
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK:return {"ok":false,"error":"Повреждён JSON"}
	var parsed=parser.data
	if not parsed is Dictionary:return {"ok":false,"error":"Повреждён JSON"}
	if validator.is_valid():return validator.call(parsed)
	return {"ok":true,"data":parsed}
static func load_file(path:String,validator:Callable=Callable())->Dictionary:
	var result=read_json(path,validator)
	if result.ok:return result
	# Never downgrade a profile written by a newer game version.
	if result.get("future",false):return result
	var backup=read_json(path+".bak",validator)
	if backup.ok:backup["recovered"]=true;return backup
	return result
static func write_file(path:String,data:Dictionary,validator:Callable=Callable())->Dictionary:
	var absolute=ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())!=OK:return {"ok":false,"error":"Не удалось создать папку сохранений"}
	var temp=path+".tmp"
	var file=FileAccess.open(temp,FileAccess.WRITE)
	if file==null:return {"ok":false,"error":"Не удалось открыть временный файл"}
	file.store_string(JSON.stringify(data));file.flush()
	var error=file.get_error();file.close()
	if error!=OK:return {"ok":false,"error":"Не удалось записать сохранение"}
	var checked=read_json(temp,validator)
	if not checked.ok:return checked
	var previous=read_json(path,validator)
	if previous.get("future",false):return previous
	# A corrupt main must not replace its last good backup.
	if previous.ok:
		if DirAccess.copy_absolute(absolute,absolute+".bak.tmp")!=OK:return {"ok":false,"error":"Не удалось создать резервную копию"}
		if DirAccess.rename_absolute(absolute+".bak.tmp",absolute+".bak")!=OK:return {"ok":false,"error":"Не удалось обновить резервную копию"}
	if not FileAccess.file_exists(path+".bak"):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(temp),absolute+".bak")!=OK:return {"ok":false,"error":"Не удалось создать первую резервную копию"}
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),absolute)!=OK:return {"ok":false,"error":"Не удалось заменить сохранение"}
	return {"ok":true}
