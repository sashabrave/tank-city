extends Control
## Class portraits from the v16 atlas. The old class gallery screen was replaced by the Barracks station
## (scripts/ui/stations/fighter_station.gd); only the pictures are left here.
const IDS=["recruit","gunner","driver","heavy","marksman","engineer"]
static func texture(id:String,mini=false)->AtlasTexture:
	var index=IDS.find(id);var atlas=AtlasTexture.new();atlas.atlas=Illustrations.texture("res://assets/portraits/v16/"+("miniatures.png" if mini else "portraits.png"));var size=atlas.atlas.get_size()/Vector2(3,2)
	var cell=Rect2(Vector2(index%3,floori(index/3.0))*size,size)
	# Interface portraits are chest-up: a centred square over the helmet and chest of the full-figure art.
	if not mini:cell=Rect2(cell.position+size*Vector2(PORTRAIT_CROP.x,PORTRAIT_CROP.y),size*PORTRAIT_CROP.z)
	atlas.region=cell;return atlas
## Chest-up crop inside a portrait cell: left, top, side (fractions of the cell).
const PORTRAIT_CROP=Vector3(.17,.03,.66)
func picture(parent,id,pos,dimensions,mini=false):
	var image=TextureRect.new();parent.add_child(image);image.texture=texture(id,mini);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.position=pos;image.size=dimensions;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;UiKit.locked_preview(image,id not in Game.class_unlocks)
