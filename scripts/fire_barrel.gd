extends Node3D
## Burning oil drum outside the playable field: flickering flame and a warm light. Visual only,
## own RNG, no collision. Brighter at night; dim at day so it reads as smoke and embers.
var rng=RandomNumberGenerator.new()
var light:OmniLight3D
var flames:Array=[]
var clock=0.0
## Drum colour; the burning drum takes a dark shade of the map (set before adding to the tree).
var tint=Color("3a3632")

## One oil-drum model for the whole game: burning drums, explosive barrels and room props differ only in colour.
static func drum(parent:Node3D,color:Color,pos:=Vector3.ZERO)->Node3D:
	var root=Node3D.new();root.name="Drum";parent.add_child(root);root.position=pos
	var body=MeshInstance3D.new();var c=CylinderMesh.new();c.top_radius=.24;c.bottom_radius=.24;c.height=.72;c.radial_segments=16;body.mesh=c;body.position.y=.36
	body.material_override=Visuals.material(color);root.add_child(body)
	for y in [.12,.6]:
		var hoop=MeshInstance3D.new();var h=CylinderMesh.new();h.top_radius=.25;h.bottom_radius=.25;h.height=.04;h.radial_segments=16;hoop.mesh=h;hoop.position.y=y
		hoop.material_override=Visuals.material(color.darkened(.35));root.add_child(hoop)
	var lid=MeshInstance3D.new();var l=CylinderMesh.new();l.top_radius=.2;l.bottom_radius=.22;l.height=.03;l.radial_segments=16;lid.mesh=l;lid.position.y=.735
	lid.material_override=Visuals.material(color.darkened(.2));root.add_child(lid)
	return root

func _ready():
	name="FireBarrel"
	rng.seed=hash(global_position if is_inside_tree() else position)
	drum(self,tint)
	for i in range(3):
		var flame=MeshInstance3D.new();var m=PrismMesh.new();m.size=Vector3(.2-i*.04,.34-i*.06,.2-i*.04);flame.mesh=m
		flame.position=Vector3(rng.randf_range(-.07,.07),.84+i*.05,rng.randf_range(-.07,.07))
		var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=[Color("ff7a1f"),Color("ffb13d"),Color("ffe38a")][i]
		mat.emission_enabled=true;mat.emission=mat.albedo_color;flame.material_override=mat;flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame);flames.append(flame)
	light=OmniLight3D.new();light.position.y=1.2;light.light_color=Color("ff9a4a");light.omni_range=4.2;light.omni_attenuation=1.4;light.shadow_enabled=false;add_child(light)

func _process(delta):
	clock+=delta
	var night=Settings.values.get("world_lighting","day")=="night"
	var flicker=.75+.25*sin(clock*13.0)+.15*sin(clock*29.0+1.3)+rng.randf_range(-.08,.08)
	light.light_energy=(2.2 if night else .5)*flicker
	for i in range(flames.size()):
		flames[i].scale=Vector3(1,.85+.3*absf(sin(clock*(9.0+i*3.0)+i)),1)
		flames[i].rotation.y+=delta*(1.5+i)
