extends CanvasLayer
## Minimal loading screen for heavy synchronous switches (resume, map build). It is drawn first,
## then the work runs under it, then it fades out after the new scene has rendered one frame.
## A hitch under a calm dark frame reads as loading, not as a frozen game.
const FADE=.22
var shade:ColorRect
var label:Label

static func run(owner:Node,work:Callable):
	var veil=new();veil.layer=120;owner.get_tree().root.add_child(veil)
	await veil.cover()
	work.call()
	await veil.reveal()

func _ready():
	shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color("161c19");shade.mouse_filter=Control.MOUSE_FILTER_STOP
	label=Label.new();shade.add_child(label);label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",18);label.add_theme_color_override("font_color",Color(UiKit.MUTED,.8))
	Texts.set_text(label,"Загрузка")
	shade.modulate.a=0.0

func cover():
	var tween=create_tween();tween.tween_property(shade,"modulate:a",1.0,.12)
	await tween.finished
	# Two presented frames guarantee the veil is on screen before the heavy work blocks the thread.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

func reveal():
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var tween=create_tween();tween.tween_property(shade,"modulate:a",0.0,FADE)
	await tween.finished
	queue_free()
