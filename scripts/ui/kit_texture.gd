class_name KitTexture extends Texture2D
## A kit icon as one texture: draws its layers (without the aura) straight from the layer textures, so
## nothing is composited in memory. Used where a single texture is expected (button icons, plain rects);
## KitIcon animates the same layers separately. No image data: get_image() is empty, 3D sprites need flat().
var layers:Array=[]
const SIDE:=256

static func make(id:String)->KitTexture:
	var texture=KitTexture.new()
	texture.layers=IconKit.layers(id).filter(func(layer):return layer.kind!="aura")
	return texture

func _get_width()->int:return SIDE
func _get_height()->int:return SIDE
func _has_alpha()->bool:return true
func _is_pixel_opaque(_x:int,_y:int)->bool:return false

func _draw(to_canvas_item:RID,pos:Vector2,modulate:Color,transpose:bool):
	_draw_rect(to_canvas_item,Rect2(pos,Vector2(SIDE,SIDE)),false,modulate,transpose)

func _draw_rect(to_canvas_item:RID,rect:Rect2,_tile:bool,modulate:Color,transpose:bool):
	for layer in layers:
		var unit:Rect2=layer.rect
		var target=Rect2(rect.position+unit.position*rect.size,unit.size*rect.size)
		layer.texture.draw_rect(to_canvas_item,target,false,modulate,transpose)

func _draw_rect_region(to_canvas_item:RID,rect:Rect2,src_rect:Rect2,modulate:Color,transpose:bool,_clip_uv:bool):
	# Regions are only used for trimming, which kit textures skip; map the region onto the full square.
	var scale=rect.size/src_rect.size
	_draw_rect(to_canvas_item,Rect2(rect.position-src_rect.position*scale,Vector2(SIDE,SIDE)*scale),false,modulate,transpose)
