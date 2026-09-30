class_name ExitFlag
extends RefCounted
## Exit flag: metal pole on a concrete footing with sandbags, waving cloth (shaders/world/flag_cloth).
const CLOTH_SIZE=Vector2(1.15,.68)
const POLE_HEIGHT=2.7

static func build(parent:Node3D)->Node3D:
	var flag=Node3D.new();flag.name="ExitFlag";parent.add_child(flag)
	Visuals.box(flag,Vector3(0,.09,0),Vector3(.5,.18,.5),Color("9a9d93"))
	Visuals.box(flag,Vector3(0,.22,0),Vector3(.34,.1,.34),Color("74786f"))
	for i in range(5):
		var bag=MeshInstance3D.new();var capsule=CapsuleMesh.new();capsule.radius=.09;capsule.height=.34;capsule.radial_segments=6;capsule.rings=1
		bag.mesh=capsule;bag.material_override=Visuals.material(Color("b0ac91"));flag.add_child(bag)
		var a=TAU*i/5.0;bag.position=Vector3(cos(a)*.36,.08,sin(a)*.36);bag.rotation=Vector3(0,-a,PI/2)
	var pole=MeshInstance3D.new();var cylinder=CylinderMesh.new()
	cylinder.top_radius=.03;cylinder.bottom_radius=.04;cylinder.height=POLE_HEIGHT;cylinder.radial_segments=8;cylinder.rings=1
	pole.mesh=cylinder;flag.add_child(pole);pole.position.y=.27+POLE_HEIGHT*.5
	var steel=Visuals.material(Color("8f969a"));steel.resource_name="flag_steel";Visuals.cozy_material(steel);pole.material_override=steel
	var finial=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=.07;sphere.height=.14;sphere.radial_segments=8;sphere.rings=4
	finial.mesh=sphere;flag.add_child(finial);finial.position.y=.3+POLE_HEIGHT
	var gold=Visuals.material(Color("c9a24a"));gold.metallic=.8;gold.roughness=.35;finial.material_override=gold
	var cloth=MeshInstance3D.new();cloth.name="Cloth";var plane=PlaneMesh.new()
	plane.size=CLOTH_SIZE;plane.subdivide_width=14;plane.subdivide_depth=7;plane.orientation=PlaneMesh.FACE_Z
	cloth.mesh=plane;flag.add_child(cloth)
	cloth.position=Vector3(CLOTH_SIZE.x*.5+.03,.27+POLE_HEIGHT-CLOTH_SIZE.y*.5-.06,0)
	var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/world/flag_cloth.gdshader");cloth.material_override=mat
	return flag
