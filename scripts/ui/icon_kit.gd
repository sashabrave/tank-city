class_name IconKit
## Static icon symbols (guides/03_release/07_icon_kit_brief.md): data/icon_kit.json maps an icon id to one drawn
## symbol in assets/ui/icon_kit/symbols — no plates, frames or layers. Ids without a drawn symbol use the old lookup.
const ROOT:="res://assets/ui/icon_kit/symbols/"
## A bare id (no "group/") is looked up in these groups in order, so «fire», «luck» or «hq_tesla» passed without a
## prefix (encyclopedia, older cards, status strip) still get the drawn symbol instead of legacy art.
const GROUP_ORDER:=["upgrades","abilities","stats","headquarters","pickups","building"]
static var data:Dictionary={}
static var resolved:Dictionary={}

static func table()->Dictionary:
	if data.is_empty():
		var file=FileAccess.open("res://data/icon_kit.json",FileAccess.READ)
		var parsed=JSON.parse_string(file.get_as_text()) if file else null
		data=parsed if parsed is Dictionary else {"icons":{}}
	return data

## Symbol file name for an id, or "" when nothing is drawn for it.
static func symbol_name(id:String)->String:
	if resolved.has(id):return resolved[id]
	var icons:Dictionary=table().icons
	var aliases:Dictionary=table().get("aliases",{})
	var name=""
	if icons.has(id):name=str(icons[id])
	elif aliases.has(id):name=str(aliases[id])
	elif not "/" in id:
		for group in GROUP_ORDER:
			if icons.has(group+"/"+id):name=str(icons[group+"/"+id]);break
	if name!="" and not ResourceLoader.exists(ROOT+name+".png"):name=""
	resolved[id]=name
	return name

static func has(id:String)->bool:return symbol_name(id)!=""

static func symbol(id:String)->Texture2D:
	var name=symbol_name(id)
	return load(ROOT+name+".png") if name!="" else null
