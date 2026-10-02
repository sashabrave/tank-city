extends CanvasLayer
## Darkness over the maze room: everything is black except a soft circle around the soldier.
## Drawn under the HUD (layer 0); lift() fades it out when the timer runs out or the flag is reached.
const SHADER="""shader_type canvas_item;
uniform vec2 center=vec2(0.0);
uniform vec2 screen=vec2(1600.0,900.0);
uniform float radius=120.0;
uniform float feather=70.0;
uniform float strength=0.96;
void fragment(){
	float d=distance(SCREEN_UV*screen,center);
	COLOR=vec4(0.015,0.02,0.025,smoothstep(radius,radius+feather,d)*strength);
}"""
## Light radius around the soldier, in field cells.
const LIGHT_CELLS=2.3
var arena
var veil:ColorRect
var paint:ShaderMaterial
var lifting=false
func _ready():
	layer=0;name="MazeDarkness"
	veil=ColorRect.new();add_child(veil);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader=Shader.new();shader.code=SHADER;paint=ShaderMaterial.new();paint.shader=shader;veil.material=paint
	follow()
func _process(_delta):follow()
func follow():
	var camera=get_viewport().get_camera_3d()
	var player=arena.room.player if is_instance_valid(arena) else null
	if not is_instance_valid(camera) or not is_instance_valid(player):return
	var screen=get_viewport().get_visible_rect().size
	var here=camera.unproject_position(player.position+Vector3.UP*.4)
	var edge=camera.unproject_position(player.position+Vector3.UP*.4+Vector3(LIGHT_CELLS,0,0))
	paint.set_shader_parameter("screen",screen);paint.set_shader_parameter("center",here)
	var radius=maxf(40.0,here.distance_to(edge))
	paint.set_shader_parameter("radius",radius);paint.set_shader_parameter("feather",radius*.55)
func lift():
	if lifting:return
	lifting=true
	var tween=create_tween();tween.tween_method(func(v):paint.set_shader_parameter("strength",v),.96,0.0,.8)
	tween.tween_callback(queue_free)
