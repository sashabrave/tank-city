extends RefCounted
## One walking scheme for the hero outside battle (T-082): the hub's quarter-cell steps chained without a stop
## between them and a short eased turn. Service rooms and the merchant use it; the hub keeps its own copy.
const STEP=.25
const SPEED=3.4
const TURN=.105
var body:Node3D
var facing=Vector2i.UP
var moving=false
var destination=Vector3.ZERO
var turn_timer=0.0
var turn_from=0.0
var turn_to=0.0
func _init(node:Node3D):body=node;destination=node.position
## Moves the body for this frame; `can_stand` takes a world position and says if the hero may step there.
func step(delta:float,dir:Vector2i,can_stand:Callable):
	turn_timer=maxf(0,turn_timer-delta)
	if dir!=Vector2i.ZERO and dir!=facing:
		facing=dir;turn_timer=TURN;turn_from=body.rotation.y;turn_to=atan2(-float(dir.x),-float(dir.y))
	body.rotation.y=lerp_angle(turn_from,turn_to,1.0-turn_timer/TURN) if turn_timer>0 else atan2(-float(facing.x),-float(facing.y))
	var budget=SPEED*delta
	if moving:
		var before=body.position
		body.position=body.position.move_toward(destination,budget)
		budget-=before.distance_to(body.position)
		if body.position.distance_to(destination)<.001:moving=false
	# Chain straight into the next quarter step in the same frame: no stop on every cell.
	if not moving and dir!=Vector2i.ZERO:
		var next=body.position+Vector3(dir.x,0,dir.y)*STEP
		next.x=snappedf(next.x,STEP);next.z=snappedf(next.z,STEP)
		if can_stand.call(next):
			destination=next;moving=true
			if budget>0:body.position=body.position.move_toward(destination,budget)
func cell()->Vector2i:return Vector2i(roundi(body.position.x),roundi(body.position.z))
