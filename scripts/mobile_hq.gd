extends Node
var dish:Node3D
var time=0.0
var wheels:Array=[]
var previous=Vector3.ZERO
func _ready():
	taillights(get_parent())
	preload("res://scripts/world_lighting.gd").headlights(get_parent(),true,true)
	get_parent().add_child(preload("res://scripts/base_alert.gd").new())
	dish=get_parent().find_child("RadarDish",true,false)
	wheels=get_parent().find_children("WheelPivot*","Node3D",true,false)
	previous=get_parent().global_position
func _process(delta):
	time+=delta
	var displacement=get_parent().global_position-previous;previous=get_parent().global_position
	var radius=.2688*get_parent().global_basis.get_scale().x
	var distance=displacement.dot(get_parent().global_basis.z.normalized())
	for wheel in wheels:wheel.rotate_x(distance/maxf(.01,radius))
	if is_instance_valid(dish):dish.rotation.y=sin(time*.23)*.75

# The HQ always stands across the field: facing left or right, never toward or away from the camera.
static func orientation(seed_value:int)->float:
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+52379
	return PI*.5 if rng.randi()%2==0 else -PI*.5

static func taillights(parent:Node3D):
	if parent.has_node("TaillightRig"):return
	var bounds:AABB;var found=false
	for mesh in parent.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null:continue
		var box=parent.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		bounds=bounds.merge(box) if found else box;found=true
	if not found:return
	var height=bounds.position.y+bounds.size.y*.3
	var lamps=parent.find_children("Amber headlamp*","MeshInstance3D",true,false)
	if not lamps.is_empty():height=parent.to_local(lamps[0].global_position).y
	var rig=Node3D.new();rig.name="TaillightRig";parent.add_child(rig)
	var red=Color("ff1a12");var glow=Visuals.material(red,true);glow.emission_energy_multiplier=1.6
	# The model carries two tall red pillars on its rear corners (art_requests/hq_vehicle_v2, author 3 Oct):
	# they glow themselves, the rig only adds the light they cast on the ground.
	var pillars=parent.find_children("Taillight pillar*","MeshInstance3D",true,false).filter(func(m):return not "frame" in str(m.name))
	if not pillars.is_empty():
		for pillar in pillars:
			pillar.material_override=glow
			var spot=rig.to_local(pillar.global_position);spot.y=bounds.position.y+bounds.size.y*.25
			var light=SpotLight3D.new();light.name="Taillight";rig.add_child(light);light.position=spot+Vector3(0,0,-.06)
			light.rotation.x=deg_to_rad(-55)
			light.light_color=red;light.light_energy=.56;light.spot_range=1.8;light.spot_angle=48;light.spot_attenuation=.8;light.shadow_enabled=false
		return
	# Authored HQ points +Z, so the rear is the minimum Z face.
	for side in [-1,1]:
		var pos=Vector3(bounds.get_center().x+side*bounds.size.x*.36,height,bounds.position.z-.012)
		var lamp=Visuals.box(rig,pos,Vector3(.14,.07,.03),red);lamp.name="Red taillamp";lamp.material_override=glow
		# Aimed backward and down so the glow lands on the ground behind the HQ.
		var light=SpotLight3D.new();light.name="Taillight";rig.add_child(light);light.position=pos+Vector3(0,0,-.04)
		light.rotation.x=deg_to_rad(-55)
		light.light_color=red;light.light_energy=.56;light.spot_range=1.8;light.spot_angle=48;light.spot_attenuation=.8;light.shadow_enabled=false
