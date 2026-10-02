extends Node3D
## Light status read on an actor's model. One overlay at a time, by priority:
## hit flash (red, .09 s) > invulnerable (soft white shimmer) > frozen (ice blue) > burning (orange flicker).
## On top, one small minimal marker per status: a block of ice around a frozen enemy, three flame tongues on a
## burning one, stars orbiting a stunned head, floating «Z z z» over a sleeping (gassed) one. The same status
## shows as a small icon left of the HP bar. Visual only: no game RNG, no timers of the fight.
const FLASH_TIME=.09
const ICONS={"frozen":"res://assets/icons/v09/freeze.png","sleep":"res://assets/icons/v09/gas.png","stun":"res://assets/icons/v1/star.png","burning":"res://assets/icons/v09/fire.png"}
static var overlays:={}
static var shared:={}
var actor
var flash_left=0.0
var current=""
var marker=""
var meshes:Array=[]
var stars:Node3D
var ice:MeshInstance3D
var flames:Node3D
var sleep:Node3D
var icon:Sprite3D
var clock=0.0

static func of(target)->Node3D:
	if not is_instance_valid(target):return null
	var fx=target.get_node_or_null("StatusFx")
	if fx:return fx
	fx=load("res://scripts/status_fx.gd").new();fx.name="StatusFx";fx.actor=target;target.add_child(fx)
	return fx

static func overlay(kind:String)->StandardMaterial3D:
	if overlays.has(kind):return overlays[kind]
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color={"flash":Color(1,.18,.12,.5),"invulnerable":Color(1,1,1,.25),"frozen":Color(.62,.88,1,.3),"burning":Color(1,.5,.12,.22)}[kind]
	mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD if kind in ["invulnerable","burning"] else BaseMaterial3D.BLEND_MODE_MIX
	overlays[kind]=mat;return mat

## Materials shared by every marker of one kind.
static func paint(kind:String)->Material:
	if shared.has(kind):return shared[kind]
	var mat=StandardMaterial3D.new()
	match kind:
		"ice":
			mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color=Color(.72,.92,1,.34);mat.roughness=.08;mat.metallic_specular=1.0
			mat.rim_enabled=true;mat.rim=.6;mat.emission_enabled=true;mat.emission=Color(.35,.6,.75);mat.emission_energy_multiplier=.25
		"flame","flame_core":
			mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
			mat.albedo_color=Color(1,.45,.12,.85) if kind=="flame" else Color(1,.85,.35,.9)
		"star":
			mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("ffd75a")
	shared[kind]=mat;return mat

func hit():flash_left=FLASH_TIME

func enemy()->bool:return not actor.player_owned and not actor.allied
func state()->String:
	if flash_left>0:return "flash"
	if actor.player_owned and (actor.invulnerable>.7 or actor.arena.star_time>0):return "invulnerable"
	if enemy() and actor.arena.freeze_time>0:return "frozen"
	if actor.burn_time>0:return "burning"
	return ""
## The one status marker shown (and its HP-bar icon): frozen > sleep > stun > burning.
func marker_state()->String:
	if not enemy():return ""
	if actor.arena.freeze_time>0:return "frozen"
	if actor.get("sleep_time")!=null and actor.sleep_time>0:return "sleep"
	if actor.stun_time>0:return "stun"
	if actor.burn_time>0:return "burning"
	return ""

func _process(delta):
	if not is_instance_valid(actor) or actor.dead:queue_free();return
	clock+=delta;flash_left=maxf(0,flash_left-delta)
	var next=state()
	if next!=current:apply(next)
	# Shared materials pulse by time, so every actor in the same state breathes together.
	if current=="invulnerable":overlays.invulnerable.albedo_color.a=.12+.16*absf(sin(clock*9.0))
	elif current=="burning":overlays.burning.albedo_color.a=.14+.1*absf(sin(clock*17.0+1.3))
	var shown=marker_state()
	if shown!=marker:show_marker(shown)
	match marker:
		"stun":stars.rotation.y+=delta*6.0
		"burning":
			for i in flames.get_child_count():
				var tongue:Node3D=flames.get_child(i);var beat=clock*(11.0+i*2.3)+i*1.7
				tongue.scale=Vector3(1.0+.15*sin(beat*1.3),.75+.35*absf(sin(beat)),1.0+.15*sin(beat*1.3))
		"sleep":
			for i in sleep.get_child_count():
				var z:Label3D=sleep.get_child(i);var t=fmod(clock*.55+i/3.0,1.0)
				z.position=Vector3(.1+t*.2,t*.38,0);z.modulate.a=sin(t*PI);z.pixel_size=.0022+t*.0016

func apply(next:String):
	current=next
	if meshes.is_empty() or not is_instance_valid(meshes[0]):
		meshes=actor.model.find_children("*","GeometryInstance3D",true,false).filter(func(m):return not lighting_part(m)) if is_instance_valid(actor.model) else []
	for mesh in meshes:
		if is_instance_valid(mesh):mesh.material_overlay=overlay(next) if next!="" else null

## Light cones, lamp lenses, the headlight rig and the contact shadow keep their own look: a hit tints only the
## body (an overlay on the floor shadow flashed the whole cell, T-091).
func lighting_part(mesh:Node)->bool:
	var node=mesh
	while node!=null and node!=actor:
		if node.name in ["SoftCone","HeadlightRig","Flashlight","Floodlight","ContactShadow","SteadyBeam"] or node is Light3D:return true
		node=node.get_parent()
	return false
func show_marker(next:String):
	marker=next
	for node in [stars,ice,flames,sleep]:
		if is_instance_valid(node):node.visible=false
	match next:
		"stun":
			if not is_instance_valid(stars):build_stars()
			stars.visible=true
		"frozen":
			if not is_instance_valid(ice):build_ice()
			ice.visible=true
		"burning":
			if not is_instance_valid(flames):build_flames()
			flames.visible=true
		"sleep":
			if not is_instance_valid(sleep):build_sleep()
			sleep.visible=true
	update_icon()

func top()->float:
	return actor.health_label.position.y if is_instance_valid(actor.health_label) else 1.2*actor.footprint

func build_stars():
	stars=Node3D.new();stars.name="StunStars";add_child(stars);stars.position.y=top()+.12
	for i in range(3):
		var star=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3.ONE*.09;star.mesh=box
		star.material_override=paint("star");star.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a=i*TAU/3.0;star.position=Vector3(cos(a),0,sin(a))*.28;star.rotation=Vector3(.6,a,.6);stars.add_child(star)

## A single bevel-free block of ice around the model: footprint-wide, up to the HP bar.
func build_ice():
	ice=MeshInstance3D.new();ice.name="IceBlock";var box=BoxMesh.new()
	var width=.62 if actor.footprint<=1 and UnitKinds.is_infantry(actor.kind) else .92*actor.footprint
	var height=top()*.9
	box.size=Vector3(width,height,width);ice.mesh=box;ice.position.y=height*.5;ice.rotation.y=.18
	ice.material_override=paint("ice");ice.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(ice)

## Three small flame tongues: an orange cone with a yellow core, flickering at their own pace.
func build_flames():
	flames=Node3D.new();flames.name="Flames";add_child(flames)
	var spread=.18*maxf(1.0,actor.footprint*.8)
	for i in range(3):
		var tongue=Node3D.new();flames.add_child(tongue)
		var a=i*TAU/3.0+.4;tongue.position=Vector3(cos(a)*spread,top()*.62,sin(a)*spread)
		for core in [false,true]:
			var part=MeshInstance3D.new();var cone=CylinderMesh.new();cone.top_radius=0.0
			cone.bottom_radius=.08 if core else .13;cone.height=.2 if core else .34;cone.radial_segments=6;cone.rings=1
			part.mesh=cone;part.position.y=cone.height*.5;part.material_override=paint("flame_core" if core else "flame")
			part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;tongue.add_child(part)

## Sleep: «Z z z» drifting up and fading, instead of stun stars.
func build_sleep():
	sleep=Node3D.new();sleep.name="SleepZ";add_child(sleep);sleep.position.y=top()+.16
	for i in range(3):
		var z=Label3D.new();z.text="Z" if i==0 else "z";z.billboard=BaseMaterial3D.BILLBOARD_ENABLED;z.no_depth_test=true
		z.font_size=64;z.outline_size=14;z.modulate=Color("d8ccff");z.outline_modulate=Color("2c2a44");z.pixel_size=.005
		sleep.add_child(z)

## Small status icon left of the HP bar (it follows ranked, wider bars).
func update_icon():
	var bar=actor.health_label if is_instance_valid(actor.health_label) else null
	if bar==null:return
	if not is_instance_valid(icon):
		icon=Sprite3D.new();icon.name="StatusIcon";icon.billboard=BaseMaterial3D.BILLBOARD_ENABLED;icon.no_depth_test=true;icon.shaded=false
		icon.render_priority=1;bar.add_child(icon)
	icon.visible=marker!=""
	if marker=="":return
	icon.texture=load(ICONS[marker])
	var bar_width=(bar.texture.get_width() if bar.texture else 96)*bar.pixel_size
	var side=.3*(bar.pixel_size/.009)
	icon.pixel_size=side/maxf(1.0,icon.texture.get_height())
	icon.position=Vector3(-bar_width*.5-side*.6,0,0)
