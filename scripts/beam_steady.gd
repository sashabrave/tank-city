extends Node3D
## Follows a bobbing lamp (the chest flashlight on the walk animation) with 15% less shake: the light rides a
## low-passed copy of the lamp's transform and moves only 85% of the way to the real one each frame.
var lamp:Node3D
var smooth:Transform3D
var ready_once=false
const KEEP=.85
func _process(delta):
	if not is_instance_valid(lamp):return
	var target=lamp.global_transform
	if not ready_once:smooth=target;ready_once=true
	smooth=smooth.interpolate_with(target,minf(1.0,delta*6.0))
	global_transform=smooth.interpolate_with(target,KEEP)
