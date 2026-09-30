extends Node3D
var clock=0.0
var legs:Array=[]
var wheels:Array=[]
var rotors:Array=[]
var recoil=0.0
var gun:Node3D
var gun_home=Vector3.ZERO
func _ready():
	for node in find_children("*","Node3D",true,false):
		var title=str(node.name).to_lower()
		if "leg pivot" in title:legs.append(node)
		if "wheel pivot" in title or "animated road wheel" in title:wheels.append(node)
		if "rotor spin" in title:rotors.append(node)
func _process(delta):
	var actor=get_parent()
	var active=actor.get("arena") if actor else null
	if active!=null and active.phase not in ["combat","countdown"]:return
	clock+=delta
	var moving=bool(actor.get("moving")) if actor.get("moving")!=null else false
	for i in range(legs.size()):legs[i].rotation.x=sin(clock*13+i*PI)*.35 if moving else lerpf(legs[i].rotation.x,0,minf(1,delta*8))
	if moving:
		for wheel in wheels:wheel.rotation.x+=delta*7
	for rotor in rotors:rotor.rotation.y+=delta*25
	recoil=maxf(0,recoil-delta*5)
	if is_instance_valid(gun):gun.position=gun_home+Vector3(0,0,recoil*.08)
func kick():recoil=1.0
