extends Node3D
## Light status read on an actor's model. One overlay at a time, by priority:
## hit flash (red, .09 s) > invulnerable (soft white shimmer) > frozen (ice blue) > burning (orange flicker).
## A stunned actor gets three small stars orbiting above the head. Visual only.
const FLASH_TIME=.09
static var overlays:={}
var actor
var flash_left=0.0
var current=""
var meshes:Array=[]
var stars:Node3D
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
	mat.albedo_color={"flash":Color(1,.18,.12,.5),"invulnerable":Color(1,1,1,.25),"frozen":Color(.55,.85,1,.38),"burning":Color(1,.5,.12,.3)}[kind]
	mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD if kind in ["invulnerable","burning"] else BaseMaterial3D.BLEND_MODE_MIX
	overlays[kind]=mat;return mat

func hit():flash_left=FLASH_TIME

func state()->String:
	if flash_left>0:return "flash"
	if actor.player_owned and (actor.invulnerable>.7 or actor.arena.star_time>0):return "invulnerable"
	if not actor.player_owned and not actor.allied and actor.arena.freeze_time>0:return "frozen"
	if actor.burn_time>0:return "burning"
	return ""

func _process(delta):
	if not is_instance_valid(actor) or actor.dead:queue_free();return
	clock+=delta;flash_left=maxf(0,flash_left-delta)
	var next=state()
	if next!=current:apply(next)
	# Shared materials pulse by time, so every actor in the same state breathes together.
	if current=="invulnerable":overlays.invulnerable.albedo_color.a=.12+.16*absf(sin(clock*9.0))
	elif current=="burning":overlays.burning.albedo_color.a=.18+.14*absf(sin(clock*17.0+1.3))
	var stunned=actor.stun_time>0 and not actor.player_owned
	if stunned and not is_instance_valid(stars):build_stars()
	if is_instance_valid(stars):
		stars.visible=stunned
		stars.rotation.y+=delta*6.0

func apply(next:String):
	current=next
	if meshes.is_empty() or not is_instance_valid(meshes[0]):
		meshes=actor.model.find_children("*","GeometryInstance3D",true,false) if is_instance_valid(actor.model) else []
	for mesh in meshes:
		if is_instance_valid(mesh):mesh.material_overlay=overlay(next) if next!="" else null

func build_stars():
	stars=Node3D.new();stars.name="StunStars";add_child(stars);stars.position.y=1.25*actor.footprint
	for i in range(3):
		var star=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3.ONE*.09;star.mesh=box
		star.material_override=Visuals.material(Color("ffd75a"),true);star.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a=i*TAU/3.0;star.position=Vector3(cos(a),0,sin(a))*.28;star.rotation=Vector3(.6,a,.6);stars.add_child(star)
