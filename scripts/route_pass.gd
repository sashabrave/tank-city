extends Node3D
## The far end of the route map, past the boss (T-007): a mountain pass with a checkpoint — a booth, striped
## barriers and a sandbagged gate — and beyond it the war goes on: burnt ground, black smoke columns and fires.
## Visual only, placed by route_map at the top of the route.
var smoke:Array=[]
var clock=0.0
func build(top_z:float):
	name="RoutePass";position=Vector3(0,0,top_z-9.0)
	var rock=Color("6e6a62");var dark=Color("2c2a28");var stripe_a=Color("d8c14a");var stripe_b=Color("2a2a26")
	# Cliffs on both sides narrowing into the pass.
	for side in [-1.0,1.0]:
		for k in range(5):
			var r=Visuals.box(self,Vector3(side*(5.2+k*2.2),1.4+k*.7,-k*1.6),Vector3(3.6,2.8+k*1.4,4.2),rock.darkened(k*.05))
			r.rotation=Vector3(0,side*.25+k*.1,side*.06)
	# The road through the gate.
	Visuals.box(self,Vector3(0,.02,-2.0),Vector3(3.2,.04,10),Color("5b5a52"))
	# Checkpoint: booth, sandbag walls, two striped barriers.
	Visuals.box(self,Vector3(2.4,.8,.5),Vector3(1.3,1.6,1.3),Color("6f7a5c"))
	Visuals.box(self,Vector3(2.4,1.7,.5),Vector3(1.6,.15,1.6),Color("4b5340"))
	Visuals.box(self,Vector3(1.75,1.0,.5),Vector3(.04,.5,.8),Color("9fd0ff"))
	for side in [-1.0,1.0]:
		for k in range(4):Visuals.box(self,Vector3(side*(2.0+k*.5),.25,-.6),Vector3(.5,.5,.35),Color("b8a47c"))
	for z in [.0,-2.4]:
		Visuals.box(self,Vector3(-1.75,.5,z),Vector3(.25,1.0,.25),stripe_b)
		for i in range(6):Visuals.box(self,Vector3(-1.35+i*.48,.85,z),Vector3(.46,.14,.12),stripe_a if i%2==0 else stripe_b)
	# Beyond the pass: burnt ground, ruins, fires and black smoke.
	# Burnt ground as overlapping irregular patches with a soft, ragged edge instead of one rectangle.
	var rng=RandomNumberGenerator.new();rng.seed=7781
	for i in range(26):
		var patch=MeshInstance3D.new();var disc=CylinderMesh.new();var r=rng.randf_range(2.2,4.4);disc.top_radius=r;disc.bottom_radius=r;disc.height=.02;disc.radial_segments=9
		patch.mesh=disc;patch.position=Vector3(rng.randf_range(-13,13),-.01+i*.0004,rng.randf_range(-22,-5));patch.rotation.y=rng.randf()*TAU
		patch.scale=Vector3(1.0,1.0,rng.randf_range(.6,1.0));patch.material_override=Visuals.material(Color("1f1d1b").lerp(Color("3a332c"),rng.randf()*.4));add_child(patch)
	for i in range(9):
		var p=Vector3(rng.randf_range(-12,12),0,rng.randf_range(-22,-7))
		var ruin=Visuals.box(self,p+Vector3(0,rng.randf_range(.6,1.6),0),Vector3(rng.randf_range(1,2.5),rng.randf_range(1.2,3.2),rng.randf_range(1,2.2)),dark);ruin.rotation.y=rng.randf()*TAU
	for i in range(6):
		var p=Vector3(rng.randf_range(-11,11),0,rng.randf_range(-20,-8))
		var flame=Visuals.box(self,p+Vector3(0,.35,0),Vector3(.6,.7,.6),Color("ff7a2a"));flame.material_override=Visuals.material(Color("ff7a2a"),true);flame.name="Flame"
		var glow=OmniLight3D.new();add_child(glow);glow.position=p+Vector3(0,1.0,0);glow.light_color=Color("ff8a3d");glow.light_energy=2.2;glow.omni_range=4.0;glow.name="FireGlow"
		for k in range(4):
			var puff=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=.9+k*.35;sphere.height=sphere.radius*1.6;puff.mesh=sphere
			var mat=StandardMaterial3D.new();mat.albedo_color=Color(.06,.06,.06,.55-k*.1);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;puff.material_override=mat
			puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(puff);puff.position=p+Vector3(k*.4,1.6+k*1.5,-k*.3)
			smoke.append([puff,puff.position,rng.randf()*TAU])
func _process(delta):
	clock+=delta
	for s in smoke:
		var puff:Node3D=s[0];puff.position=s[1]+Vector3(sin(clock*.3+s[2])*.3,sin(clock*.2+s[2])*.15,0)
	for child in get_children():
		if child.name.begins_with("FireGlow"):child.light_energy=2.0+sin(clock*9.0+child.position.x)*.4
