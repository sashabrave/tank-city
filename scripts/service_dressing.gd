extends Node3D
## Themed interior of a route service room: a hangar bay (mechanic), a training yard (instructor) or a field
## command post (headquarters). Visual only; uses its own RNG and never touches combat state.
## The exit gate on the right is red until the choice is made, then turns green.
const EXIT_CELL=Vector2i(4,1)
const STATION=Vector3(0,0,-1)
var branch="vehicle"
var vehicle="buggy"
var rng=RandomNumberGenerator.new()
var gate_lamp:MeshInstance3D
var gate_light:OmniLight3D
var arrows:Array=[]
var flicker:Array=[]
var clock=0.0
var open=false

func _ready():
	name="ServiceDressing"
	rng.seed=hash(branch)+Game.visual_run_seed
	lighting()
	shell()
	exit_gate()
	mood()
	silhouettes(self,rng)
	hanging_lamps()
	match branch:
		"vehicle":mechanic()
		"ability":instructor()
		_:command_post()

func steel()->Color:return Color("59636a")

## Dim interior with a warm key light on the station and a cool rim light from behind.
func lighting():
	var parent=get_parent()
	for child in parent.get_children():
		if child is WorldEnvironment:
			var env:Environment=child.environment
			env.background_mode=Environment.BG_COLOR;env.background_color=Color("2b3130")
			env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("8a9a9a");env.ambient_light_energy=.55
			env.glow_enabled=true;env.glow_intensity=.55;env.glow_bloom=.08
		elif child is DirectionalLight3D:
			child.light_energy=.35;child.light_color=Color("b9c8d6")
	var key=SpotLight3D.new();add_child(key);key.position=STATION+Vector3(-.6,4.2,2.2);key.look_at_from_position(key.position,STATION+Vector3(0,.4,0))
	key.light_color=Color("ffd9a0");key.light_energy=5.0;key.spot_range=9.0;key.spot_angle=38;key.shadow_enabled=true
	var rim=SpotLight3D.new();add_child(rim);rim.position=Vector3(3.4,3.2,-3.4);rim.look_at_from_position(rim.position,STATION+Vector3(0,.6,.4))
	rim.light_color=Color("7fb4ff");rim.light_energy=3.2;rim.spot_range=9.0;rim.spot_angle=34;rim.shadow_enabled=false
	var fill=OmniLight3D.new();add_child(fill);fill.position=Vector3(-2,2.2,3);fill.light_color=Color("c9d6d1");fill.light_energy=.6;fill.omni_range=7;fill.shadow_enabled=false

## T-009: each visit gets its own light mood — warm workshop, cold neon night or a low sunset through the doors.
const MOODS=[["ffcf8a","2e2a24","9a8f80"],["7fd6ff","1f262e","6f8fa8"],["ff9a5c","2d2420","b08a78"]]
func mood():
	var m=MOODS[rng.randi_range(0,MOODS.size()-1)]
	for child in get_parent().get_children():
		if child is WorldEnvironment:
			child.environment.background_color=Color(m[1]);child.environment.ambient_light_color=Color(m[2])
	var wash=SpotLight3D.new();add_child(wash);wash.name="MoodWash";wash.position=Vector3(rng.randf_range(-3,3),5.5,4.5);wash.look_at_from_position(wash.position,Vector3(0,0,-1))
	wash.light_color=Color(m[0]);wash.light_energy=2.4;wash.spot_range=12;wash.spot_angle=50;wash.shadow_enabled=true
## Big, dim, low-contrast shapes beyond the floor: hangar gantries, stacked containers, a crane, tanks under
## covers — they hint at a larger base without competing with the room. Shared with the merchant stop.
static func silhouettes(parent:Node3D,rng:RandomNumberGenerator,tint:=Color("3a403e")):
	var kinds=["gantry","stack","crane","covered"]
	for i in range(7):
		var side=-1.0 if i%2==0 else 1.0
		var x=side*rng.randf_range(7.5,11.5);var z=rng.randf_range(-7.0,5.0)
		if i>=5:x=rng.randf_range(-6,6);z=-rng.randf_range(7.0,10.0)
		var shade=tint.darkened(rng.randf_range(0,.18))
		match kinds[rng.randi_range(0,kinds.size()-1)]:
			"gantry":
				for k in [-1.0,1.0]:Visuals.box(parent,Vector3(x+k*1.4,2.2,z),Vector3(.35,4.4,.35),shade)
				Visuals.box(parent,Vector3(x,4.4,z),Vector3(3.4,.4,.5),shade)
			"stack":
				for k in range(rng.randi_range(2,3)):Visuals.box(parent,Vector3(x,.7+k*1.4,z),Vector3(2.8,1.3,1.2),shade.lightened(k*.03))
			"crane":
				Visuals.box(parent,Vector3(x,3.2,z),Vector3(.4,6.4,.4),shade);var jib=Visuals.box(parent,Vector3(x+side*1.6,6.2,z),Vector3(3.6,.3,.3),shade);jib.rotation.y=rng.randf_range(-.3,.3)  # points away from the room
			"covered":
				Visuals.box(parent,Vector3(x,.6,z),Vector3(2.4,1.2,1.5),shade);Visuals.box(parent,Vector3(x,1.25,z),Vector3(2.5,.12,1.6),shade.lightened(.05))
## Two pendant lamps over the room (light and soft cones only, fixtures out of frame); one stutters now and then.
func hanging_lamps():
	for i in range(2):
		var at=Vector3(-1.8+i*3.6,3.6,rng.randf_range(-.5,1.5))
		# The lamp bodies hung between the camera and the vehicle bay and hid the car (T-083): only their light
		# and soft cone stay, as if the fixtures are above the frame.
		var lamp=SpotLight3D.new();add_child(lamp);lamp.position=at+Vector3(0,-.15,0);lamp.rotation_degrees=Vector3(-90,0,0)
		lamp.light_color=Color("ffe1ad");lamp.light_energy=2.2;lamp.spot_range=5.0;lamp.spot_angle=40;lamp.shadow_enabled=i==0

		preload("res://scripts/world_lighting.gd").add_cone(lamp);lamp.get_node("SoftCone").material_override.set_shader_parameter("density",.012)
		if i==1:preload("res://scripts/light_flicker.gd").attach(lamp,rng.randi())
func shell():
	# Back wall of ribbed panels, a low left wall and a hazard band around the station.
	for i in range(10):
		var x=-4.5+i
		Visuals.box(self,Vector3(x,1.3,-3.75),Vector3(.96,2.6,.2),steel().darkened(.06 if i%2==0 else 0.0))
		Visuals.box(self,Vector3(x+.48,1.3,-3.62),Vector3(.06,2.6,.08),Color("454c51"))
	Visuals.box(self,Vector3(0,2.66,-3.7),Vector3(10.1,.12,.36),Color("3b4145"))
	for z in range(-3,5):
		Visuals.box(self,Vector3(-4.75,.45,z),Vector3(.2,.9,.96),steel().darkened(.1))
	for i in range(8):
		var stripe=Visuals.box(self,Vector3(-1.4+i*.4,.02,.35),Vector3(.2,.02,.12),Color("e0b13a") if i%2==0 else Color("2c2f30"))
		stripe.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Painted bay markings on the floor.
	for side in [-1,1]:
		var line=Visuals.box(self,Vector3(side*1.6,.015,-1.2),Vector3(.06,.01,2.6),Color("d8c27a"));line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Back-wall work light strips.
	for x in [-3.0,3.0]:
		var strip=Visuals.box(self,Vector3(x,2.3,-3.6),Vector3(1.2,.08,.06),Color("d9ecff"));strip.material_override=Visuals.material(Color("d9ecff"),true);strip.material_override.emission_energy_multiplier=1.6

func exit_gate():
	var at=Vector3(EXIT_CELL.x+.45,0,EXIT_CELL.y)
	for side in [-1,1]:Visuals.box(self,at+Vector3(0,1.1,side*.62),Vector3(.24,2.2,.2),Color("4a5249"))
	Visuals.box(self,at+Vector3(0,2.26,0),Vector3(.3,.22,1.5),Color("4a5249"))
	for i in range(5):
		var z=-.5+i*.25;var band=Visuals.box(self,at+Vector3(0,2.26,z),Vector3(.32,.1,.12),Color("e0b13a") if i%2==0 else Color("2c2f30"))
		band.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate_lamp=Visuals.box(self,at+Vector3(-.12,2.5,0),Vector3(.18,.16,.18),Color("e2493b"));gate_lamp.material_override=Visuals.material(Color("e2493b"),true);gate_lamp.material_override.emission_energy_multiplier=2.5
	gate_light=OmniLight3D.new();add_child(gate_light);gate_light.position=at+Vector3(-.5,2.2,0);gate_light.light_color=Color("ff5a44");gate_light.light_energy=1.2;gate_light.omni_range=3.2;gate_light.shadow_enabled=false
	# Floor chevrons toward the gate.
	for i in range(3):
		var chevron=Visuals.label3d(self,"›",Vector3(1.2+i*.9,.03,EXIT_CELL.y),Color("e0b13a"),90)
		chevron.billboard=BaseMaterial3D.BILLBOARD_DISABLED;chevron.rotation_degrees=Vector3(-90,0,0);chevron.outline_size=0;chevron.modulate.a=.35;arrows.append(chevron)
	var sign=Visuals.label3d(self,"Выход",at+Vector3(-.2,2.85,0),Color("dfe8dd"),26);sign.outline_size=4

func set_open(value:bool):
	open=value
	var color=Color("63d97a") if open else Color("e2493b")
	gate_lamp.material_override.albedo_color=color;gate_lamp.material_override.emission=color
	gate_light.light_color=color.lightened(.1)

func mechanic():
	# Lift under the vehicle, tool wall, tyres, barrels, welding glow.
	var lift=Vector3(2.2,0,-1.2)
	Visuals.box(self,lift+Vector3(0,.08,0),Vector3(2.0,.16,2.3),Color("3e4447"))
	for side in [-1,1]:Visuals.box(self,lift+Vector3(side*1.02,.1,0),Vector3(.06,.2,2.3),Color("e0b13a"))
	for x in [-.6,.6]:Visuals.box(self,lift+Vector3(x,.9,-1.3),Vector3(.12,1.8,.12),Color("c24a3a"))
	for i in range(6):
		var hook=Visuals.box(self,Vector3(-3.4+i*.34,1.6+(i%2)*.18,-3.58),Vector3(.08,.4+rng.randf()*.3,.06),Color("9aa3a8"));hook.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Visuals.box(self,Vector3(-2.55,1.62,-3.62),Vector3(2.2,1.2,.04),Color("2e3538"))
	for i in range(3):tyre(Vector3(-3.8,.14+i*.26,2.6))
	tyre(Vector3(-3.1,.14,3.1))
	barrel(Vector3(3.6,0,3.2),Color("b45c32"));barrel(Vector3(3.9,0,2.6),Color("5d6b4a"))
	Visuals.model("crate",self,Vector3(-3.6,0,-2.6)).rotation.y=rng.randf()*.4
	var weld=OmniLight3D.new();add_child(weld);weld.position=lift+Vector3(-.9,.6,.6);weld.light_color=Color("8ad8ff");weld.omni_range=2.4;weld.shadow_enabled=false;flicker.append(weld)

func instructor():
	# Training yard: sandbag line, targets, map board, flag.
	for i in range(5):Visuals.box(self,Vector3(-3.6+i*.55,.2,-2.6),Vector3(.52,.4,.5),Color("a39068").darkened(rng.randf()*.12))
	for i in range(4):Visuals.box(self,Vector3(-3.35+i*.55,.55,-2.6),Vector3(.52,.32,.5),Color("9a8862").darkened(rng.randf()*.12))
	for x in [2.4,3.5]:
		var dummy=Visuals.model("training_dummy",self,Vector3(x,0,-2.95));dummy.rotation.y=PI+rng.randf_range(-.3,.3)
	Visuals.box(self,Vector3(-1.9,1.55,-3.6),Vector3(2.0,1.3,.05),Color("33483a"))
	for i in range(5):
		var pin=Visuals.box(self,Vector3(-2.7+i*.4,1.4+rng.randf()*.5,-3.56),Vector3(.1,.1,.03),Color("e2493b") if i%2==0 else Color("e0b13a"));pin.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Visuals.box(self,Vector3(3.9,1.4,3.4),Vector3(.06,2.8,.06),Color("6e6a5c"))
	var flag=Visuals.box(self,Vector3(3.9,2.55,3.05),Vector3(.03,.5,.7),Color("5c7550"));flag.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(2):Visuals.model("crate",self,Vector3(-3.7,0,2.2+i*.9)).rotation.y=rng.randf()*.5
	barrel(Vector3(3.7,0,2.5),Color("5d6b4a"))

func command_post():
	# Field command post: antenna mast, radio crates, camo net, a green terminal glow.
	Visuals.box(self,Vector3(3.6,2.0,-3.1),Vector3(.08,4.0,.08),Color("6e757a"))
	for y in [1.2,2.2,3.2]:Visuals.box(self,Vector3(3.6,y,-3.1),Vector3(.5,.04,.04),Color("6e757a"))
	var tip=Visuals.box(self,Vector3(3.6,4.05,-3.1),Vector3(.12,.12,.12),Color("e2493b"));tip.material_override=Visuals.material(Color("e2493b"),true);flicker.append(tip)
	for i in range(3):
		var crate=Visuals.box(self,Vector3(-3.4+i*.75,.3,-2.9),Vector3(.65,.6,.5),Color("4f5b45"))
		var screen=Visuals.box(self,Vector3(-3.4+i*.75,.42,-2.63),Vector3(.4,.2,.02),Color("6bf29a"));screen.material_override=Visuals.material(Color("6bf29a"),true);screen.material_override.emission_energy_multiplier=1.8
	var glow=OmniLight3D.new();add_child(glow);glow.position=Vector3(-2.6,.9,-2.2);glow.light_color=Color("6bf29a");glow.light_energy=.9;glow.omni_range=2.6;glow.shadow_enabled=false
	for i in range(2):Visuals.model("crate",self,Vector3(-3.8,0,3.0+i*.8)).rotation.y=rng.randf()*.5
	barrel(Vector3(3.8,0,3.0),Color("b45c32"))
	Visuals.model("crate",self,Vector3(3.2,0,3.4))

func tyre(pos:Vector3):
	var m=MeshInstance3D.new();var t=TorusMesh.new();t.inner_radius=.14;t.outer_radius=.3;m.mesh=t;m.position=pos
	m.material_override=Visuals.material(Color("25282a"));add_child(m)

func barrel(pos:Vector3,color:Color):
	preload("res://scripts/fire_barrel.gd").drum(self,color,pos)

func _process(delta):
	clock+=delta
	for i in range(arrows.size()):
		arrows[i].modulate.a=(.25+.6*clampf(sin(clock*4.0-i*.9),0,1)) if open else .18
	for node in flicker:
		if node is OmniLight3D:node.light_energy=(1.4 if rng.randf()<.35 else .15) if fposmod(clock,2.6)<.9 else 0.0
		elif node is MeshInstance3D:node.visible=fposmod(clock,1.2)<.6
	if is_instance_valid(gate_light):gate_light.light_energy=1.2+(.5*sin(clock*5.0) if open else 0.0)
