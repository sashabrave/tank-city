extends RefCounted
## Bounded ballistic motion against the game's logical obstacle grid.
const RADIUS=.14
const GRAVITY=9.8
var position:Vector3
var velocity:Vector3
var landed=false
var collided=false
var travel_after_contact=0.0
var blocked:Callable
func _init(origin:Vector3,destination:Vector3,seconds:float,obstacle:Callable):
	position=origin;blocked=obstacle
	var end=destination;end.y=RADIUS
	velocity=(end-origin)/seconds+Vector3.UP*(GRAVITY*seconds*.5)
func advance(delta:float):
	var remaining=delta
	while remaining>0:
		var dt=minf(remaining,1.0/240.0);remaining-=dt
		var next=position+velocity*dt+Vector3.DOWN*(GRAVITY*dt*dt*.5)
		for axis in [0,2]:
			var probe=position;probe[axis]=next[axis]+signf(velocity[axis])*RADIUS
			if blocked.call(probe):
				next[axis]=position[axis];velocity[axis]=-signf(velocity[axis])*minf(absf(velocity[axis])*.18,.85)
				if not collided:velocity.y=minf(velocity.y,0.5)
				collided=true
		if landed or collided:
			var distance=Vector2(next.x-position.x,next.z-position.z).length()
			if travel_after_contact+distance>.48:
				var fraction=maxf(0,.48-travel_after_contact)/maxf(distance,.00001)
				next.x=lerpf(position.x,next.x,fraction);next.z=lerpf(position.z,next.z,fraction);velocity.x=0;velocity.z=0
			travel_after_contact+=distance
		velocity.y-=GRAVITY*dt
		if next.y<=RADIUS:
			next.y=RADIUS
			if not landed:
				velocity.x*=.16;velocity.z*=.16
			velocity.y=-velocity.y*.16 if absf(velocity.y)>.7 else 0.0
			landed=true
		if landed:
			velocity.x=move_toward(velocity.x,0,2.8*dt);velocity.z=move_toward(velocity.z,0,2.8*dt)
		position=next
