extends Node3D
## Very rare biome particles over the battle field: a leaf, ash flake, sand grain, seed fluff or frost crystal
## drifts through now and then (at most MAX_ALIVE at once). They ride the wind of the current weather so they
## never move against rain, snow or a sandstorm. Visual only: own RNG, no game state. Off with the atmosphere setting.
const MAX_ALIVE=3
const KINDS={
	"forest":{"colors":["c98a3a","8aa04e","b0633a"],"size":Vector2(.13,.08),"fall":.35,"flutter":1.0},
	"marsh":{"colors":["eeeadc","d8d4c4"],"size":Vector2(.07,.07),"fall":.12,"flutter":.6},
	"desert":{"colors":["c9b07a","a88c5c"],"size":Vector2(.05,.04),"fall":.25,"flutter":.3},
	"inferno":{"colors":["3a3633","56504a","ff8a3d"],"size":Vector2(.07,.06),"fall":.18,"flutter":.7},
	"mountains":{"colors":["e8f2f8","cfe0ea"],"size":Vector2(.06,.06),"fall":.3,"flutter":.5},
}
var arena
var weather
var rng=RandomNumberGenerator.new()
var wait=0.0
var alive:Array=[]
var style:Dictionary={}
func setup(context,weather_node):
	arena=context;weather=weather_node;name="BiomeParticles"
	rng.seed=hash([Game.visual_run_seed,arena.room_index,"biome_particles"])
	style=KINDS.get(str(arena.room_palette().get("ambience","forest")),KINDS.forest)
	wait=rng.randf_range(4.0,9.0)
func _process(delta):
	for p in alive.duplicate():
		if not is_instance_valid(p.node):alive.erase(p);continue
		step(p,delta)
	if not Settings.values.get("atmosphere",true) or not is_instance_valid(arena) or arena.phase not in ["combat","countdown"]:return
	wait-=delta
	if wait>0 or alive.size()>=MAX_ALIVE:return
	wait=rng.randf_range(6.0,14.0)
	spawn()
func wind()->Vector3:
	var w=weather.wind() if is_instance_valid(weather) and weather.has_method("wind") else Vector3(.45,0,.08)
	return w if w.length()>.2 else Vector3(.3,0,.05)
func spawn():
	var half=arena.grid_size*.5+1.5;var w=wind()
	var start=Vector3(-half*signf(w.x if absf(w.x)>.01 else 1.0),rng.randf_range(2.5,4.5),rng.randf_range(-half,half*.7))
	var quad=QuadMesh.new();quad.size=style.size
	var node=MeshInstance3D.new();node.mesh=quad;add_child(node);node.position=start;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.albedo_color=Color(style.colors[rng.randi_range(0,style.colors.size()-1)])
	node.material_override=material
	var speed=rng.randf_range(.8,1.2)
	alive.append({"node":node,"velocity":w*speed+Vector3(0,-float(style.fall),0),"phase":rng.randf()*TAU,"age":0.0,"life":rng.randf_range(9.0,14.0),"spin":rng.randf_range(-2.5,2.5)})
func step(p:Dictionary,delta:float):
	p.age+=delta
	var node:MeshInstance3D=p.node;var flutter=float(style.flutter)
	node.position+=p.velocity*delta+Vector3(0,sin(p.age*2.6+p.phase)*.25*flutter,cos(p.age*1.9+p.phase)*.2*flutter)*delta
	node.rotation=Vector3(sin(p.age*1.7+p.phase)*flutter,p.age*p.spin,cos(p.age*1.3)*flutter*.6)
	var t=p.age/p.life
	node.material_override.albedo_color.a=smoothstep(0.0,.08,t)*(1.0-smoothstep(.85,1.0,t))
	var half=arena.grid_size*.5+3.0
	if p.age>=p.life or node.position.y<.02 or absf(node.position.x)>half:
		node.queue_free();alive.erase(p)
