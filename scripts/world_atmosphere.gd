extends Node3D
## Three small GPU batches; no per-particle processing, physics or light sources.
var materials:Array=[]
var batches:Array=[]
var tilt:CanvasLayer
var haze:ColorRect
var clouds:Array[GeometryInstance3D]=[]
var anchored=false
## Battle edge clouds: two big blurry clusters near the camera that drift slowly along the left
## and right edges of the field (up or down). They wrap far beyond the screen and fade in and out near
## the ends of their lane, so a cloud never pops up in view. Visual RNG only.
var drifters:Array=[]
var drift_span=20.0
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	var rng=RandomNumberGenerator.new();rng.seed=74983
	for kind in range(3):
		var multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_custom_data=true
		var quad=QuadMesh.new();quad.size=Vector2.ONE;multimesh.mesh=quad;multimesh.instance_count=[26,10,7][kind]
		for i in range(multimesh.instance_count):
			var scale_value=rng.randf_range(.04,.10) if kind!=2 else rng.randf_range(.07,.12)
			multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_value),Vector3(rng.randf_range(-11,11),rng.randf_range(.3,3.5),rng.randf_range(-9,9))))
			multimesh.set_instance_custom_data(i,Color(rng.randf(),0,0,1))
		var batch=MultiMeshInstance3D.new();batch.multimesh=multimesh;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;batch.extra_cull_margin=3
		var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/world/atmosphere.gdshader");mat.set_shader_parameter("kind",kind);batch.material_override=mat;add_child(batch);materials.append(mat);batches.append(batch)
	tilt=CanvasLayer.new();tilt.layer=0;add_child(tilt)
	var overlay=ColorRect.new();tilt.add_child(overlay);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material=ShaderMaterial.new();material.shader=preload("res://shaders/world/tilt_edges.gdshader");overlay.material=material
	haze=ColorRect.new();tilt.add_child(haze);haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);haze.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var haze_material=ShaderMaterial.new();haze_material.shader=preload("res://shaders/world/haze.gdshader");haze.material=haze_material
	Settings.changed.connect(apply);apply()
func apply():
	var night=Settings.values.world_lighting=="night"
	for mat in materials:mat.set_shader_parameter("night",night)
	var biome="forest"
	if get_parent().has_method("room_palette"):biome=get_parent().room_palette().ambience
	materials[2].set_shader_parameter("strength",1.0 if biome in ["forest","marsh","city"] else 0.0)
	for batch in batches:batch.visible=Settings.values.get("atmosphere",true)
	for cloud in clouds:
		cloud.visible=Settings.values.get("atmosphere",true)
		# Night clouds are dim shapes, not glowing blobs (0.8 dark night).
		cloud.material_override.set_shader_parameter("light_color",Color("39425a") if night else Color("fffdf8"))
		cloud.material_override.set_shader_parameter("shade_color",Color("1b2133") if night else Color("cbc8dd"))
	var cozy=Settings.values.get("shaders",true)
	tilt.visible=cozy
	tilt.get_child(0).visible=Settings.values.get("tilt_shift",true)
	var style:Dictionary=preload("res://scripts/world_lighting.gd").STYLES.get(Settings.values.get("shader_style","pastel"),{})
	haze.visible=cozy and Settings.values.get("haze",true)
	var time:Dictionary=preload("res://scripts/world_lighting.gd").moment(get_parent(),night)
	haze.material.set_shader_parameter("haze_color",Color(time.haze) if not time.is_empty() else Color("33405a") if night else Color(style.get("haze","dfe4ee")))
	var weather:Dictionary=preload("res://scripts/systems/weather.gd").look(get_parent())
	if not weather.is_empty():
		haze.visible=cozy
		haze.material.set_shader_parameter("haze_color",Color(weather.haze).darkened(.6) if night else Color(weather.haze))
	# Readability first: haze only hints at depth (it washed out the field before).
	haze.material.set_shader_parameter("amount",(float(style.get("haze_amount",.3))+float(weather.get("haze_add",0.0)))*(.8 if night else 1.0)*.55)
func battle_clouds(grid_size:int,seed_value:int):
	for entry in drifters:
		clouds.erase(entry.node)
		if is_instance_valid(entry.node):entry.node.queue_free()
	drifters.clear()
	var rng=RandomNumberGenerator.new();rng.seed=hash([seed_value,"edge_clouds"])
	drift_span=grid_size+44.0
	for side in [-1.0,1.0]:
		var discs:Array=[];var scale_value=rng.randf_range(6.0,8.4)
		for i in range(rng.randi_range(5,7)):
			var offset=Vector3(rng.randf_range(-1.6,1.6),rng.randf_range(-.3,.6),rng.randf_range(-1.0,1.0))*scale_value*.55
			discs.append([offset,(rng.randf_range(1.5,2.3)-absf(offset.x)*.08)*scale_value*.6,rng.randf_range(.75,1.0),rng.randf()])
		var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true
		var quad=QuadMesh.new();quad.size=Vector2.ONE;multi.mesh=quad;multi.instance_count=discs.size()
		for i in range(discs.size()):
			multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*discs[i][1]),discs[i][0]))
			multi.set_instance_custom_data(i,Color(discs[i][2],discs[i][3],0,1))
		var node=MultiMeshInstance3D.new();node.name="EdgeCloud";node.multimesh=multi;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.extra_cull_margin=12
		var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/world/map_clouds.gdshader");mat.set_shader_parameter("opacity",.55);mat.set_shader_parameter("screen_edge_fade",1.0);node.material_override=mat
		add_child(node);clouds.append(node)
		node.position=Vector3(side*(grid_size*.5+rng.randf_range(7.6,9.8)),rng.randf_range(10.0,12.5),rng.randf_range(-drift_span*.5,drift_span*.5))
		drifters.append({"node":node,"speed":rng.randf_range(.18,.32)*(1.0 if rng.randf()<.5 else -1.0)})
	apply()

func _process(_delta):
	for entry in drifters:
		var node:Node3D=entry.node
		if not is_instance_valid(node):continue
		node.position.z+=float(entry.speed)*_delta
		if node.position.z>drift_span*.5:node.position.z=-drift_span*.5
		elif node.position.z<-drift_span*.5:node.position.z=drift_span*.5
		# Fade over the last 10 units of the lane (all of it off screen): the wrap is never seen.
		var edge=drift_span*.5-absf(node.position.z)
		node.material_override.set_shader_parameter("opacity",.55*clampf(edge/10.0,0.0,1.0))
	var camera=get_viewport().get_camera_3d()
	if camera:
		var forward=-camera.global_basis.z
		var center=camera.global_position+forward*(camera.global_position.y/maxf(.1,-forward.y))
		if anchored:
			# Clouds drift 12% faster than the ground while scrolling: a small parallax.
			for cloud in clouds:cloud.position.z=-(center.z-global_position.z)*.12
		else:global_position=Vector3(center.x,0,center.z)

func anchor_to_map(length:float):
	# Cover the complete scrolling map once; camera movement never repositions dust.
	anchored=true;position=Vector3(0,0,-length*.5)
	var rng=RandomNumberGenerator.new();rng.seed=74983
	for kind in range(batches.size()):
		var multi=batches[kind].multimesh
		multi.instance_count=ceili([7,10,7][kind]*maxf(1.0,(length+18)/18.0))
		materials[kind].set_shader_parameter("near_bokeh",kind==0)
		# The near-camera bokeh read as dirt on the lens; soft clouds replace it.
		if kind==0:multi.instance_count=0;continue
		for i in range(multi.instance_count):
			var size=rng.randf_range(.55,1.15) if kind==0 else rng.randf_range(.04,.10) if kind==1 else rng.randf_range(.07,.12)
			var height=rng.randf_range(11.5,15.5) if kind==0 else rng.randf_range(.3,3.5)
			multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),Vector3(rng.randf_range(-13,13),height,rng.randf_range(-length*.5-9,length*.5+15))))
			multi.set_instance_custom_data(i,Color(rng.randf(),0,0,1))
	add_map_clouds(length)
	apply()

func add_map_clouds(length:float):
	# Rare puffy clusters along the left/right screen edges. Height stays under the bottom edge
	# of the near-vertical ortho view (~10 units), otherwise the near plane clips them.
	var rng=RandomNumberGenerator.new();rng.seed=51377
	var discs:Array=[]
	# Extend well past both ends so the top and bottom of the screen never run out of clouds.
	var z=-length*.5-34.0
	var side=1.0
	while z<length*.5+40.0:
		z+=rng.randf_range(14.0,22.0)
		if rng.randf()<.25:continue
		if rng.randf()<.7:side=-side
		var base=Vector3(side*rng.randf_range(15.0,21.0),rng.randf_range(5.0,7.0),z)
		var scale_value=rng.randf_range(3.0,4.4)
		for i in range(rng.randi_range(6,9)):
			var offset=Vector3(rng.randf_range(-2.2,2.2),rng.randf_range(-.4,.9),rng.randf_range(-1.2,1.2))*scale_value
			# Larger discs in the middle make a rounded crown.
			var size=(rng.randf_range(1.6,2.6)-absf(offset.x)*.25)*scale_value
			discs.append([base+offset,size,rng.randf(),rng.randf()])
	var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true
	var quad=QuadMesh.new();quad.size=Vector2.ONE;multi.mesh=quad;multi.instance_count=discs.size()
	for i in range(discs.size()):
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*discs[i][1]),discs[i][0]))
		multi.set_instance_custom_data(i,Color(discs[i][2],discs[i][3],0,1))
	var mesh=MultiMeshInstance3D.new();mesh.name="Clouds";mesh.multimesh=multi;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.extra_cull_margin=6
	var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/world/map_clouds.gdshader");mesh.material_override=mat
	add_child(mesh);clouds.append(mesh)
