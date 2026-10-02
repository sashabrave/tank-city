extends MultiMeshInstance3D
## Floor contact shadows (setting «Глубина света»), one draw call, visual only.
## Arena: one quad per floor cell next to a wall (sides and diagonals), shaded per cell so the shadow runs
## unbroken along walls and wraps round corners; rebuilt when a wall is destroyed.
## Hub (and any scene without a wall grid): a soft rounded-rectangle shadow under each static box that stands
## on the floor (build_props).
const DEPTH=.34
const LIFT=.006
var arena
static func build_for(context)->Node:
	var old=context.get_node_or_null("FloorAO")
	if old:old.name="FloorAOOld";old.queue_free()
	var ao=load("res://scripts/systems/floor_ao.gd").new();ao.name="FloorAO";ao.arena=context;context.add_child(ao);ao.rebuild();return ao
static func build_props(context:Node3D,skip:Array=[])->Node:
	var ao=load("res://scripts/systems/floor_ao.gd").new();ao.name="FloorAO";context.add_child(ao);ao.rebuild_props(context,skip);return ao
## A small soft shadow under a soldier (the hero in battle and in the hub): one quad in box mode that follows
## the model, so the figure stands on the floor even in flat light.
static func contact_shadow(model:Node3D):
	if model.has_node("ContactShadow"):return
	var shadow=MeshInstance3D.new();shadow.name="ContactShadow";var quad=QuadMesh.new();quad.size=Vector2(1.15,1.15);quad.orientation=PlaneMesh.FACE_Y;shadow.mesh=quad
	shadow.position.y=LIFT+.004;shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/world/contact_shadow.gdshader");shadow.material_override=mat
	model.add_child(shadow)
func _ready():
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/world/floor_ao.gdshader");mat.set_shader_parameter("depth",DEPTH);material_override=mat
	Settings.changed.connect(func():visible=bool(Settings.values.get("depth_light",true)) and bool(Settings.values.get("shaders",true)))
	visible=bool(Settings.values.get("depth_light",true)) and bool(Settings.values.get("shaders",true))
func rebuild():
	if not is_instance_valid(arena):return
	var cells=[]
	var g=arena.grid_size
	var sides=[[Vector2i.LEFT,1],[Vector2i.RIGHT,2],[Vector2i.UP,4],[Vector2i.DOWN,8]]
	var corners=[[Vector2i(-1,-1),1],[Vector2i(1,-1),2],[Vector2i(-1,1),4],[Vector2i(1,1),8]]
	for y in range(g):
		for x in range(g):
			var cell=Vector2i(x,y)
			if arena.walls.has(cell):continue
			var s=0;var c=0
			for e in sides:if arena.walls.has(cell+e[0]):s+=e[1]
			for e in corners:if arena.walls.has(cell+e[0]):c+=e[1]
			if s or c:cells.append([cell,s,c])
	var quad=QuadMesh.new();quad.size=Vector2.ONE;quad.orientation=PlaneMesh.FACE_Y
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=quad;mm.instance_count=cells.size()
	for i in range(cells.size()):
		var origin=arena.world_pos(cells[i][0]);origin.y+=LIFT
		mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,origin));mm.set_instance_custom_data(i,Color(cells[i][1],cells[i][2],0,0))
	multimesh=mm
func rebuild_props(root:Node3D,skip:Array):
	material_override.set_shader_parameter("boxes",true);material_override.set_shader_parameter("strength",.3)
	var items=[]
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		if not mesh.visible or mesh.mesh==null or skip.any(func(n):return is_instance_valid(n) and (n==mesh or n.is_ancestor_of(mesh))):continue
		var box=mesh.get_aabb();var b=mesh.global_basis
		var half=Vector2(box.size.x*b.x.length(),box.size.z*b.z.length())*.5
		var height=box.size.y*b.y.length()
		var bottom=(mesh.global_transform*box.position).y
		var center=mesh.global_transform*box.get_center()
		# Standing props only: floor-level bottom, some height, not the floor itself.
		if height<.25 or half.x<.06 or half.y<.06 or half.x>2.2 or half.y>2.2 or bottom<-.2 or bottom>.12:continue
		var yaw=atan2(-b.x.z,b.x.x)
		var quad_half=half+Vector2.ONE*DEPTH
		var t=Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3(quad_half.x*2.0,1,quad_half.y*2.0)),Vector3(center.x,bottom+LIFT,center.z))
		items.append([root.global_transform.affine_inverse()*t,Color(half.x,half.y,quad_half.x,quad_half.y)])
	var quad=QuadMesh.new();quad.size=Vector2.ONE;quad.orientation=PlaneMesh.FACE_Y
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=quad;mm.instance_count=items.size()
	for i in range(items.size()):mm.set_instance_transform(i,items[i][0]);mm.set_instance_custom_data(i,items[i][1])
	multimesh=mm
