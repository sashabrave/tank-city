extends Node
## Gentle diorama tilt: the camera leans a few degrees toward the cursor (keyboard/mouse) or follows a drag
## on empty screen space (touch), and eases back when released or disabled. Returns yaw/pitch in degrees.
## Used only in calm moments: the hub and between waves. Never during active combat.
## Only a turn around the vertical axis through the field centre (seen from above), no pitch.
const MAX_YAW=1.5
const MAX_PITCH=0.0
const EASE=2.6
var enabled=false
var tilt=Vector2.ZERO
var drag=Vector2.ZERO
var dragging=false

func _unhandled_input(event):
	if not enabled:return
	if event is InputEventScreenTouch:dragging=event.pressed
	elif event is InputEventScreenDrag and dragging:
		var size=get_viewport().get_visible_rect().size
		drag=(drag+event.relative/size*Vector2(2.4,2.4)).clampf(-1.0,1.0)

func _process(delta):
	var goal=Vector2.ZERO
	if enabled:
		if InputScheme.touch():
			if not dragging:drag=drag.lerp(Vector2.ZERO,minf(1.0,delta*EASE))
			goal=drag
		elif not InputScheme.gamepad():
			var size=get_viewport().get_visible_rect().size
			var mouse=get_viewport().get_mouse_position()
			if DisplayServer.window_is_focused():goal=((mouse/size)*2.0-Vector2.ONE).clampf(-1.0,1.0)
	tilt=tilt.lerp(goal,1.0-exp(-delta*EASE))

func yaw()->float:return tilt.x*MAX_YAW
func pitch()->float:return 0.0
