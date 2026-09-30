extends Node
var dish:Node3D
var time=0.0
var wheels:Array=[]
var previous=Vector3.ZERO
func _ready():
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

static func orientation(seed_value:int)->float:
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+52379
	return rng.randi_range(0,3)*PI*.5
