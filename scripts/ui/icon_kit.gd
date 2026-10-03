class_name IconKit
## Static icon symbols (guides/03_release/07_icon_kit_brief.md): data/icon_kit.json maps an icon id to one drawn
## symbol in assets/ui/icon_kit/symbols — no plates, frames or layers. Ids without a drawn symbol use the old lookup.
const ROOT:="res://assets/ui/icon_kit/symbols/"
static var data:Dictionary={}

static func table()->Dictionary:
	if data.is_empty():
		var file=FileAccess.open("res://data/icon_kit.json",FileAccess.READ)
		var parsed=JSON.parse_string(file.get_as_text()) if file else null
		data=parsed if parsed is Dictionary else {"icons":{}}
	return data

static func has(id:String)->bool:
	return table().icons.has(id) and ResourceLoader.exists(ROOT+str(table().icons[id])+".png")

static func symbol(id:String)->Texture2D:
	return load(ROOT+str(table().icons[id])+".png") if has(id) else null
