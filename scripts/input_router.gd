extends Node
## Default key bindings and the player's movement/fire intent from keyboard and touch controls.
const MOVE_DIRECTIONS={"north":Vector2i.UP,"south":Vector2i.DOWN,"west":Vector2i.LEFT,"east":Vector2i.RIGHT}
const DEFAULT_KEYS={"north": [KEY_W, KEY_UP], "south": [KEY_S, KEY_DOWN], "west": [KEY_A, KEY_LEFT], "east": [KEY_D, KEY_RIGHT], "fire": [KEY_SPACE], "interact": [KEY_E], "hide_trench": [KEY_C], "pause": [KEY_ESCAPE, KEY_TAB], "class_ability":[KEY_Q],"hq_ability":[KEY_2],"ability": [KEY_F]}
var touch_direction=Vector2i.ZERO
var touch_fire=false
var keyboard_fire_held=false
var movement_press_order:Array[String]=[]
func register_actions():
	for action in DEFAULT_KEYS:
		if not InputMap.has_action(action):InputMap.add_action(action)
		for key in DEFAULT_KEYS[action]:
			var event=InputEventKey.new();event.physical_keycode=key
			InputMap.action_add_event(action,event)
func direction()->Vector2i:
	if touch_direction!=Vector2i.ZERO:return touch_direction
	# Most recent held direction wins; releasing it resumes the previous held key.
	for i in range(movement_press_order.size()-1,-1,-1):
		var action=movement_press_order[i]
		if Input.is_action_pressed(action):return MOVE_DIRECTIONS[action]
	for action in MOVE_DIRECTIONS:
		if Input.is_action_pressed(action):return MOVE_DIRECTIONS[action]
	return Vector2i.ZERO
func reset():
	movement_press_order.clear();touch_direction=Vector2i.ZERO;touch_fire=false;keyboard_fire_held=false
func wants_fire()->bool:
	return keyboard_fire_held or Input.is_action_pressed("fire") or touch_fire
func _input(event):
	if not event.is_echo():
		for action in MOVE_DIRECTIONS:
			if event.is_action_pressed(action):
				movement_press_order.erase(action);movement_press_order.append(action)
	if event.is_action("fire"):keyboard_fire_held=event.pressed
