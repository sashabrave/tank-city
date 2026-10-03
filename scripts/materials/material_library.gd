class_name MaterialLibrary
extends RefCounted
## One place for how surfaces look (author, 2026-10-03): data/materials.json holds the surfaces (steel,
## gunmetal, brass, painted metal, rubber, wood, fabric, concrete, glass) and what uses them:
##   "palette" — palette atlas cells (guns, troops, lamps, gates…) → surface, so metal goes on the parts only;
##   "names"   — material-name fragments of imported models → surface;
##   procedural boxes ask for a surface directly: Visuals.box(…, "steel").
## The tester tool (Инструменты → Материалы) edits it live; «Сохранить» writes the file (project file when run
## from the editor, a user override in a build), «Сбросить» goes back to what is saved.
const PATH:="res://data/materials.json"
const USER_PATH:="user://materials_override.json"
static var data:Dictionary={}
static var loaded:=false

static func ensure():
	if loaded:return
	loaded=true;data=read(PATH)
	if FileAccess.file_exists(USER_PATH) and not OS.has_feature("editor"):
		var user=read(USER_PATH)
		for key in ["surfaces","palette"]:
			if user.get(key) is Dictionary:data[key].merge(user[key],true)
static func read(path:String)->Dictionary:
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var result:Dictionary=parsed if parsed is Dictionary else {}
	for key in ["surfaces","palette"]:
		if not result.get(key) is Dictionary:result[key]={}
	if not result.get("names") is Array:result["names"]=[]
	return result

static func surfaces()->Dictionary:ensure();return data.surfaces
static func surface(kind:String)->Dictionary:ensure();return data.surfaces.get(kind,{})
static func palette_surface(cell:String)->String:ensure();return str(data.palette.get(cell,""))
## Surface for an imported material by its name, "" when no rule matches.
static func by_name(title:String)->String:
	ensure()
	for rule in data.names:
		if str(rule[0]) in title:return str(rule[1])
	return ""

## Writes what is on screen now. From the editor the project file itself (to commit), in a build the
## player-side override.
static func save()->bool:
	ensure()
	var path=PATH if OS.has_feature("editor") else USER_PATH
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(data,"\t"));file.close();return true
## Back to the saved state (drops unsaved live edits).
static func reset():
	loaded=false;ensure()
## Painted vehicle hulls (team_paint shader) take the «paint» surface.
static func paint_params(mat:ShaderMaterial):
	var spec=surface("paint")
	mat.set_shader_parameter("paint_metallic",float(spec.get("metallic",.25)));mat.set_shader_parameter("paint_roughness",float(spec.get("roughness",.45)));mat.set_shader_parameter("paint_clearcoat",float(spec.get("clearcoat",.5)))
## Re-applies every material in the running scene (after an edit).
static func apply_live(tree:SceneTree):
	Visuals.palette_orm_texture=null
	for key in Visuals.surface_cache:
		if is_instance_valid(Visuals.surface_cache[key]):Visuals.cozy_material(Visuals.surface_cache[key])
	Visuals.refresh_cozy_materials(tree.root)
	paint_live(tree.root)
static func paint_live(node:Node):
	if node is GeometryInstance3D:
		var targets=[node.material_override]
		if node is MeshInstance3D and node.mesh:
			for i in range(node.mesh.get_surface_count()):targets.append(node.get_surface_override_material(i))
		for mat in targets:
			if mat is ShaderMaterial and mat.shader==preload("res://assets/shaders/team_paint.gdshader"):paint_params(mat)
	for child in node.get_children():paint_live(child)
