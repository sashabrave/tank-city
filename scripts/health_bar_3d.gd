extends Sprite3D
var ratio=1.0
var rank=0
var rendered_key=Vector2i(-1,-1)
## Frame colour, e.g. the bonus a thief carries (T-072); transparent — the usual dark frame.
var accent:=Color.TRANSPARENT
func _ready():
	billboard=BaseMaterial3D.BILLBOARD_ENABLED
	pixel_size=.009
	no_depth_test=true
	shaded=false
func set_health(value: float,maximum: float):
	ratio=clampf(value/maxf(maximum,.001),0,1)
	var key=Vector2i(roundi(ratio*92),rank)
	if key==rendered_key:return
	rendered_key=key
	var img=Image.create(96,12,false,Image.FORMAT_RGBA8)
	img.fill(Color("26332c") if accent.a<=0 else accent)
	img.fill_rect(Rect2i(2,2,92,8),Color("aeb8a4"))
	var color=Color("d85b50").lerp(Color("e4bb54"),ratio*2) if ratio<.5 else Color("e4bb54").lerp(Color("6ba064"),(ratio-.5)*2)
	if ratio>0:img.fill_rect(Rect2i(2,2,maxi(1,roundi(92*ratio)),8),color)
	if rank>0:
		var combined=Image.create(96+rank*9+4,12,false,Image.FORMAT_RGBA8);combined.fill(Color.TRANSPARENT);combined.blit_rect(img,Rect2i(0,0,96,12),Vector2i(rank*9+4,0))
		for badge in range(rank):
			for x in range(5):
				combined.set_pixel(2+badge*9+x,2+x,Color("ffd082"));combined.set_pixel(2+badge*9+x,10-x,Color("ffd082"))
		img=combined
	texture=ImageTexture.create_from_image(img)
