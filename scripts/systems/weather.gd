extends Node3D
## Battle weather: visual only. Deterministic per run from the visual seed; each new stage keeps
## the previous weather unless a chance roll changes it. Precipitation is shader-driven MultiMesh.
const BIOMES=preload("res://scripts/biome_catalog.gd")
const CHANGE_CHANCE=.35
## Clear sky dominates; rain is a rare event (it hurts readability), a downpour rarer still.
const WEIGHTS={"clear":1.0,"fog":.22,"rain":.07,"snow":.3,"sandstorm":.18}
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
var rain_style=""
## Thunderstorm during any rain (T-074): a flash of cold light over the field now and then, thunder a moment
## later. Own visual RNG; heavier rain flashes more often.
const STORM_GAPS={"drizzle":Vector2(16,30),"shower":Vector2(9,18),"downpour":Vector2(5,11)}
var storm_light:DirectionalLight3D
var storm_rng:=RandomNumberGenerator.new()
var storm_wait=0.0
## Three rains, chosen per room from the visual seed: count, streak size, fall speed, wind slant,
## opacity, ripples and glossy puddles. All visual.
const RAIN={
	"drizzle":{"count":120,"quad":Vector2(.03,.22),"fall":1.0,"slant":.35,"strength":.75,"ripples":30,"puddles":5},
	"shower":{"count":190,"quad":Vector2(.034,.34),"fall":1.35,"slant":.9,"strength":1.0,"ripples":48,"puddles":9},
	"downpour":{"count":300,"quad":Vector2(.038,.5),"fall":1.8,"slant":1.6,"strength":1.2,"ripples":80,"puddles":14},
}
static func pick_rain(context:Node)->String:return rain_for(int(own_look(context).room_index))
## The hub on the practice arena keeps its own per-visit look (hub.gd room_palette/run_seed/room_index).
static func own_look(context:Node)->Node:
	var ground=context.get("playground") if context!=null else null
	if ground!=null and is_instance_valid(ground) and ground.has_method("room_palette") and ground.get("room_index")!=null:return ground
	return context
static func rain_for(index:int)->String:
	var forced=str(Settings.values.get("rain_style",""))
	if forced in RAIN:return forced
	var rng=RandomNumberGenerator.new();rng.seed=hash([Game.visual_run_seed,index,"rain_style"])
	var roll=rng.randf()
	return "drizzle" if roll<.62 else "shower" if roll<.92 else "downpour"

static func allowed(entry:Dictionary)->Array:
	if "ice" in entry.kinds or entry.get("vegetation","")=="frost":return ["clear","snow","fog"]
	if entry.ambience=="desert":return ["clear","sandstorm","fog"]
	return ["clear","rain","fog"]

## Weather of the context's current room, or "" outside battle.
static func pick(context:Node)->String:
	context=own_look(context)
	if context==null or not context.has_method("room_palette") or not "room_index" in context:return ""
	# Rooms between fields (the arena in service mode) stay in fair weather.
	if context.get("cozy_light")==true:return ""
	return for_room(context.run_seed,int(context.room_index),context.run.route_choices if "run" in context and context.run else {})
## Weather of room `index` of a run (the route map shows the same weather the battle will have).
static func for_room(run_seed:int,index:int,choices:Dictionary={})->String:
	var choice=str(Settings.values.get("weather","random"))
	if choice in KINDS:return choice
	var rng=RandomNumberGenerator.new();rng.seed=hash([Game.visual_run_seed,"weather"])
	var current="clear"
	for room in range(index+1):
		var options=allowed(BIOMES.entry(run_seed,room,BIOMES.chosen_lane(run_seed,room,choices)))
		var roll=rng.randf();var pick_roll=rng.randf()
		if roll<CHANGE_CHANCE or current not in options:current=weighted(options,pick_roll)
	return current

static func weighted(options:Array,roll:float)->String:
	var total=0.0
	for id in options:total+=float(WEIGHTS.get(id,.2))
	var at=roll*total
	for id in options:
		at-=float(WEIGHTS.get(id,.2))
		if at<=0:return id
	return options[0]

static func look(context:Node)->Dictionary:return LOOK.get(pick(context),{})
## Wind of the current weather along +X (the way rain slants, snow drifts and sand streaks), units per second.
## Biome particles ride it so they never fight the weather.
func wind()->Vector3:
	match kind:
		"rain":var style=RAIN.get(rain_style,RAIN.shower);return Vector3(float(style.slant)*float(style.fall)*.9,0,0)
		"snow":return Vector3(.35,0,.05)
		"sandstorm":return Vector3(3.2,0,.15)
		"fog":return Vector3(.15,0,0)
	return Vector3(.45,0,.08)

func setup(context):
	arena=context;name="Weather"
	build()
	Settings.changed.connect(apply);apply()

func build():
	kind=pick(arena)
	var size=float(arena.grid_size)+4.0
	match kind:
		"rain":
			rain_style=pick_rain(arena);var style=RAIN[rain_style]
			# Rain covers the whole view, not just the field: a wider area with proportionally more streaks.
			var streaks=batch(0,int(style.count*2.4),size+14.0,style.quad)
			for key in ["fall","slant","strength"]:streaks.material_override.set_shader_parameter(key,style[key])
			batch(4,style.ripples,size,Vector2(.3,.3)).material_override.set_shader_parameter("strength",style.strength)
			puddles(style.puddles)
			storm_rng.seed=hash([Game.visual_run_seed,arena.room_index,"storm"]);storm_wait=storm_rng.randf_range(2.5,6.0)
			storm_light=DirectionalLight3D.new();storm_light.name="StormFlash";storm_light.light_color=Color("dce6ff");storm_light.light_energy=0.0
			storm_light.shadow_enabled=false;storm_light.rotation_degrees=Vector3(-62,storm_rng.randf_range(0,360),0);add_child(storm_light)
		"snow":
			batch(1,200,size,Vector2(.07,.07))
		"fog":
			batch(3,16,size,Vector2(2.6,2.6))
		"sandstorm":
			batch(2,170,size,Vector2(.24,.022));batch(3,8,size,Vector2(3.2,3.2))
	if kind in ["snow","sandstorm"]:preload("res://scripts/systems/block_decor.gd").drifts(arena,kind)

func clear():
	if is_instance_valid(storm_light):storm_light.queue_free()
	storm_light=null
	for batch_node in batches:batch_node.queue_free()
	batches.clear()
	if not is_inside_tree() or not is_instance_valid(arena):return
	for node in get_tree().get_nodes_in_group("weather_drifts"):
		if arena.is_ancestor_of(node):node.remove_from_group("weather_drifts");node.queue_free()

## Glossy rain puddles on open floor: flat blobs that only catch the light. They block nothing.
func puddles(count:int):
	var rng=RandomNumberGenerator.new();rng.seed=hash([Game.visual_run_seed,arena.room_index,"puddles"])
	var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true
	var mesh=QuadMesh.new();mesh.size=Vector2(1,1);mesh.orientation=PlaneMesh.FACE_Y;multi.mesh=mesh
	var spots=[]
	for attempt in range(count*12):
		if spots.size()>=count:break
		var cell=Vector2i(rng.randi_range(1,arena.grid_size-2),rng.randi_range(1,arena.grid_size-2))
		if arena.walls.has(cell) or arena.terrain.patches.has(cell*2) or arena.trenches.has(cell) or cell==arena.base_cell:continue
		var pos=arena.world_pos(cell)+Vector3(rng.randf_range(-.3,.3),.012,rng.randf_range(-.3,.3))
		var basis=Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(rng.randf_range(.65,1.25),1,rng.randf_range(.5,.9)))
		spots.append([Transform3D(basis,pos),Color(rng.randf(),rng.randf(),rng.randf(),1)])
	multi.instance_count=spots.size()
	for i in range(spots.size()):multi.set_instance_transform(i,spots[i][0]);multi.set_instance_custom_data(i,spots[i][1])
	var instance=MultiMeshInstance3D.new();instance.name="Puddles";instance.multimesh=multi;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/world/puddle.gdshader");instance.material_override=mat
	add_child(instance);batches.append(instance)

func batch(shader_kind:int,count:int,size:float,quad:Vector2)->MultiMeshInstance3D:
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
	return instance

func apply():
	# The settings dropdown can switch weather mid-battle.
	if pick(arena)!=kind:clear();build()
	var night=Settings.values.get("world_lighting","day")=="night"
	for batch_node in batches:batch_node.material_override.set_shader_parameter("night",night)  # puddles read it too
func _process(delta):
	if not is_instance_valid(storm_light) or not is_instance_valid(arena) or arena.get("phase") not in ["combat","countdown"]:return
	storm_wait-=delta
	if storm_wait>0.0:return
	var gap:Vector2=STORM_GAPS.get(rain_style,STORM_GAPS.shower);storm_wait=storm_rng.randf_range(gap.x,gap.y)
	var night=Settings.values.get("world_lighting","day")=="night"
	var peak=(2.6 if night else 1.6)*storm_rng.randf_range(.75,1.1)
	# Two or three uneven strokes, like a real flash.
	var tween=create_tween()
	for i in range(storm_rng.randi_range(2,3)):
		tween.tween_property(storm_light,"light_energy",peak*(1.0 if i==0 else storm_rng.randf_range(.45,.8)),.04)
		tween.tween_property(storm_light,"light_energy",peak*.12,storm_rng.randf_range(.06,.12))
	tween.tween_property(storm_light,"light_energy",0.0,.35)
	get_tree().create_timer(storm_rng.randf_range(.35,1.6)).timeout.connect(func():if is_inside_tree():Game.sound("weather_thunder",self))
