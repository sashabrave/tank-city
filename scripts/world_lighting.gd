extends Node
## Only world lighting changes; UI colors and camera geometry are untouched.
var environment:Environment
var sun:DirectionalLight3D
var day_background:Color
var elapsed=0.0
## Shader style profiles. Only lighting/post values; geometry and gameplay are untouched.
const STYLES={
	"pastel":{"fill":"b4bfdc","sun":"ffe9cc","sun_energy":1.12,"sun_angle":Vector3(-50,-38,0),"ambient":.5,"exposure":.88,"white":1.7,"contrast":1.02,"saturation":1.25,"softness":2.6,"shadow":.95,"specular":.9,"ssao":1.2,"glow":.5,"haze":"e2e7f0","haze_amount":.32,"sky_top":"a9c9ea","sky_horizon":"f6efe3","ground":"cfc6b4"},
	"cozy":{"fill":"c9cdc3","sun":"ffdbad","sun_energy":.95,"sun_angle":Vector3(-42,-32,0),"ambient":.48,"exposure":1.0,"white":1.0,"contrast":1.0,"saturation":1.0,"softness":1.5,"shadow":1.0,"specular":.6,"ssao":1.45,"glow":.35,"haze":"d9dccf","haze_amount":.18,"sky_top":"8fb0cc","sky_horizon":"e6e6dc","ground":"b9b6a4"},
	"golden":{"fill":"c4b3d8","sun":"ffc58a","sun_energy":1.18,"sun_angle":Vector3(-30,-62,0),"ambient":.42,"exposure":.9,"white":1.5,"contrast":1.06,"saturation":1.2,"softness":2.2,"shadow":.95,"specular":1.0,"ssao":1.25,"glow":.65,"haze":"f3d6b4","haze_amount":.34,"sky_top":"9cb6d8","sky_horizon":"ffe0bb","ground":"d4b996"},
	"overcast":{"fill":"d3d8de","sun":"eef1f4","sun_energy":.62,"sun_angle":Vector3(-62,-28,0),"ambient":.66,"exposure":.92,"white":1.5,"contrast":.96,"saturation":.92,"softness":7.0,"shadow":.7,"specular":.7,"ssao":1.5,"glow":.3,"haze":"c9d0d6","haze_amount":.42,"sky_top":"c3ccd6","sky_horizon":"e3e6e8","ground":"b8bcb8"},
}
## Sun moments for battle rooms. Day theme: dawn to sunset, weighted toward golden light;
## night theme: end of sunset, moonlight, early pre-dawn. Elevation in degrees.
const MOMENTS={
	"dawn":{"night":false,"weight":.22,"sun":"ffc6a6","energy":.95,"elevation":Vector2(15,22),"fill":"b3b6d8","ambient":.95,"horizon":"ffdcc8","haze":"eee0dc"},
	"morning":{"night":false,"weight":.2,"sun":"ffe2b4","energy":1.0,"elevation":Vector2(24,36),"fill":"b4c2dc","ambient":1.0,"horizon":"f7ecdc","haze":"e4e8ee"},
	"noon":{"night":false,"weight":.1,"sun":"fff4e2","energy":1.05,"elevation":Vector2(55,68),"fill":"bcc6d8","ambient":1.05,"horizon":"eef1ee","haze":"e2e7ee"},
	"golden":{"night":false,"weight":.26,"sun":"ffc98a","energy":1.05,"elevation":Vector2(19,28),"fill":"c3b3d6","ambient":.92,"horizon":"ffe0b8","haze":"f4dcc0"},
	"sunset":{"night":false,"weight":.22,"sun":"ffa874","energy":1.0,"elevation":Vector2(14,19),"fill":"aeb0cf","ambient":.88,"horizon":"ffcaa6","haze":"efd6c8"},
	"dusk":{"night":true,"weight":.3,"sun":"ff9c7c","energy":.4,"elevation":Vector2(5,9),"fill":"8174ac","ambient":1.0,"horizon":"c08aa0","haze":"4a3f66"},
	"moon":{"night":true,"weight":.45,"sun":"9ab7e0","energy":.32,"elevation":Vector2(35,58),"fill":"869fbc","ambient":1.0,"horizon":"7f97b8","haze":"33405a"},
	"predawn":{"night":true,"weight":.25,"sun":"b3cfe8","energy":.3,"elevation":Vector2(6,11),"fill":"6f8fb4","ambient":1.05,"horizon":"c9a898","haze":"3d4f68"},
}
const DAY_MOMENTS=["dawn","morning","noon","golden","sunset"]
const NIGHT_MOMENTS=["dusk","moon","predawn"]
## Below this sun height, shadows fade towards LOW_SUN_SHADOW opacity so long stripes do not cover the field.
const SOFTER=1.3  # shadow edge blur multiplier, author request (30% softer)
const LOW_SUN=30.0
const LOW_SUN_SHADOW=.55
## Battle-only moment; hub and route map keep the style sun. Deterministic per run and room,
## seeded from the visual seed so gameplay RNG is never touched.
static func moment(context:Node,night:bool)->Dictionary:
	if context==null or not context.has_method("room_palette") or not "room_index" in context:return {}
	var choice=str(Settings.values.get("sun_night" if night else "sun_day","random"))
	var ids=NIGHT_MOMENTS if night else DAY_MOMENTS
	var rng=RandomNumberGenerator.new();rng.seed=hash([Game.visual_run_seed,int(context.room_index),"sun"])
	if choice not in ids:
		var total=0.0
		for id in ids:total+=float(MOMENTS[id].weight)
		var roll=rng.randf()*total;choice=ids[-1]
		for id in ids:
			roll-=float(MOMENTS[id].weight)
			if roll<=0:choice=id;break
	var entry:Dictionary=MOMENTS[choice].duplicate()
	var span:Vector2=entry.elevation
	var elevation=rng.randf_range(span.x,span.y)
	# Realistic height for every moment (T-006): dawn and sunset are low. Long low shadows stay readable
	# because apply() makes them lighter the lower the sun is (shadow_opacity), not shorter.
	# Avoid the sun straight behind the camera (yaw ~10°): it flattens every shadow.
	var yaw=wrapf(10.0+rng.randf_range(35,325),-180,180)
	entry.id=choice;entry.angle=Vector3(-elevation,yaw,0)
	return entry
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	Settings.changed.connect(apply)
	apply()
	call_deferred("refresh_materials")
func refresh_materials():
	Visuals.refresh_cozy_materials(get_parent())
func apply():
	var night=Settings.values.get("world_lighting","day")=="night"
	environment.background_color=day_background.darkened(.78) if night else day_background
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR if night else Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color=Color("869fbc") if night else Color.WHITE
	environment.ambient_light_energy=.38 if night else .48
	sun.light_color=Color("9ab7e0") if night else Color("fff0d7")
	sun.light_energy=.28 if night else .95
	var cozy=bool(Settings.values.get("shaders",true))
	var advanced=RenderingServer.get_current_rendering_method()=="forward_plus"
	var style:Dictionary=STYLES.get(Settings.values.get("shader_style","pastel"),STYLES.pastel)
	var option=func(key):return cozy and bool(Settings.values.get(key,true))
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC if cozy else Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure=float(style.exposure) if cozy else 1.0
	environment.tonemap_white=float(style.white) if cozy else 1.0
	environment.adjustment_enabled=cozy
	environment.adjustment_brightness=1.0
	environment.adjustment_contrast=float(style.contrast)
	environment.adjustment_saturation=float(style.saturation)
	environment.ssao_enabled=option.call("ambient_occlusion") and advanced
	environment.ssao_radius=.65
	environment.ssao_intensity=float(style.ssao)
	environment.ssao_detail=.6
	environment.ssao_light_affect=.15
	# T-063: «Кино» adds stronger contact shadows and bounced colour light (SSIL); other presets skip the cost.
	var cinema=str(Settings.values.get("graphics_preset","standard"))=="cinema" and advanced and cozy
	# SSIL is the expensive part: a short radius, and off at night where volumetric fog already costs a lot
	# (the hub lagged on «Кино», 0.7.2).
	environment.ssil_enabled=cinema and not night
	if cinema:
		environment.ssao_intensity*=1.35;environment.ssao_radius=.9
		environment.ssil_radius=2.0;environment.ssil_intensity=.8;environment.ssil_sharpness=.98;environment.ssil_normal_rejection=1.0
	# Glow picks only bright highlights (metal glints, gold, lamps) instead of washing the frame.
	environment.glow_enabled=option.call("glow")
	environment.glow_intensity=float(style.glow)
	environment.glow_bloom=.03
	environment.glow_hdr_threshold=.92
	environment.glow_blend_mode=Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.fog_enabled=false
	environment.volumetric_fog_enabled=cozy and advanced and night
	environment.volumetric_fog_density=.012
	environment.volumetric_fog_length=48.0
	environment.volumetric_fog_albedo=Color("a7b9d0")
	environment.volumetric_fog_ambient_inject=.15
	# Reflection sky: light pastel colours keep metal and gold from mirroring a dark ground.
	var sky_material=environment.sky.sky_material if environment.sky else null
	if sky_material is ProceduralSkyMaterial:
		var bright=cozy and bool(Settings.values.get("shiny_metal",true))
		sky_material.sky_top_color=Color(style.sky_top) if bright else Color("7394b0")
		sky_material.sky_horizon_color=Color(style.sky_horizon) if bright else Color("d9dfdd")
		sky_material.ground_horizon_color=Color(style.ground) if bright else Color("a1a394")
		sky_material.ground_bottom_color=Color(style.ground).darkened(.25) if bright else Color("44483d")
		sky_material.energy_multiplier=(.45 if night else 1.0)
		# Metal needs contrast to read as metal: a deeper zenith and a bright warm horizon give its edges a
		# light-to-dark sweep instead of one flat grey (only the reflection sky; the background colour stays).
		if bright and not night:
			sky_material.sky_top_color=Color(style.sky_top).darkened(.28)
			sky_material.sky_horizon_color=Color(style.sky_horizon).lightened(.12)
			sky_material.sky_curve=.06
	var soft=option.call("soft_shadows")
	# Softness is a filter blur, not an angular sun size: PCSS (angular distance) samples the penumbra
	# with noise that reads as grain on small geometry like brick courses.
	sun.light_angular_distance=0.0
	# The orthographic field falls into the far (coarse) shadow split, and the high-quality soft filter with a
	# blur of 2+ smeared the sun shadows to nothing: walls cast no shadow and daylight read flat. Low filter
	# quality (project setting) and a small blur keep a soft but visible edge.
	# 0.8.0 b4xx (author): shadows 30% softer — SOFTER scales every shadow blur below.
	sun.shadow_blur=clampf(1.0+float(style.softness)*.08,1.0,1.6)*SOFTER if soft else 1.0
	# Moonlight shadows read as blurry as the day ones.
	if soft and night:sun.shadow_blur=clampf(sun.shadow_blur*1.8,2.0,5.0*SOFTER)
	sun.shadow_opacity=float(style.shadow) if cozy else 1.0
	sun.light_specular=float(style.specular) if cozy else .5
	var time:Dictionary=moment(get_parent(),night) if cozy else {}
	if cozy and not time.is_empty():
		style=style.duplicate();style.sun_angle=time.angle;style.sun=time.sun;style.fill=time.fill
		style.sun_energy=float(time.energy) if night else float(style.sun_energy)*float(time.energy)
		style.ambient=float(style.ambient)*float(time.ambient)
		if sky_material is ProceduralSkyMaterial and bool(Settings.values.get("shiny_metal",true)):
			sky_material.sky_horizon_color=Color(time.horizon);sky_material.ground_horizon_color=Color(style.ground).lerp(Color(time.horizon),.35)
		environment.background_color=(day_background.darkened(.78) if night else day_background).lerp(Color(time.sun),.1 if not night else .06)
	# Weather dims the sun, softens shadows and tints the fill; visual only.
	var weather:Dictionary=preload("res://scripts/systems/weather.gd").look(get_parent()) if cozy else {}
	if not weather.is_empty():
		style=style.duplicate();style.sun_energy=float(style.sun_energy)*float(weather.sun)
		style.ambient=float(style.ambient)*float(weather.ambient);style.fill=Color(style.fill).lerp(Color(weather.fill),.6).to_html()
		sun.shadow_opacity=float(style.shadow)*float(weather.shadow)
		environment.adjustment_saturation=float(style.saturation)*float(weather.saturation)
	if cozy:
		sun.rotation_degrees=style.sun_angle
		var height=-float(Vector3(style.sun_angle).x)
		if not night and height<LOW_SUN:sun.shadow_opacity*=lerpf(LOW_SUN_SHADOW,1.0,clampf((height-12.0)/(LOW_SUN-12.0),0.0,1.0))
		sun.light_color=Color(style.sun) if not night or not time.is_empty() else Color("9ab7e0")
		sun.light_energy=float(style.sun_energy) if not night or not time.is_empty() else .3
		# Fill light is a style colour (lilac-blue shadows); the bright sky is used only for reflections.
		if not night or not time.is_empty():
			environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
			environment.ambient_light_color=Color(style.fill)
		environment.ambient_light_energy=(.34*float(time.get("ambient",1.0))) if night else float(style.ambient)
	else:sun.rotation_degrees=Vector3(-55,-32,0)
	depth_light(cozy and bool(Settings.values.get("depth_light",true)),night)
	cinematic_light(cozy and bool(Settings.values.get("cinematic_light",true)),night,Vector3(style.sun_angle) if cozy else Vector3(-55,-32,0))
	refresh_materials()
	update_lamps()
## «Киношный свет» (T-066): a second, shadowless back light opposite the sun in a complementary colour
## (warm key / cool rim, or the reverse at night). It outlines every model so it reads in volume. The recipe
## is picked per room from the visual seed, so each field gets its own mood; hub and route map use room 0.
const CINE_DAY=[["8fb8ff",.5],["c7a0ff",.45],["a8e0ff",.4],["ffb3c8",.38]]
const CINE_NIGHT=[["ff9f6b",.32],["7fe0d0",.28],["c7a0ff",.3]]
func cinematic_light(on:bool,night:bool,sun_angle:Vector3):
	var rim:DirectionalLight3D=get_node_or_null("CineRim")
	if rim==null:
		rim=DirectionalLight3D.new();rim.name="CineRim";rim.shadow_enabled=false;rim.light_specular=.7;add_child(rim)
	rim.visible=on
	if not on:return
	var room=int(get_parent().get("room_index")) if get_parent().get("room_index")!=null else 0
	var rng=RandomNumberGenerator.new();rng.seed=hash([Game.visual_run_seed,room,"cine"])
	var recipe=(CINE_NIGHT if night else CINE_DAY)[rng.randi_range(0,(CINE_NIGHT if night else CINE_DAY).size()-1)]
	rim.light_color=Color(recipe[0]);rim.light_energy=float(recipe[1])
	rim.rotation_degrees=Vector3(-rng.randf_range(16,28),sun_angle.y+180.0+rng.randf_range(-25,25),0)
## Night sky glow (T-067): three huge, very faint moonbeam shafts slanting down through the scene and drifting
## slowly, plus a soft cool sheen — cheap unshaded cones, night and «Киношный свет» only.
## «Глубина света» (T-062), cheap: grid AO on the floor (systems/floor_ao.gd), a slightly warmer sun and
## a hint of cool fill (warm light / cool shadow), a touch more contrast. AgX was tried and greyed the sand
## palette, so the style's filmic tonemap stays.
func depth_light(on:bool,night:=false):
	if not on:return
	if night:
		# Night recipe, tuned like the day one: silver-blue moonlight that shapes the forms, a deep blue fill
		# so shadows stay coloured (never black or brown), slightly muted colour, warm lamps glowing against it.
		environment.adjustment_contrast*=1.08;environment.adjustment_saturation*=.92
		sun.light_color=sun.light_color.lerp(Color("b4c8ff"),.5);sun.light_energy*=1.25
		environment.ambient_light_color=environment.ambient_light_color.lerp(Color("5f74b0"),.35)
		sun.shadow_opacity=minf(1.0,sun.shadow_opacity)*.8
		environment.glow_intensity*=1.3
		# Soft dark night (0.8): with real sun shadows back, the moon and fill lit sand like daytime. Moon and
		# fill go down so searchlights and lamps make the bright patches; light floors darken a bit more.
		var k=0.0
		if get_parent().has_method("room_palette"):k=clampf((Color(get_parent().room_palette().floor).get_luminance()-.45)/.25,0.0,1.0)
		sun.light_energy*=.42-.1*k;environment.ambient_light_energy*=.48-.1*k
		environment.tonemap_exposure*=.94-.12*k
		return
	environment.adjustment_contrast*=1.08;environment.adjustment_saturation*=1.05
	sun.light_color=sun.light_color.lerp(Color("ffd6a8"),.15);sun.light_energy*=1.06
	# Light floors (sand, pale concrete) washed out in daylight and read flat: the lighter the floor, the lower
	# the exposure and fill and the firmer the contrast and sun shadows. Mid and dark biomes stay as they are.
	if get_parent().has_method("room_palette"):
		var lum=Color(get_parent().room_palette().floor).get_luminance()
		var k=clampf((lum-.56)/.14,0.0,1.0)
		environment.tonemap_exposure*=1.0-.13*k;environment.ambient_light_energy*=1.0-.18*k
		environment.adjustment_contrast*=1.0+.07*k;sun.shadow_opacity=minf(1.0,sun.shadow_opacity*(1.0+.12*k))
		# Golden hour on sand turned the whole frame yellow: the sun gets a little more neutral and softer there.
		sun.light_color=sun.light_color.lerp(Color("fff1df"),.35*k);sun.light_energy*=1.0-.1*k
		environment.adjustment_saturation*=1.0-.14*k
	# Volume (0.7.2): a cooler, weaker fill against the warm sun reads the sides and cast shadows of walls;
	# the shadows stay coloured, never near-black.
	environment.ambient_light_color=environment.ambient_light_color.lerp(Color("9db0d8"),.22)
	environment.ambient_light_energy*=.86;sun.light_energy*=1.05
	sun.shadow_opacity*=.92
func _process(delta):
	elapsed+=delta
	if elapsed<.25:return
	elapsed=0.0;update_lamps()
func update_lamps():
	if not is_inside_tree():return
	var night=Settings.values.get("world_lighting","day")=="night"
	var camera=get_viewport().get_camera_3d()
	var lamps=get_tree().get_nodes_in_group("night_lamps").filter(func(n):return get_parent().is_ancestor_of(n))
	if camera:
		lamps.sort_custom(func(a,b):
			var ap=int(a.get_meta("priority",0));var bp=int(b.get_meta("priority",0))
			if ap!=bp:return ap>bp
			return a.global_position.distance_squared_to(camera.global_position)<b.global_position.distance_squared_to(camera.global_position))
	var budget=int(Settings.values.light_budget)
	var cozy=bool(Settings.values.get("shaders",true))
	var allocated={};var used=0
	for i in range(lamps.size()):
		var light=lamps[i];light.light_energy=float(light.get_meta("night_energy",1.6)) if night else float(light.get_meta("day_energy",.12))
		var group=light.get_parent().get_instance_id() if light.get_meta("occluded_beam",false) else light.get_instance_id()
		if not allocated.has(group):
			var cost=2 if light.get_meta("occluded_beam",false) else 1
			allocated[group]=used+cost<=budget and light.light_energy>0 and light.get_parent().is_visible_in_tree()
			if allocated[group]:used+=cost
		light.visible=allocated[group]
		# The full-size HQ slightly overlaps its cover tile. A source inside intact
		# cover must not illuminate the far side; each real lamp is checked separately.
		var board=get_parent()
		if light.get_meta("occluded_beam",false) and board.has_method("wall_contacts"):
			var forward=-light.global_basis.z.normalized()
			if not board.wall_contacts(light.global_position,forward,.04).is_empty():light.visible=false
		light.shadow_enabled=light.visible and not light.get_meta("no_shadow",false) and (light.get_meta("occluded_beam",false) or (cozy and i<3))
		light.light_volumetric_fog_energy=1.5 if cozy else 0.0
		# Lamp shadows at night were crisp next to the soft day ones; a wider filter blurs them the same way.
		light.shadow_blur=(3.2 if night else 1.5)*SOFTER if cozy and Settings.values.get("soft_shadows",true) else 1.0
		if light is SpotLight3D:
			if not light.has_node("SoftCone"):add_cone(light)
			# A faint beam is always visible; night and fog make it denser (T-058).
			var foggy=preload("res://scripts/systems/weather.gd").pick(get_parent()) in ["fog","rain","sandstorm"]
			# Long-range mast lights get no visible cone: from above it would veil the whole field.
			var cone=light.get_node("SoftCone");cone.visible=light.visible and cozy and light.spot_range<=5.0
			cone.material_override.set_shader_parameter("density",(.02 if night else .006)*(1.6 if foggy else 1.0))
	var pickups=get_tree().get_nodes_in_group("pickup_lights").filter(func(n):return get_parent().is_ancestor_of(n))
	if camera:pickups.sort_custom(func(a,b):return a.global_position.distance_squared_to(camera.global_position)<b.global_position.distance_squared_to(camera.global_position))
	for i in range(pickups.size()):
		pickups[i].visible=cozy and i<4
		pickups[i].light_energy=.6 if night else .22
static func lamp(parent:Node3D,position:Vector3):
	var light=OmniLight3D.new();light.name="NightLamp";parent.add_child(light);light.position=position
	light.light_color=Color("ffcc83");light.light_energy=1.6;light.omni_range=7;light.omni_attenuation=1.3;light.shadow_enabled=false
	light.add_to_group("night_lamps");light.visible=Settings.values.get("world_lighting","day")=="night"

static func beam(parent:Node3D,pos:Vector3,always=false,priority=1)->SpotLight3D:
	var light=SpotLight3D.new();light.name="Headlight";parent.add_child(light);light.position=pos;light.rotation.x=deg_to_rad(-16)
	# No projector texture: in Godot 4.7 a runtime cookie switched the light off entirely (hub went dark, 0.7.2).
	light.light_color=Color("ffe1ad");light.light_energy=2.1;light.spot_range=3.8;light.spot_angle=34;light.spot_attenuation=1.0;light.shadow_enabled=false
	light.set_meta("day_energy",.65 if always else 0.0);light.set_meta("night_energy",2.1);light.set_meta("priority",priority)
	light.add_to_group("night_lamps");light.visible=always or Settings.values.world_lighting=="night";return light

static func headlights(parent:Node3D,vehicle=false,always=false):
	if parent.has_node("HeadlightRig"):return
	var rig=Node3D.new();rig.name="HeadlightRig";parent.add_child(rig)
	if vehicle:
		var lamps=parent.find_children("Amber headlamp*","MeshInstance3D",true,false)
		var mounts=parent.find_children("HeadlightMount*","Node3D",true,false)
		if not mounts.is_empty():
			# v6 vehicles: beams sit on the modelled lamps and follow the hull.
			for mount in mounts:
				var light=beam(mount,Vector3.ZERO,always,3)
				light.set_meta("occluded_beam",true);light.shadow_enabled=true
		elif not lamps.is_empty():
			# Authored HQ points +Z; attach to the actual lamp surfaces, including map scale.
			for fixture in lamps:
				var pos=parent.to_local(fixture.global_position)+Vector3(0,0,.025)
				var light=beam(rig,pos,always,5);light.rotation.y=PI
				light.set_meta("occluded_beam",true);light.shadow_enabled=true
		else:
			var body=parent.find_child(str(parent.get("kind"))+"_body",true,false)
			var bounds=AABB(Vector3(-.3,.15,-.45),Vector3(.6,.4,.9))
			if body is MeshInstance3D:
				var transform=body.transform;var ancestor=body.get_parent()
				while ancestor!=parent and ancestor is Node3D:
					transform=ancestor.transform*transform;ancestor=ancestor.get_parent()
				bounds=transform*body.get_aabb()
			for side in [-1,1]:
				var pos=Vector3(bounds.get_center().x+side*bounds.size.x*.34,bounds.position.y+bounds.size.y*.48,bounds.position.z-.025)
				Visuals.box(rig,pos,Vector3(.095,.065,.035),Color("ffe6a8")).material_override=Visuals.material(Color("ffe6a8"),true)
				var light=beam(rig,pos+Vector3(0,0,-.025),always,3)
				light.set_meta("occluded_beam",true);light.shadow_enabled=true
	else:
		# v6 infantry carry a chest lamp: the beam rides on it and follows the animation.
		var lamp=parent.find_child("Flashlight",true,false)
		if lamp is Node3D:
			var steady=preload("res://scripts/beam_steady.gd").new();steady.name="SteadyBeam";steady.lamp=lamp;rig.add_child(steady)
			beam(steady,Vector3.ZERO,false,4).set_meta("no_shadow",true)
		else:beam(rig,Vector3(.12,.65,-.24),false,4).set_meta("no_shadow",true)
		# A chest lamp casts no shadows: its own soldier's weapon flickered across the beam while running.
		preload("res://scripts/systems/floor_ao.gd").contact_shadow(parent)

## Compact fixtures (tools/build_lights_v1.py): an armoured searchlight on a turntable for block tops, a caged
## bulkhead lamp on a bracket for walls (`wall` true). The spotlight sits in the modelled lens.
static func floodlight(parent:Node3D,pos:Vector3,yaw:float,wall:=false):
	var rig=Node3D.new();rig.name="Floodlight";parent.add_child(rig);rig.position=pos;rig.rotation.y=yaw
	Visuals.model("light_wall" if wall else "light_block",rig)
	var light=beam(rig,Vector3(0,0,-.26) if wall else Vector3(0,.22,-.16),true,1);light.rotation.x=deg_to_rad(-55.0 if wall else -35.0);light.spot_range=4.5;light.spot_angle=42;light.set_meta("day_energy",.22)

static func field(arena):
	var rng=RandomNumberGenerator.new();rng.seed=arena.run_seed+arena.room_index*3907+711
	var candidates=arena.walls.keys().filter(func(c):return arena.walls[c].hp<0 and not arena.walls[c].has("half_side") and c.y>1 and c.y<arena.grid_size-2)
	# Fixtures sit on existing solid cover; no new collision or pathfinding cells.
	# Fewer, deliberate pools of light (T-065): overlapping lamps read as noise from above.
	var count=mini(candidates.size(),rng.randi_range(1,3))
	for i in range(count):
		var index=rng.randi_range(0,candidates.size()-1);var cell=candidates.pop_at(index)
		preload("res://scripts/base_surroundings.gd").lamp(arena.walls[cell].node,Vector3(0,1.0,0))
	for i in range(mini(rng.randi_range(0,1),candidates.size())):
		var index=rng.randi_range(0,candidates.size()-1);var cell=candidates.pop_at(index)
		floodlight(arena.walls[cell].node,Vector3(0,1.02,0),rng.randf()*TAU)
	# A few fixtures stutter now and then (T-016): about a quarter of the field lamps, never all at once.
	var flick=RandomNumberGenerator.new();flick.seed=hash([Game.visual_run_seed,arena.room_index,"flicker"])
	for light in arena.find_children("*","Light3D",true,false):
		var fixture=str(light.get_path()).contains("MilitaryLightStand") or str(light.get_path()).contains("Floodlight")
		if fixture and flick.randf()<.25:preload("res://scripts/light_flicker.gd").attach(light,flick.randi())
	# Burning drums just outside the field edge: warm story light on the flanks, never on playable cells.
	for i in range(rng.randi_range(1,2)):
		var side=-1 if (i+rng.randi_range(0,1))%2==0 else 1
		var row=rng.randi_range(2,arena.grid_size-3)
		var drum=preload("res://scripts/fire_barrel.gd").new();drum.intensity=.5;drum.tint=Color(arena.room_palette().wall).darkened(.62).lerp(Color("3a2c24"),.3);arena.add_child(drum)
		drum.position=arena.world_pos(Vector2i(-1 if side<0 else arena.grid_size,row))+Vector3(side*.35,0,0)

## One reflection probe over a whole field or the hub (T-065/T-005): captured once when the room is built,
## so metal and water reflect the real scene instead of an empty sky. Costs only at room load.
static func reflection_probe(parent:Node3D,extent:Vector3,center:=Vector3.ZERO):
	var old=parent.get_node_or_null("SceneReflection")
	if old:old.name="SceneReflectionOld";old.queue_free()
	if not bool(Settings.values.get("shiny_metal",true)) or not bool(Settings.values.get("shaders",true)):return
	var probe=ReflectionProbe.new();probe.name="SceneReflection";parent.add_child(probe)
	probe.position=center+Vector3(0,1.6,0);probe.size=extent;probe.box_projection=true;probe.update_mode=ReflectionProbe.UPDATE_ONCE
	probe.intensity=.8;probe.max_distance=extent.length();probe.enable_shadows=false
static func add_cone(light:SpotLight3D):
	var cone=MeshInstance3D.new();cone.name="SoftCone";cone.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh=CylinderMesh.new();mesh.top_radius=.018;mesh.bottom_radius=tan(deg_to_rad(light.spot_angle))*light.spot_range*.68;mesh.height=light.spot_range*.8;mesh.radial_segments=16;mesh.rings=1;mesh.cap_top=false;mesh.cap_bottom=false
	cone.mesh=mesh;cone.rotation.x=PI*.5;cone.position.z=-mesh.height*.5
	var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/world/light_cone.gdshader");cone.material_override=mat;light.add_child(cone)
