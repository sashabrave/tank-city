class_name IconKit
## Layered icon kit (guides/03_release/07_icon_kit_brief.md). data/icon_kit.json maps an icon id to its group
## base (aura, face, rim), its symbol and an optional modifier badge; the PNG layers live in assets/ui/icon_kit.
## Every layer rect is given in a unit square, so the same kit draws at any size.
const ROOT:="res://assets/ui/icon_kit/"
static var data:Dictionary={}
static var flat_cache:Dictionary={}

static func table()->Dictionary:
	if data.is_empty():
		var file=FileAccess.open("res://data/icon_kit.json",FileAccess.READ)
		var parsed=JSON.parse_string(file.get_as_text()) if file else null
		data=parsed if parsed is Dictionary else {"icons":{},"groups":{},"badge":[.79,.77,.38]}
	return data

static func has(id:String)->bool:return table().icons.has(id)

## Layers bottom to top: [{kind, texture, rect}]. Kinds: aura, face, symbol, rim, badge.
static func layers(id:String)->Array:
	var entry:Dictionary=table().icons.get(id,{})
	if entry.is_empty():return []
	var group:Dictionary=table().groups.get(entry.group,{})
	var variant=str(entry.get("variant",""))
	var full=Rect2(0,0,1,1)
	var out=[]
	for kind in ["aura","face"]:
		if group.has(kind):out.append({"kind":kind,"texture":texture("kit/"+str(group[kind]).replace("{variant}",variant)),"rect":full})
	var place:Array=group.get("symbol",[.5,.5,.6])
	var symbol=texture("symbols/"+str(entry.symbol))
	# A bare symbol (no plate, e.g. abilities) is cropped to its visible pixels, so uneven transparent margins
	# in the source do not push it off centre (T-102).
	if not group.has("face") and symbol:symbol=UiKit.trimmed(symbol)
	out.append({"kind":"symbol","texture":symbol,"rect":Rect2(place[0]-place[2]*.5,place[1]-place[2]*.5,place[2],place[2])})
	if group.has("rim"):out.append({"kind":"rim","texture":texture("kit/"+str(group.rim).replace("{variant}",variant)),"rect":full})
	if entry.has("badge"):
		var badge:Array=table().badge
		out.append({"kind":"badge","texture":texture("badges/"+str(entry.badge)),"rect":Rect2(badge[0]-badge[2]*.5,badge[1]-badge[2]*.5,badge[2],badge[2])})
	return out.filter(func(layer):return layer.texture!=null)

static func texture(relative:String)->Texture2D:
	var path=ROOT+relative+".png"
	return load(path) if ResourceLoader.exists(path) else null

## One flattened picture without the aura, for the few places that need image data (3D sprites). It costs
## ~14 ms per icon, so the interface uses KitTexture (draws the layers directly) and KitIcon instead.
static func flat(id:String,side:=256)->Texture2D:
	if flat_cache.has(id):return flat_cache[id]
	var image=Image.create(side,side,false,Image.FORMAT_RGBA8)
	for layer in layers(id):
		if layer.kind=="aura":continue
		var source:Image=layer.texture.get_image()
		if source==null:continue
		if source.is_compressed():source.decompress()
		source.convert(Image.FORMAT_RGBA8)
		var rect:Rect2=layer.rect
		var size=Vector2i(maxi(1,roundi(rect.size.x*side)),maxi(1,roundi(rect.size.y*side)))
		source.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
		image.blend_rect(source,Rect2i(Vector2i.ZERO,size),Vector2i(roundi(rect.position.x*side),roundi(rect.position.y*side)))
	var result=ImageTexture.create_from_image(image)
	flat_cache[id]=result
	return result
