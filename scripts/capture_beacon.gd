extends Node3D
## Trophy signal on a captured enemy vehicle: pulsing ground waves, a soft light column and an edge pointer
## on the HUD while the hull is off-screen. Visual only; shown while the soldier is on foot and can board.
const COLOR=Color("83ea77")
var wreck
var waves:Array=[]
var column:MeshInstance3D
var pointer:Control
var clock=0.0

func _ready():
	name="CaptureBeacon"
	for i in range(2):
		var wave=Visuals.ring(self,COLOR,.7);wave.position.y=.05;waves.append(wave)
	column=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=.16;mesh.bottom_radius=.34;mesh.height=3.2;mesh.radial_segments=12;mesh.cap_top=false;mesh.cap_bottom=false
	column.mesh=mesh;column.position.y=1.6;column.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.albedo_color=Color(COLOR,.0);mat.no_depth_test=false
	column.material_override=mat;add_child(column)
	var hud=wreck.arena.hud if wreck and wreck.arena else null
	if hud:
		pointer=Label.new();pointer.name="CapturePointer";Texts.set_text(pointer,"▲");pointer.add_theme_font_size_override("font_size",30)
		pointer.add_theme_color_override("font_color",COLOR);pointer.add_theme_color_override("font_outline_color",Color("304031"));pointer.add_theme_constant_override("outline_size",6)
		pointer.size=Vector2(30,34);pointer.pivot_offset=pointer.size*.5;pointer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;pointer.mouse_filter=Control.MOUSE_FILTER_IGNORE;pointer.hide()
		hud.add_child(pointer)
	tree_exiting.connect(func():if is_instance_valid(pointer):pointer.queue_free())

func active()->bool:
	if not is_instance_valid(wreck) or wreck.spent or not wreck.boardable or wreck.unstable:return false
	var player=wreck.arena.room.player
	return is_instance_valid(player) and player.kind=="soldier" and wreck.arena.phase=="combat"

func _process(delta):
	clock+=delta
	var on=active()
	visible=on
	if is_instance_valid(pointer):pointer.visible=false
	if not on:return
	for i in range(waves.size()):
		var t=fposmod(clock*.7+i*.5,1.0)
		waves[i].scale=Vector3.ONE*lerpf(.8,2.1,t)
		waves[i].set_instance_shader_parameter("tint",Color(COLOR,(1.0-t)*.9))
	column.material_override.albedo_color=Color(COLOR,.1+.08*sin(clock*3.0))
	if is_instance_valid(wreck.label):wreck.label.modulate=Color(COLOR,.55+.45*pow(.5+.5*sin(clock*6.0),2))
	point_from_edge()

func point_from_edge():
	var camera=get_viewport().get_camera_3d()
	if camera==null or not is_instance_valid(pointer):return
	var rect=get_viewport().get_visible_rect();var margin=36.0
	var screen=camera.unproject_position(global_position+Vector3(0,.8,0))
	var inside=not camera.is_position_behind(global_position) and rect.grow(-margin*.5).has_point(screen)
	if inside:return
	var center=rect.size*.5;var direction=(screen-center)
	if camera.is_position_behind(global_position):direction=-direction
	if direction.length()<1:return
	direction=direction.normalized()
	var half=center-Vector2(margin,margin)
	var scale_to_edge=minf(half.x/maxf(absf(direction.x),.001),half.y/maxf(absf(direction.y),.001))
	pointer.position=center+direction*scale_to_edge-pointer.size*.5
	pointer.rotation=direction.angle()+PI/2
	pointer.modulate.a=.6+.4*sin(clock*6.0)
	pointer.visible=true
