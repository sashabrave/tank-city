extends MultiMeshInstance3D
## Grid ambient occlusion for the field floor (setting «Глубина света»): along every floor-cell edge that
## touches a wall, a flat strip darkens the floor towards a cool shade; inner corners get two strips.
## One draw call; rebuilt when a wall is destroyed. Visual only.
const DEPTH=.6
const LIFT=.006
var arena
static func build_for(context)->Node:
	var old=context.get_node_or_null("FloorAO")
	if old:old.name="FloorAOOld";old.queue_free()
	var ao=load("res://scripts/systems/floor_ao.gd").new();ao.name="FloorAO";ao.arena=context;context.add_child(ao);ao.rebuild();return ao
func _ready():
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/world/floor_ao.gdshader");material_override=mat
	Settings.changed.connect(func():visible=bool(Settings.values.get("depth_light",true)) and bool(Settings.values.get("shaders",true)))
	visible=bool(Settings.values.get("depth_light",true)) and bool(Settings.values.get("shaders",true))
func rebuild():
	if not is_instance_valid(arena):return
	var strips=[]
	var g=arena.grid_size
	for y in range(g):
		for x in range(g):
			var cell=Vector2i(x,y)
			if arena.walls.has(cell):continue
			for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if arena.walls.has(cell+d):strips.append([cell,d])
	var quad=QuadMesh.new();quad.size=Vector2(1.0,DEPTH);quad.orientation=PlaneMesh.FACE_Y
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=quad;mm.instance_count=strips.size()
	for i in range(strips.size()):
		var cell:Vector2i=strips[i][0];var d:Vector2i=strips[i][1]
		var dir=Vector3(d.x,0,d.y)
		# Local +Z of the quad points into the cell (UV.y grows away from the wall).
		var basis=Basis.looking_at(-dir,Vector3.UP)
		var origin=arena.world_pos(cell)+dir*(.5-DEPTH*.5);origin.y+=LIFT
		mm.set_instance_transform(i,Transform3D(basis,origin))
	multimesh=mm
