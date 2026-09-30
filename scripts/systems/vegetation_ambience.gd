extends Node3D
## Sparse forest accents, batched across the room. Independent appearance RNG only.
var clock=0.0
var leaves:MultiMeshInstance3D
var lights:MultiMeshInstance3D
var materials:Array=[]
const SHADER_CODE="""
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float clock = 0.0;
uniform bool fireflies = false;
uniform vec4 tint : source_color;
varying float glow;
void vertex() {
 float seed = INSTANCE_CUSTOM.x;
 float rate = INSTANCE_CUSTOM.y;
 float phase = seed * 31.7;
 if (fireflies) {
  float time = clock * (0.34 + rate * 0.31);
  glow = pow(max(0.0, sin(time * 1.63 + phase)), 2.0);
  VERTEX *= 0.25 + glow * 0.75;
  VERTEX.x += sin(time + phase) * 0.19;
  VERTEX.z += cos(time * 0.73 + phase * 1.7) * 0.16;
  VERTEX.y += 0.55 + sin(time * 0.61 + phase) * 0.23;
 } else {
  float life = fract(clock * (0.075 + rate * 0.045) + seed);
  float active = smoothstep(0.0, 0.045, life) * (1.0 - smoothstep(0.39, 0.46, life));
  float angle = clock * (0.65 + rate) + phase;
  VERTEX.xz = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * VERTEX.xz;
  VERTEX *= active;
  VERTEX.x += sin(life * 14.0 + phase) * 0.12;
  VERTEX.z += cos(life * 11.0 + phase) * 0.09;
  VERTEX.y += 1.55 - min(life, 0.46) * 3.1;
  glow = 0.0;
 }
}
void fragment() {
 ALBEDO = tint.rgb;
 EMISSION = fireflies ? tint.rgb * glow * 2.2 : vec3(0.0);
}
"""
func setup(terrain,tint:Color):
	var rng=RandomNumberGenerator.new();rng.seed=hash([terrain.arena.run_seed,terrain.arena.room_index,"forest_particles"])
	var cells=[]
	for p in terrain.patches:
		if terrain.patches[p]=="vegetation" and p.x%2==0 and p.y%2==0:cells.append(Vector2i(p.x/2,p.y/2))
	# Shuffle with our private stream to distribute a fixed budget across the whole map.
	for i in range(cells.size()-1,0,-1):
		var other=rng.randi_range(0,i);var swap=cells[i];cells[i]=cells[other];cells[other]=swap
	if cells.is_empty():return
	var family=terrain.arena.room_palette().get("vegetation","spruce")
	var shader=Shader.new();shader.code=SHADER_CODE
	var color=tint.lerp(Color("9bab55"),.45)
	if family=="charred":color=Color("aaa096")
	elif family=="frost":color=Color("e1e9e4")
	leaves=batch(terrain,cells.slice(0,32),rng,shader,color,false,family)
	if family not in ["charred","frost"]:lights=batch(terrain,cells.slice(0,24),rng,shader,Color("c9df76"),true,family)
	_process(0)
func batch(terrain,cells:Array,rng:RandomNumberGenerator,shader:Shader,color:Color,fireflies:bool,family:String)->MultiMeshInstance3D:
	var mesh=BoxMesh.new();mesh.size=Vector3(.027,.027,.027) if fireflies else Vector3(.038,.016,.052) if family=="frost" else Vector3(.065,.013,.032)
	var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true;multi.mesh=mesh;multi.instance_count=cells.size()
	for i in range(cells.size()):
		var pos=terrain.arena.world_pos(cells[i])+Vector3(rng.randf_range(-.30,.30),0,rng.randf_range(-.30,.30))
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,pos));multi.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),0,1))
	var material=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("tint",color);material.set_shader_parameter("fireflies",fireflies);materials.append(material)
	var node=MultiMeshInstance3D.new();node.name="Fireflies" if fireflies else "FallingLeaves";node.multimesh=multi;node.material_override=material;node.extra_cull_margin=2
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);return node
func _process(delta):
	visible=Settings.values.get("atmosphere",true)
	if not visible:return
	clock+=delta
	if is_instance_valid(lights):lights.visible=Settings.values.get("world_lighting","day")=="night"
	for material in materials:material.set_shader_parameter("clock",clock)
