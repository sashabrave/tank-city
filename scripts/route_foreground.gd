extends Node3D
## Foreground hangar. Visual only; route graph and hit areas stay in world space.
const HOME=Vector3(-12,0,18)
func _ready():
	name="ForegroundHangar";position=HOME;rotation.y=-.32
	var roof=Color("55594b");var concrete=Color("777c70")
	Visuals.box(self,Vector3(0,1.15,0),Vector3(24,2.3,10),concrete)
	Visuals.box(self,Vector3(0,2.4,0),Vector3(24.3,.3,10.3),roof)
	for x in [-12.0,12.0]:Visuals.box(self,Vector3(x,2.65,0),Vector3(.18,.3,10.3),concrete)
	for z in [-5.0,5.0]:Visuals.box(self,Vector3(0,2.65,z),Vector3(24.3,.3,.18),concrete)
	for x in range(-10,11,2):Visuals.box(self,Vector3(x,2.56,0),Vector3(.035,.025,9.7),Color("717566"))
	for x in [-4.0,3.0]:
		Visuals.box(self,Vector3(x,2.9,0),Vector3(1.65,.65,1.35),Color("85897b"))
		for z in range(5):Visuals.box(self,Vector3(x,3.235,-.45+z*.22),Vector3(1.25,.025,.07),Color("42483f"))
	for x in [-5.0,-3.8,-2.6]:Visuals.box(self,Vector3(x,2.565,2.7),Vector3(.65,.035,2.0),Color("b2833e"))
func follow_camera(scroll:float,zoom:float):
	# The close roof leaves the frame faster than the distant route, including zooms.
	var travel=maxf(0,scroll)*.40+maxf(0,28.0-zoom)*.60
	position=HOME+Vector3(-travel*.35,0,travel)
	visible=scroll<24
