extends RefCounted
# Player-facing list of changes. Newest entries first; each entry holds its own ru/en text.
const PATH="res://data/changelog.json"
static func entries()->Array:
	if not FileAccess.file_exists(PATH):return []
	var data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary or not data.get("entries") is Array:return []
	var result=data.entries.filter(func(entry):return entry is Dictionary and entry.get("ru") is Dictionary)
	result.sort_custom(func(a,b):return str(a.get("date",""))>str(b.get("date","")))
	return result
static func date_text(value:String)->String:
	var parts=value.split("-")
	if parts.size()!=3:return value
	return "%s.%s.%s" % [parts[2],parts[1],parts[0]]
## Releases for the version tabs, newest first; entries without a version fall into "earlier".
static func versions()->Array:
	var seen=[]
	for entry in entries():
		var v=str(entry.get("version","earlier"))
		if v not in seen:seen.append(v)
	seen.sort_custom(func(a,b):
		if a=="earlier":return false
		if b=="earlier":return true
		var pa=a.split(".");var pb=b.split(".")
		for i in range(maxi(pa.size(),pb.size())):
			var x=int(pa[i]) if i<pa.size() else 0;var y=int(pb[i]) if i<pb.size() else 0
			if x!=y:return x>y
		return false)
	return seen
static func for_version(version:String)->Array:
	return entries().filter(func(e):return str(e.get("version","earlier"))==version)

