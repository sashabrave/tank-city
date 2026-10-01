extends CanvasLayer
## Small rotating refresh icon in the top-right corner, left of the profile button, while the profile is written.
## Purely visual: never touches game RNG or timing.
const SIZE=26.0
const HOLD=1.1
var icon:TextureRect
var left=0.0
func _ready():
	layer=120;process_mode=Node.PROCESS_MODE_ALWAYS
	icon=TextureRect.new();icon.name="SaveIcon";icon.texture=UiKit.icon_texture("refresh")
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size=Vector2(SIZE,SIZE);icon.pivot_offset=icon.size/2;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	icon.modulate=Color(UiKit.ORANGE,0);add_child(icon);place()
	get_viewport().size_changed.connect(place)
func place():
	if is_instance_valid(icon):icon.position=Vector2(get_viewport().get_visible_rect().size.x-62-10-SIZE,17)
func pulse():left=HOLD
func _process(delta):
	if not is_instance_valid(icon) or (left<=0 and icon.modulate.a<=0):return
	left=maxf(0,left-delta)
	icon.rotation+=delta*TAU*1.1
	var target=.85 if left>0 else 0.0
	icon.modulate=Color(UiKit.ORANGE,move_toward(icon.modulate.a,target,delta*4))
