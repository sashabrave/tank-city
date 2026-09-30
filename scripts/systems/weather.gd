extends Node3D
## Battle weather: visual only. Deterministic per run from the visual seed; each new stage keeps
## the previous weather unless a chance roll changes it. Precipitation is shader-driven MultiMesh.
const BIOMES=preload("res://scripts/biome_catalog.gd")
const CHANGE_CHANCE=.35
const KINDS=["clear","rain","snow","fog","sandstorm"]
## Lighting multipliers read by WorldLighting; haze colour/amount by WorldAtmosphere.
const LOOK={
	"rain":{"sun":.55,"shadow":.6,"ambient":1.1,"fill":"a9b4c6","saturation":.86,"haze":"c3ccd6","haze_add":.2},
	"snow":{"sun":.8,"shadow":.75,"ambient":1.08,"fill":"d3dcec","saturation":.92,"haze":"eef2f6","haze_add":.16},
	"fog":{"sun":.6,"shadow":.5,"ambient":1.12,"fill":"cfd4da","saturation":.88,"haze":"dde2e6","haze_add":.36},
	"sandstorm":{"sun":.75,"shadow":.7,"ambient":1.05,"fill":"dcc6a0","saturation":.95,"haze":"e6cc9c","haze_add":.3},
}
var arena
var kind="clear"
var batches:Array[MultiMeshInstance3D]=[]

static func allowed(entry:Dictionary)->Array:
	if "ice" in entry.kinds or entry.get("vegetation","")=="frost":return ["clear","snow","fog"]
	if entry.ambience=="desert":return ["clear","sandstorm","fog"]
	return ["clear","rain","fog"]

## Weather of the context's current room, or "" outside battle.
static func pick(context:Node)->String:
	if context==null or not context.has_method("room_palette") or not "room_index" in context:return ""
	var choice=str(Settings.values.get("weather","random"))
	if choice in KINDS:return choice
	var rng=RandomNumberGenerator.new();rng.seed=hash([Game.visual_run_seed,"weather"])
	var current="clear"
	for room in range(int(context.room_index)+1):
		var options=allowed(BIOMES.entry(context.run_seed,room))
		var roll=rng.randf();var index=rng.randi_range(0,options.size()-1)
		if roll<CHANGE_CHANCE or current not in options:current=options[index]
	return current

static func look(context:Node)->Dictionary:return LOOK.get(pick(context),{})

func setup(context):
	arena=context;name="Weather"
	build()
	Settings.changed.connect(apply);apply()

func build():
	kind=pick(arena)
	var size=float(arena.grid_size)+4.0
	match kind:
		"rain":
			batch(0,260,size,Vector2(.018,.34));batch(4,48,size,Vector2(.3,.3))
		"snow":
			batch(1,200,size,Vector2(.07,.07))
		"fog":
			batch(3,16,size,Vector2(2.6,2.6))
		"sandstorm":
			batch(2,170,size,Vector2(.24,.022));batch(3,8,size,Vector2(3.2,3.2))
	if kind in ["snow","sandstorm"]:preload("res://scripts/systems/block_decor.gd").drifts(arena,kind)

func clear():
	for batch_node in batches:batch_node.queue_free()
	batches.clear()
	for node in get_tree().get_nodes_in_group("weather_drifts"):
		if arena.is_ancestor_of(node):node.remove_from_group("weather_drifts");node.queue_free()

func batch(shader_kind:int,count:int,size:float,quad:Vector2):
	var rng=RandomNumberGenerator.new();rng.seed=hash([Game.visual_run_seed,arena.room_index,"weather",shader_kind])
	var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true
	var mesh=QuadMesh.new();mesh.size=quad;multi.mesh=mesh;multi.instance_count=count
	for i in range(count):
		# Only X/Z scatter lives in the transform; fall and drift are animated by the shader.
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(rng.randf_range(-.5,.5)*size,0,rng.randf_range(-.5,.5)*size)))
		multi.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),rng.randf_range(.7,1.3),1))
	var instance=MultiMeshInstance3D.new();instance.multimesh=multi;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb=AABB(Vector3(-size,-1,-size),Vector3(size*2,9,size*2))
	var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/world/weather.gdshader")
	mat.set_shader_parameter("kind",shader_kind);mat.set_shader_parameter("area",size)
	instance.material_override=mat;add_child(instance);batches.append(instance)

func apply():
	# The settings dropdown can switch weather mid-battle.
	if pick(arena)!=kind:clear();build()
	var night=Settings.values.get("world_lighting","day")=="night"
	for batch_node in batches:batch_node.material_override.set_shader_parameter("night",night)
