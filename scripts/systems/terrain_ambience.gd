extends Node3D
## One batched draw per effect, no particle nodes or physics per tile.
var clock=0.0
var materials:Array=[]
const EFFECT_SHADER="""
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float clock = 0.0;
uniform int kind = 0;
uniform vec4 tint : source_color;
void vertex() {
 float seed = INSTANCE_CUSTOM.x;
 if (kind == 0) {
  float frame = mod(floor(clock * 3.0 + seed * 3.0), 3.0);
  VERTEX.x *= 0.80 + frame * 0.24;
  VERTEX.z += (frame - 1.0) * 0.018;
 } else {
  float life = fract(clock * (kind == 1 ? 0.24 : 0.34) + seed);
  float active = step(life, 0.55);
  VERTEX *= active * smoothstep(0.0, 0.07, life) * (1.0 - smoothstep(0.46, 0.55, life));
  if (kind == 1) {
   VERTEX.y += 0.62 - life * 1.0;
   VERTEX.x += sin(life * 9.0 + seed * 20.0) * 0.065;
  } else {
   VERTEX.x += (life - 0.27) * 0.9;
   VERTEX.z += (life - 0.27) * 0.22;
   VERTEX.y += 0.10 + sin(life * 5.7) * 0.10;
  }
 }
}
void fragment() { ALBEDO = tint.rgb; }
"""
func setup(terrain,tint:Color):
	var forest=preload("res://scripts/systems/vegetation_ambience.gd").new();forest.name="ForestAmbience";add_child(forest);forest.setup(terrain,tint)
	var shader=Shader.new();shader.code=EFFECT_SHADER
	for kind in ["water","ice","sand"]:
		var positions=[];var phases=[]
		var rng=RandomNumberGenerator.new();rng.seed=terrain.arena.run_seed+terrain.arena.room_index*41+kind.hash()
		for p in terrain.patches:
			if terrain.patches[p]!=kind:continue
			if kind!="water" and (p.x+p.y)%2!=0:continue
			var center=terrain.half_pos(p)
			if kind=="water":
				for i in range(3):positions.append(center+Vector3(-.07+i*.13,-.031,-.12+i*.21));phases.append(rng.randf())
			else:
				positions.append(center+Vector3(rng.randf_range(0,.45),0,rng.randf_range(0,.45)));phases.append(rng.randf())
		if positions.is_empty():continue
		var mesh=BoxMesh.new();mesh.size=Vector3(.24,.006,.016) if kind=="water" else Vector3(.047,.028,.047) if kind=="ice" else Vector3(.04,.025,.031)
		var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true;multi.mesh=mesh;multi.instance_count=positions.size()
		for i in range(positions.size()):
			multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,positions[i]));multi.set_instance_custom_data(i,Color(phases[i],0,0,1))
		var material=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("kind",["water","ice","sand"].find(kind))
		material.set_shader_parameter("tint",tint.lerp(Color("416d80"),.65).lightened(.3) if kind=="water" else tint.lerp(Color("e8eef0"),.8) if kind=="ice" else tint.lerp(Color("cfb989"),.6))
		var node=MultiMeshInstance3D.new();node.name=kind;node.multimesh=multi;node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.extra_cull_margin=1;add_child(node);materials.append(material)
func _process(delta):
	clock+=delta
	for material in materials:material.set_shader_parameter("clock",clock)
