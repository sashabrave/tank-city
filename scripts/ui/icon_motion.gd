extends Node
## Design-system hook for icons: every TextureRect whose texture came from UiKit.icon_texture (it carries the
## "icon_id" meta) gets a KitIcon — kit layers and the shared bounce on appear, hover, select and leave.
## Screens keep assigning `texture` as before; nothing is wired per icon.

func _ready():
	get_tree().node_added.connect(added)

func added(node:Node):
	if node is TextureRect and not node.has_meta("kit_layer"):
		node.draw.connect(drawn.bind(node))

## A redraw follows every texture or tint change, so this is where a new icon, a swapped icon or a
## re-tinted host is noticed.
func drawn(rect:TextureRect):
	var id:String=str(rect.texture.get_meta("icon_id","")) if rect.texture else ""
	var icon:KitIcon=rect.get_meta("kit_icon") if rect.has_meta("kit_icon") else null
	if not is_instance_valid(icon):icon=null
	if id=="":
		if icon:icon.detach()
		return
	if icon==null or icon.key!=id:KitIcon.attach(rect,id)
	elif rect.self_modulate.a>0.0:icon.take_tint()
