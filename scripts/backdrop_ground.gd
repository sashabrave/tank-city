extends MeshInstance3D
## Ground around the battle board (0.8): the board stands on a biome-coloured surface with a minimal relief —
## flat near the board, soft hills further out. Visual only, own seed. height() places props and silhouettes.
const LEVEL=-1.1  # just under the board's plinth (FieldBorder slab bottom)
const SIZE=110.0
const STEPS=88
var radius=10.0
var noise:=FastNoiseLite.new()

static func colors(palette:Dictionary,family:String)->Array:
	var floor=Color(str(palette.get("floor","9aa08a")));var edge=Color(str(palette.get("edge","7d8270")))
	var green={"forest":Color("5f7a52"),"marsh":Color("5e7a62"),"mountains":Color("7d8a86"),"desert":Color("a8925f"),"inferno":Color("5a4038"),"city":Color("6f7368")}.get(family,Color("6c7a5a"))
	return [floor.lerp(edge,.35).darkened(.06),green.lerp(edge,.35),floor.lightened(.04)]

func setup(palette:Dictionary,family:String,size_radius:float,seed_value:int):
	radius=size_radius
	noise.seed=seed_value;noise.frequency=.045;noise.fractal_octaves=3
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step=SIZE/STEPS
	for zi in range(STEPS):
		for xi in range(STEPS):
			var corners=[Vector2(xi,zi),Vector2(xi+1,zi),Vector2(xi+1,zi+1),Vector2(xi,zi+1)]
			var points=corners.map(func(c):var x=-SIZE*.5+c.x*step;var z=-SIZE*.5+c.y*step;return Vector3(x,height(x,z),z))
			for index in [0,1,2,0,2,3]:tool.add_vertex(points[index])
	tool.generate_normals()
	mesh=tool.commit()
	var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/world/biome_ground.gdshader")
	var tones=colors(palette,family)
	mat.set_shader_parameter("base_color",tones[0]);mat.set_shader_parameter("patch_color",tones[1]);mat.set_shader_parameter("accent_color",tones[2])
	mat.set_shader_parameter("seed",float(seed_value%997))
	material_override=mat
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Ground height: level under and right around the board, rising into soft hills further out.
func height(x:float,z:float)->float:
	var away=maxf(absf(x),absf(z))
	var hills=smoothstep(radius+1.5,radius+9.0,away)
	return LEVEL+(noise.get_noise_2d(x,z)*.5+.5)*1.8*hills+.08*(1.0-hills)  # the plinth sinks a little into the ground
