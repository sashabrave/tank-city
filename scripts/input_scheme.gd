extends Node
## Control scheme: keyboard, gamepad or touch. "Авто" follows the last device the player used —
## touching the screen shows the on-screen pads, a key press or a gamepad hides them.
signal changed
const SCHEMES=["auto","keyboard","gamepad","touch"]
## Gamepad layout (Xbox names; the same positions on other pads).
const PAD_BUTTONS={"interact":JOY_BUTTON_A,"hide_trench":JOY_BUTTON_B,"fire":JOY_BUTTON_X,"ability":JOY_BUTTON_Y,"class_ability":JOY_BUTTON_LEFT_SHOULDER,"pause":JOY_BUTTON_START,"ammo_switch":JOY_BUTTON_RIGHT_STICK,
	"north":JOY_BUTTON_DPAD_UP,"south":JOY_BUTTON_DPAD_DOWN,"west":JOY_BUTTON_DPAD_LEFT,"east":JOY_BUTTON_DPAD_RIGHT}
const PAD_AXES={"fire":[JOY_AXIS_TRIGGER_RIGHT,1.0],"north":[JOY_AXIS_LEFT_Y,-1.0],"south":[JOY_AXIS_LEFT_Y,1.0],"west":[JOY_AXIS_LEFT_X,-1.0],"east":[JOY_AXIS_LEFT_X,1.0]}
const PAD_GLYPHS={"interact":"A","hide_trench":"B","fire":"RT","ability":"Y","class_ability":"LB","pause":"☰","ammo_switch":"RS"}
var device="touch" if OS.has_feature("mobile") else "keyboard"
func _ready():process_mode=Node.PROCESS_MODE_ALWAYS
func current()->String:
	var chosen=str(Settings.values.get("input_scheme","auto"))
	return device if chosen=="auto" else chosen
func touch()->bool:return current()=="touch"
func gamepad()->bool:return current()=="gamepad"
func _input(event):
	var next=device
	if event is InputEventScreenTouch or event is InputEventScreenDrag:next="touch"
	elif event is InputEventKey and event.pressed:next="keyboard"
	elif event is InputEventJoypadButton and event.pressed:next="gamepad"
	elif event is InputEventJoypadMotion and absf(event.axis_value)>.5:next="gamepad"
	if next!=device:
		device=next
		if str(Settings.values.get("input_scheme","auto"))=="auto":changed.emit()
## Adds the gamepad events for an action; called after keyboard bindings are rebuilt.
static func add_pad_events(action:String):
	InputMap.action_set_deadzone(action,.45)
	if PAD_BUTTONS.has(action):
		var button=InputEventJoypadButton.new();button.button_index=PAD_BUTTONS[action];InputMap.action_add_event(action,button)
	if PAD_AXES.has(action):
		var motion=InputEventJoypadMotion.new();motion.axis=PAD_AXES[action][0];motion.axis_value=PAD_AXES[action][1];InputMap.action_add_event(action,motion)
## What to show in a key hint for the current scheme ("" for touch: the hint itself is tapped).
func glyph(action:String)->String:
	match current():
		"touch":return ""
		"gamepad":return PAD_GLYPHS.get(action,"")
	return OS.get_keycode_string(Settings.keys.get(action,KEY_NONE))
