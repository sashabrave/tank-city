extends CanvasLayer
## Small corner readout above every mode: frames per second everywhere, the build number in the hub.
## Shown by the "show_fps" interface setting; the hub turns the build line on while it is open.
var show_build=false
var label:Label
var timer=0.0
func _ready():
	layer=120;process_mode=Node.PROCESS_MODE_ALWAYS
	label=Label.new();add_child(label);label.name="PerfLabel";label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.position=Vector2(10,6);label.add_theme_font_size_override("font_size",13)
	label.add_theme_color_override("font_color",Color(1,1,1,.72));label.add_theme_color_override("font_outline_color",Color(0,0,0,.8));label.add_theme_constant_override("outline_size",4)
	refresh()
func _process(delta):
	timer-=delta
	if timer<=0.0:timer=.5;refresh()
static func build_text()->String:
	return "%s · %s" % [ProjectSettings.get_setting("application/config/version","0.1"),ProjectSettings.get_setting("application/config/build","1")]
func refresh():
	label.visible=bool(Settings.values.get("show_fps",true))
	if not label.visible:return
	var text="%d FPS" % roundi(Engine.get_frames_per_second())
	if show_build:text=Texts.render("Сборка")+" "+build_text()+"   "+text
	label.text=text
