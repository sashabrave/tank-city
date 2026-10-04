extends Node3D
## Victory fireworks over the field after the general falls (T-261): rockets climb from the field edges and burst
## into coloured sparks, a few seconds, then the node frees itself. Visual only — its own RNG, no gameplay state.
const COLORS=[Color("ffd56a"),Color("ff7a5c"),Color("8fe3ff"),Color("b7f27a"),Color("f2a3ff")]
const ROCKETS:=12
const SPAN:=4.2
var rng:=RandomNumberGenerator.new()
var half:=6.0
static func launch(arena:Node3D,size:float)->Node3D:
	var show=load("res://scripts/fireworks.gd").new();show.name="Fireworks";show.half=size*.5;arena.add_child(show);return show
func _ready():
	rng.randomize()
	for i in range(ROCKETS):
		var timer=get_tree().create_timer(SPAN*i/ROCKETS+rng.randf_range(0,.25),false)
		timer.timeout.connect(rocket)
	get_tree().create_timer(SPAN+2.5,false).timeout.connect(queue_free)
func glow(color:Color,radius:float)->MeshInstance3D:
	var mesh=SphereMesh.new();mesh.radius=radius;mesh.height=radius*2;mesh.radial_segments=8;mesh.rings=4
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=color
	mat.emission_enabled=true;mat.emission=color;mat.emission_energy_multiplier=2.5;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var node=MeshInstance3D.new();node.mesh=mesh;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node);return node
func rocket():
	if not is_inside_tree():return
	var color:Color=COLORS[rng.randi_range(0,COLORS.size()-1)]
	var side=-1.0 if rng.randf()<.5 else 1.0
	var from=Vector3(side*rng.randf_range(half*.4,half),0,rng.randf_range(-half,half*.6))
	var top=Vector3(rng.randf_range(-half*.6,half*.6),rng.randf_range(4.5,6.5),rng.randf_range(-half*.7,half*.3))
	var shell=glow(color.lightened(.4),.2);shell.position=from
	var climb=create_tween();climb.tween_property(shell,"position",top,.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	climb.tween_callback(func():shell.queue_free();burst(top,color))
	Game.sound("countdown_tick",self)
func burst(at:Vector3,color:Color):
	var light=OmniLight3D.new();add_child(light);light.position=at;light.light_color=color;light.light_energy=5.0;light.omni_range=9.0
	var fade=create_tween();fade.tween_property(light,"light_energy",0.0,.8);fade.tween_callback(light.queue_free)
	for i in range(26):
		var spark=glow(color if i%4 else Color.WHITE,.17);spark.position=at
		var dir=Vector3(rng.randf_range(-1,1),rng.randf_range(-.6,1),rng.randf_range(-1,1)).normalized()*rng.randf_range(2.4,3.8)
		var fly=create_tween().set_parallel(true)
		fly.tween_property(spark,"position",at+dir+Vector3.DOWN*.8,1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fly.tween_property(spark.material_override,"albedo_color:a",0.0,1.0).set_delay(.4)
		fly.chain().tween_callback(spark.queue_free)
	Game.sound("rare_reveal",self)
