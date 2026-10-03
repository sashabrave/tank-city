extends Node3D
## Garage hangar at the start of the route map (T-007): a static, monumental building that the screen crops on
## purpose. 1.5× the old block, with a complex roof — steel trusses, roof vents with fans, antennas and a dish,
## skylight openings, AC units and a railing. Visual only; route graph and hit areas stay in world space.
const HOME=Vector3(-15,0,21)
func _ready():
	name="ForegroundHangar";position=HOME;rotation.y=-.32
	var wall=Color("777c70");var roof=Color("4f5347");var steel=Color("3e423b");var trim=Color("8a8e80")
	var w=36.0;var d=15.0;var h=3.6
	Visuals.box(self,Vector3(0,h*.5,0),Vector3(w,h,d),wall)
	Visuals.box(self,Vector3(0,h+.18,0),Vector3(w+.4,.36,d+.4),roof)
	# Parapet with a cap.
	for x in [-w*.5,w*.5]:Visuals.box(self,Vector3(x,h+.55,0),Vector3(.3,.5,d+.4),trim)
	for z in [-d*.5,d*.5]:Visuals.box(self,Vector3(0,h+.55,z),Vector3(w+.4,.5,.3),trim)
	# Steel trusses across the roof: top chord, bottom chord and zigzag diagonals.
	for i in range(7):
		var x=-15.0+i*5.0
		Visuals.box(self,Vector3(x,h+1.35,0),Vector3(.16,.14,d-.6),steel)
		Visuals.box(self,Vector3(x,h+.46,0),Vector3(.14,.12,d-.6),steel)
		for k in range(6):
			var z=-d*.5+1.0+k*2.2;var bar=Visuals.box(self,Vector3(x,h+.9,z),Vector3(.08,1.1,.08),steel);bar.rotation.x=.55 if k%2==0 else -.55
	# Skylight openings: dark recessed panes with frames.
	for i in range(5):
		var x=-13.0+i*6.5
		Visuals.box(self,Vector3(x,h+.37,3.2),Vector3(3.4,.04,2.4),Color("1c2124"))
		for b in [-1.0,0.0,1.0]:Visuals.box(self,Vector3(x+b*1.1,h+.42,3.2),Vector3(.08,.06,2.5),trim)
		Visuals.box(self,Vector3(x,h+.42,3.2),Vector3(3.5,.06,.08),trim)
	# Roof vents with fans and AC units.
	for x in [-9.0,2.0,11.0]:
		Visuals.box(self,Vector3(x,h+.75,-3.6),Vector3(1.8,.8,1.8),Color("85897b"))
		var fan=Visuals.box(self,Vector3(x,h+1.17,-3.6),Vector3(1.4,.04,.22),Color("2e322c"));fan.name="Fan"
		var fan2=Visuals.box(self,Vector3(x,h+1.17,-3.6),Vector3(.22,.04,1.4),Color("2e322c"));fan2.name="Fan"
	for x in [-4.0,6.5]:
		Visuals.box(self,Vector3(x,h+.6,-.8),Vector3(1.4,.5,.9),Color("b9bcb0"))
		for k in range(4):Visuals.box(self,Vector3(x-.45+k*.3,h+.86,-.8),Vector3(.18,.02,.7),Color("6f7368"))
	# Antennas, a dish and a railing along the front edge.
	for p in [Vector3(-16,0,-5.5),Vector3(14.5,0,-6)]:
		Visuals.box(self,p+Vector3(0,h+2.4,0),Vector3(.08,4.0,.08),steel)
		Visuals.box(self,p+Vector3(0,h+4.3,0),Vector3(.9,.05,.05),steel)
		var light=Visuals.box(self,p+Vector3(0,h+4.45,0),Vector3(.14,.14,.14),Color("e2493b"));light.material_override=Visuals.material(Color("e2493b"),true)
	var dish=Visuals.box(self,Vector3(9,h+1.1,4.8),Vector3(1.5,1.5,.12),Color("c9ccc2"));dish.rotation=Vector3(-.6,.4,0)
	for x in range(-17,18,2):Visuals.box(self,Vector3(x,h+.95,d*.5-.25),Vector3(.05,.7,.05),steel)
	Visuals.box(self,Vector3(0,h+1.3,d*.5-.25),Vector3(w-.6,.05,.05),steel)
	# Big hangar number painted on the roof.
	for i in range(3):Visuals.box(self,Vector3(-2.5+i*1.6,h+.37,-1.0),Vector3(1.1,.02,2.6),Color("b2833e") if i!=1 else Color("4f5347"))
func _process(delta):
	for fan in get_children():
		if fan.name.begins_with("Fan"):fan.rotation.y+=delta*2.5
## The hangar is a static map object now (no parallax); kept for the route map's call.
func follow_camera(_scroll:float,_zoom:float):pass
