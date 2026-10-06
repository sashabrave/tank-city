class_name MeshMerge
extends RefCounted
## Fewer draw calls (T-331): a model's still parts that share a material become one mesh, so the HQ is ~15
## meshes instead of 178 and every prop draws once per material instead of once per bolt. Done once per model
## file; later instances duplicate the merged template (meshes stay shared). The look does not change: same
## geometry, transforms, materials and vertex colours (baked AO).
## Nodes the code finds or moves by name stay separate (KEEP: name prefixes, as scripts look them up). A kept
## node with children is a moving rigid group (a wheel, the radar dish): its own parts merge among themselves
## under it. Animated or skinned models are left whole.
const KEEP:=["Amber headlamp","Taillight pillar","RadarDish","WheelPivot","HeadlightMount","CommandScreen","ScanRing","Scan","Muzzle","SupportGrip","Rotor","Fan","FireGlow","Rebar","SoftCone","Flashlight","Floodlight"]
## A part smaller than this (longest side, metres) casts no sun shadow: from the battle camera it is not seen,
## yet each one was drawn again in every shadow cascade.
const SHADOW_MIN_SIZE:=.3
static var templates:Dictionary={}
## Off: models load whole and small parts keep their shadow (the look before T-331; screenshot comparison).
static var enabled:=true

static func instance(path:String)->Node3D:
	if not enabled:return load(path).instantiate()
	if not templates.has(path):
		var raw:Node3D=load(path).instantiate()
		merge(raw)
		templates[path]=raw
	# Without DUPLICATE_USE_INSTANTIATION: the default re-reads the original .glb and brings the parts back.
	return templates[path].duplicate(Node.DUPLICATE_SIGNALS|Node.DUPLICATE_GROUPS|Node.DUPLICATE_SCRIPTS)

static func kept(node:Node)->bool:
	for prefix in KEEP:
		if str(node.name).begins_with(prefix):return true
	return false

## The merge root a part belongs to: the nearest kept ancestor (a moving group) or the model root.
static func group_root(node:Node,root:Node)->Node:
	var current=node.get_parent()
	while current!=null and current!=root:
		if kept(current):return current
		current=current.get_parent()
	return root

## Transform of `node` in `root` space, read through the parents (the template is outside the tree).
static func local_transform(node:Node3D,root:Node3D)->Transform3D:
	var xf=Transform3D.IDENTITY;var current:Node=node
	while current!=null and current!=root:
		if current is Node3D:xf=current.transform*xf
		current=current.get_parent()
	return xf

static func merge(root:Node3D)->int:
	if not root.find_children("*","AnimationPlayer",true,false).is_empty() or not root.find_children("*","Skeleton3D",true,false).is_empty():return 0
	var pivots=root.find_children("*","Node3D",true,false).filter(func(node):return kept(node) and not node is MeshInstance3D and node.get_child_count()>0)
	var built=merge_into(root,root)
	for pivot in pivots:built+=merge_into(root,pivot)
	return built

## Code-built shapes (boxes, cones under one node): parts with the same material_override join into one mesh
## under `target`. Only for groups the code never edits part by part afterwards.
static func merge_built(target:Node3D)->int:
	return merge_into(target,target,true)

static func merge_into(root:Node3D,target:Node3D,overrides:=false)->int:
	var groups:Dictionary={}
	var parts:Array=[]
	for mesh:MeshInstance3D in target.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null or mesh.get_child_count()>0 or mesh.skin!=null or (mesh.material_override!=null)!=overrides or not mesh.visible or kept(mesh) or group_root(mesh,root)!=target:continue
		var xf=local_transform(mesh,target)
		var small=(local_transform(mesh,root)*mesh.mesh.get_aabb()).get_longest_axis_size()<SHADOW_MIN_SIZE
		var shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if small else mesh.cast_shadow
		var ok=true
		for s in range(mesh.mesh.get_surface_count()):
			if (mesh.mesh is ArrayMesh and mesh.mesh.surface_get_primitive_type(s)!=Mesh.PRIMITIVE_TRIANGLES) or mesh.get_surface_override_material(s)!=null:ok=false
		if not ok:continue
		for s in range(mesh.mesh.get_surface_count()):
			var material=mesh.material_override if overrides else mesh.mesh.surface_get_material(s)
			# Surfaces merge only with the same material, vertex format and shadow mode.
			# Code primitives (BoxMesh, CylinderMesh…) are triangles with normals, tangents and UVs.
			var format=(mesh.mesh.surface_get_format(s) if mesh.mesh is ArrayMesh else Mesh.ARRAY_FORMAT_NORMAL|Mesh.ARRAY_FORMAT_TANGENT|Mesh.ARRAY_FORMAT_TEX_UV)&(Mesh.ARRAY_FORMAT_NORMAL|Mesh.ARRAY_FORMAT_TANGENT|Mesh.ARRAY_FORMAT_COLOR|Mesh.ARRAY_FORMAT_TEX_UV|Mesh.ARRAY_FORMAT_TEX_UV2)
			var key=[material.get_instance_id() if material else 0,format,shadow,mesh.layers]
			if not groups.has(key):groups[key]={"material":material,"shadow":shadow,"layers":mesh.layers,"items":[]}
			groups[key].items.append([mesh.mesh,s,xf])
		parts.append(mesh)
	var built=0
	# A lone part stays as it is.
	if parts.size()<2:return 0
	for key in groups:
		var group=groups[key]
		var tool=SurfaceTool.new()
		for item in group.items:tool.append_from(item[0],item[1],item[2])
		if group.material and not overrides:tool.set_material(group.material)
		var joined=MeshInstance3D.new();joined.name="Merged%d" % built
		joined.mesh=tool.commit();joined.cast_shadow=group.shadow;joined.layers=group.layers
		if overrides:joined.material_override=group.material
		target.add_child(joined);joined.owner=root;built+=1
	for mesh in parts:
		mesh.get_parent().remove_child(mesh);mesh.free()
	return built
