extends Node
## Map dioramas: tiny stepped animations (2-3 frames), like a toy board. Visual only.
const STEP=.5
var tracks:Array=[]  # {node, property, values}
var clock=0.0
var frame=-1
func add(node:Node3D,property:String,values:Array):
	tracks.append({"node":node,"property":property,"values":values})
	if values.size()>0:node.set(property,values[0])
func _process(delta):
	clock+=delta
	var current=int(clock/STEP)
	if current==frame:return
	frame=current
	for track in tracks:
		if is_instance_valid(track.node):track.node.set(track.property,track.values[frame%track.values.size()])
