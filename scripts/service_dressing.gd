extends Node3D
## Exit gate of an upgrade room (scripts/service_room.gd): posts, a striped beam, a lamp that is red until the choice
## is made and green after it, floor chevrons and the «Выход» sign. The room itself is its route stop model up close
## (service_room.gd ROOM_MODELS) with LocationAmbience.room and RoomLights around it; the old hangar dressing
## (lights, panels, moods, silhouettes, per-branch props) went with step 3 of the one field engine — every branch
## has its model. build_gate/paint_gate are shared with the merchant (T-285). Visual only.
const EXIT_CELL=Vector2i(4,1)
var gate_lamp:MeshInstance3D
var gate_light:OmniLight3D
var arrows:Array=[]
var clock=0.0
var open=false

func _ready():
	name="ServiceDressing"
	exit_gate()

func exit_gate():
	var parts=build_gate(self,EXIT_CELL)
	gate_lamp=parts.lamp;gate_light=parts.light;arrows=parts.arrows
## The exit gate on cell (posts, striped beam, lamp, floor chevrons, «Выход»), shared with the merchant (T-285).
static func build_gate(parent:Node3D,cell:Vector2i)->Dictionary:
	var at=Vector3(cell.x+.45,0,cell.y)
	for side in [-1,1]:Visuals.box(parent,at+Vector3(0,1.1,side*.62),Vector3(.24,2.2,.2),Color("6c756b"),"steel")
	Visuals.box(parent,at+Vector3(0,2.26,0),Vector3(.3,.22,1.5),Color("6c756b"),"steel")
	for i in range(5):
		var z=-.5+i*.25;var band=Visuals.box(parent,at+Vector3(0,2.26,z),Vector3(.32,.1,.12),Color("e0b13a") if i%2==0 else Color("2c2f30"))
		band.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lamp=Visuals.box(parent,at+Vector3(-.12,2.5,0),Vector3(.18,.16,.18),Color("e2493b"));lamp.material_override=Visuals.material(Color("e2493b"),true);lamp.material_override.emission_energy_multiplier=2.5
	var light=OmniLight3D.new();parent.add_child(light);light.position=at+Vector3(-.5,2.2,0);light.light_color=Color("ff5a44");light.light_energy=1.2;light.omni_range=3.2;light.shadow_enabled=false
	var chevrons=[]
	for i in range(3):
		var chevron=Visuals.label3d(parent,"›",Vector3(cell.x-2.8+i*.9,.03,cell.y),Color("e0b13a"),90)
		chevron.billboard=BaseMaterial3D.BILLBOARD_DISABLED;chevron.rotation_degrees=Vector3(-90,0,0);chevron.outline_size=0;chevron.modulate.a=.35;chevrons.append(chevron)
	var sign=Visuals.label3d(parent,"Выход",at+Vector3(-.2,2.85,0),Color("dfe8dd"),26);sign.outline_size=4
	return {"lamp":lamp,"light":light,"arrows":chevrons}
## Green gate: lamp and light of an open exit.
static func paint_gate(parts:Dictionary,open:bool):
	var color=Color("63d97a") if open else Color("e2493b")
	parts.lamp.material_override.albedo_color=color;parts.lamp.material_override.emission=color
	parts.light.light_color=color.lightened(.1)

func set_open(value:bool):
	open=value
	var color=Color("63d97a") if open else Color("e2493b")
	gate_lamp.material_override.albedo_color=color;gate_lamp.material_override.emission=color
	gate_light.light_color=color.lightened(.1)

func _process(delta):
	clock+=delta
	for i in range(arrows.size()):
		arrows[i].modulate.a=(.25+.6*clampf(sin(clock*4.0-i*.9),0,1)) if open else .18
	if is_instance_valid(gate_light):gate_light.light_energy=1.2+(.5*sin(clock*5.0) if open else 0.0)
