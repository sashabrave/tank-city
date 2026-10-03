extends RefCounted
## Decorative light of the upgrade rooms and the merchant (author, 2026-10-03): always the same places, not
## random — a festoon of warm bulbs over the far edge between two posts, and two light masts at the front
## corners looking in. They glow in the warm cozy daylight too (world_lighting.gd COZY_MOMENTS); the lamps
## join the shared light budget (group «night_lamps», day/night energies) with a high priority.
const WARM:=Color("ffc982")
const BACK_Z:=-3.45
const HALF:=4.25

static func build(room:Node3D,back_z:=BACK_Z):
	var root=Node3D.new();root.name="RoomLights";room.add_child(root)
	festoon(root,back_z)
	for side in [-1.0,1.0]:
		preload("res://scripts/base_surroundings.gd").lamp(root,Vector3(side*(HALF+.3),0,4.35))
	for light in root.find_children("*","SpotLight3D",true,false):
		light.set_meta("day_energy",.9);light.set_meta("priority",2)

## Two posts and a sagging wire of bulbs; three soft omni lights carry the glow.
static func festoon(root:Node3D,back_z:float):
	var post=Color("5b4a3a")
	for side in [-1.0,1.0]:
		Visuals.box(root,Vector3(side*HALF,1.35,back_z),Vector3(.12,2.7,.12),post)
	var bulb_material=StandardMaterial3D.new();bulb_material.albedo_color=WARM;bulb_material.emission_enabled=true
	bulb_material.emission=WARM;bulb_material.emission_energy_multiplier=2.2;bulb_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var wire=Color("2e2a26");var count=11;var previous=Vector3.ZERO
	for i in range(count):
		var k=float(i)/(count-1);var at=Vector3(lerpf(-HALF,HALF,k),2.62-sin(k*PI)*.42,back_z)
		if i>0:
			var segment=Visuals.box(root,(previous+at)*.5,Vector3(previous.distance_to(at),.025,.025),wire)
			segment.rotation.z=atan2(at.y-previous.y,at.x-previous.x)
		previous=at
		if i==0 or i==count-1:continue
		var bulb=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=.07;sphere.height=.16;sphere.radial_segments=8;sphere.rings=4
		bulb.mesh=sphere;bulb.material_override=bulb_material;bulb.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bulb);bulb.position=at+Vector3(0,-.1,0)
	for x in [-2.6,0.0,2.6]:
		var glow=OmniLight3D.new();glow.name="FestoonGlow";root.add_child(glow);glow.position=Vector3(x,2.1,back_z+.4)
		glow.light_color=WARM;glow.omni_range=3.6;glow.omni_attenuation=1.4;glow.shadow_enabled=false
		glow.set_meta("day_energy",.7);glow.set_meta("night_energy",1.4);glow.set_meta("priority",2);glow.add_to_group("night_lamps")
