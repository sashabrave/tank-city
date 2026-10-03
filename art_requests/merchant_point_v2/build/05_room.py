"""
BUILD PHASE TEMPLATE
Copy this file to <asset>/build/NN_<phase>.py, fill in build(), run:

  blender --background --python build/02_blockout.py -- --master <asset>_master.blend

Every phase script is re-runnable: it opens the master, deletes what it owns
(objects whose names carry OWNER_TAG in a custom property), rebuilds them, saves.
Nothing else in the file is touched, so earlier phases and manual edits survive.

Coordinate convention: metres, Z up, subject faces -Y, origin at the ground
contact point (characters, props, architecture) or the ground centre (vehicles).
"""
import bpy, bmesh, sys, os, math, argparse
from mathutils import Vector, Matrix, Euler

PHASE = "05_room"
OWNER_TAG = "phase:" + PHASE   # objects created here get ob["owner"] = OWNER_TAG


# ARGS AND FILE HANDLING

def argv_after_dashes():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


def open_master(path):
    bpy.ops.wm.open_mainfile(filepath=os.path.abspath(path))
    return bpy.context.scene


def save_master(path):
    bpy.context.preferences.filepaths.save_version = 0   # no .blend1 backups
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(path))


def col(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
    return c


def clear_owned(tag=None):
    """Delete every object this phase created last time, so the script is idempotent."""
    tag = tag or OWNER_TAG
    for ob in [o for o in bpy.data.objects if o.get("owner") == tag]:
        data = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        if data is not None and data.users == 0:
            if isinstance(data, bpy.types.Mesh):
                bpy.data.meshes.remove(data)
            elif isinstance(data, bpy.types.Curve):
                bpy.data.curves.remove(data)
            elif isinstance(data, bpy.types.Armature):
                bpy.data.armatures.remove(data)


def own(ob):
    ob["owner"] = OWNER_TAG
    return ob


def log(*a):
    print("[" + PHASE + "]", *a)


# MESH PRIMITIVES (bmesh based, no operators, safe in background mode)

def new_mesh_object(name, bm, collection, location=(0, 0, 0), rotation=(0, 0, 0), scale=(1, 1, 1)):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.location = location
    ob.rotation_euler = rotation
    ob.scale = scale
    col(collection).objects.link(ob)
    return own(ob)


def box(name, size, collection="LOW", location=(0, 0, 0), rotation=(0, 0, 0), base_at_origin=False):
    """size = (x, y, z). base_at_origin puts the bottom face on z=0."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    if base_at_origin:
        bmesh.ops.translate(bm, vec=(0, 0, size[2] / 2), verts=bm.verts)
    return new_mesh_object(name, bm, collection, location, rotation)


def cylinder(name, radius, height, collection="LOW", segments=32, axis="Z", location=(0, 0, 0),
             radius_top=None, base_at_origin=False):
    """Cylinder or truncated cone along axis. radius_top defaults to radius."""
    bm = bmesh.new()
    r2 = radius if radius_top is None else radius_top
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments,
                          radius1=radius, radius2=r2, depth=height)
    if base_at_origin:
        bmesh.ops.translate(bm, vec=(0, 0, height / 2), verts=bm.verts)
    if axis == "X":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Y"), verts=bm.verts)
    elif axis == "Y":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-90), 3, "X"), verts=bm.verts)
    return new_mesh_object(name, bm, collection, location)


def sphere(name, radius, collection="LOW", location=(0, 0, 0), u=24, v=12, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=radius)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    return new_mesh_object(name, bm, collection, location)


def grid(name, size_x, size_y, cuts_x, cuts_y, collection="LOW", location=(0, 0, 0), rotation=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=cuts_x, y_segments=cuts_y, size=0.5)
    bmesh.ops.scale(bm, vec=(size_x, size_y, 1), verts=bm.verts)
    return new_mesh_object(name, bm, collection, location, rotation)


def loft(name, sections, collection="LOW", close_sections=True, cap_ends=True, smooth=True):
    """Bridge a list of cross sections (each a list of Vector/tuple, same point count) into a hull.
    Use it for vehicle bodies, boat hulls, torsos: read section widths/heights off the top and side
    reference views at fixed stations along the length."""
    bm = bmesh.new()
    rings = []
    for sec in sections:
        vs = [bm.verts.new(Vector(p)) for p in sec]
        ring = []
        for i in range(len(vs)):
            if i == len(vs) - 1 and not close_sections:
                break
            ring.append(bm.edges.new((vs[i], vs[(i + 1) % len(vs)])))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        bmesh.ops.bridge_loops(bm, edges=a + b)
    if cap_ends and close_sections:
        bmesh.ops.contextual_create(bm, geom=rings[0])
        bmesh.ops.contextual_create(bm, geom=rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_mesh_object(name, bm, collection)
    if smooth:
        shade_smooth(ob, math.radians(35))
    return ob


def profile_spin(name, profile_xz, collection="LOW", steps=32, location=(0, 0, 0), angle=360):
    """Lathe a 2D profile (list of (radius, z)) around Z: vases, columns, wheel rims, bolts."""
    bm = bmesh.new()
    verts = [bm.verts.new((r, 0, z)) for r, z in profile_xz]
    edges = [bm.edges.new((verts[i], verts[i + 1])) for i in range(len(verts) - 1)]
    bmesh.ops.spin(bm, geom=verts + edges, cent=(0, 0, 0), axis=(0, 0, 1),
                   angle=math.radians(angle), steps=steps, use_merge=(angle >= 360))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_mesh_object(name, bm, collection, location)


def profile_extrude(name, profile_xy, length, collection="LOW", location=(0, 0, 0), rotation=(0, 0, 0)):
    """Extrude a closed 2D outline (list of (x, y)) along Z: arches, mouldings, I-beams, tracks, trims."""
    bm = bmesh.new()
    verts = [bm.verts.new((x, y, 0)) for x, y in profile_xy]
    face = bm.faces.new(verts)
    res = bmesh.ops.extrude_face_region(bm, geom=[face])
    top = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, 0, length), verts=top)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_mesh_object(name, bm, collection, location, rotation)


def curve_tube(name, points, radius, collection="LOW", resolution=12, taper_to=None, bevel_res=6):
    """Poly/bezier tube through points: cables, horns, tails, pipes, tentacles, railings, roots."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("NURBS")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (p[0], p[1], p[2], 1.0)
        if taper_to is not None:
            t = i / max(1, len(points) - 1)
            sp.points[i].radius = 1.0 + (taper_to - 1.0) * t
    sp.use_endpoint_u = True
    sp.order_u = min(4, len(points))
    cu.resolution_u = resolution
    cu.bevel_depth = radius
    cu.bevel_resolution = bevel_res
    cu.use_fill_caps = True
    ob = bpy.data.objects.new(name, cu)
    col(collection).objects.link(ob)
    return own(ob)


def skin_chain(name, joints, collection="HIGH", subdiv=2, root_index=0):
    """Organic blockout in one call. joints = [(x, y, z, radius), ...] connected in order, or a dict
    {"name": [(x, y, z, r), ...], ...} of chains sharing their first point with another chain by position.
    Skin modifier + Subdivision gives a smooth mass with quad loops at every joint, which is a usable
    LOW base for stylized characters after shrinkwrapping to the sculpt."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    chains = joints if isinstance(joints, dict) else {"main": joints}
    vert_by_pos = {}
    order = []
    for cname, pts in chains.items():
        prev = None
        for (x, y, z, r) in pts:
            key = (round(x, 5), round(y, 5), round(z, 5))
            v = vert_by_pos.get(key)
            if v is None:
                v = bm.verts.new((x, y, z))
                vert_by_pos[key] = v
                order.append((v, r))
            if prev is not None and prev is not v:
                if not bm.edges.get((prev, v)):
                    bm.edges.new((prev, v))
            prev = v
    bm.verts.index_update()
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    col(collection).objects.link(ob)
    skin = ob.modifiers.new("Skin", "SKIN")
    skin.use_smooth_shade = True
    # skin_vertices layer exists once the modifier is present
    layer = me.skin_vertices[0].data
    for i, (v, r) in enumerate(order):
        layer[i].radius = (r, r)
        layer[i].use_root = (i == root_index)
    sub = ob.modifiers.new("Subdivision", "SUBSURF")
    sub.levels = subdiv
    sub.render_levels = subdiv
    return own(ob)


# MODIFIERS AND EDITS

def mirror_origin():
    """Shared empty at the world origin so mirrors work across the asset's centre line,
    not across each object's own origin (the classic Blender mirror mistake)."""
    ob = bpy.data.objects.get("REF_mirror_origin")
    if ob is None:
        ob = bpy.data.objects.new("REF_mirror_origin", None)
        ob.empty_display_type = "PLAIN_AXES"
        ob.empty_display_size = 0.05
        col("REF").objects.link(ob)
    return ob


def mirror(ob, axis="X", merge=0.001, clip=True, about_world=True):
    """Mirror across the world centre plane by default. Pass about_world=False to mirror
    across the object's own origin (only right when the origin sits on the symmetry plane)."""
    m = ob.modifiers.new("Mirror", "MIRROR")
    m.use_axis = (axis == "X", axis == "Y", axis == "Z")
    m.use_mirror_merge = merge > 0
    m.merge_threshold = merge
    m.use_clip = clip
    if about_world:
        m.mirror_object = mirror_origin()
    return m


def bevel(ob, width=0.01, segments=3, angle_limit=30, harden=True):
    b = ob.modifiers.new("Bevel", "BEVEL")
    b.width = width
    b.segments = segments
    b.limit_method = "ANGLE"
    b.angle_limit = math.radians(angle_limit)
    b.harden_normals = harden
    return b


def subsurf(ob, levels=2):
    s = ob.modifiers.new("Subdivision", "SUBSURF")
    s.levels = levels
    s.render_levels = levels
    return s


def solidify(ob, thickness=0.01, offset=-1.0, rim=True):
    s = ob.modifiers.new("Solidify", "SOLIDIFY")
    s.thickness = thickness
    s.offset = offset
    s.use_rim = rim
    return s


def boolean(ob, cutter, op="DIFFERENCE", hide_cutter=True, solver="EXACT"):
    b = ob.modifiers.new("Bool_" + cutter.name, "BOOLEAN")
    b.operation = op
    b.object = cutter
    b.solver = solver
    if hide_cutter:
        cutter.hide_render = True
        cutter.hide_viewport = True
        cutter.display_type = "WIRE"
    return b


def array(ob, count, offset=(1, 0, 0), relative=True, curve=None):
    a = ob.modifiers.new("Array", "ARRAY")
    a.count = count
    if relative:
        a.relative_offset_displace = offset
    else:
        a.use_relative_offset = False
        a.use_constant_offset = True
        a.constant_offset_displace = offset
    if curve is not None:
        a.fit_type = "FIT_CURVE"
        a.curve = curve
        c = ob.modifiers.new("Curve", "CURVE")
        c.object = curve
    return a


def shrinkwrap(ob, target, offset=0.0, mode="NEAREST_SURFACEPOINT"):
    s = ob.modifiers.new("Shrinkwrap", "SHRINKWRAP")
    s.target = target
    s.offset = offset
    s.wrap_method = mode
    return s


def remesh_voxel(ob, voxel_size=0.02, smooth_normals=True):
    r = ob.modifiers.new("Remesh", "REMESH")
    r.mode = "VOXEL"
    r.voxel_size = voxel_size
    r.use_smooth_shade = smooth_normals
    return r


def decimate(ob, ratio):
    d = ob.modifiers.new("Decimate", "DECIMATE")
    d.ratio = ratio
    return d


def apply_all_modifiers(ob):
    """Bake the modifier stack into the mesh without operators (safe in background)."""
    dg = bpy.context.evaluated_depsgraph_get()
    eo = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(eo)
    old = ob.data
    name = old.name
    ob.data = me
    ob.modifiers.clear()
    if old.users == 0:
        bpy.data.meshes.remove(old)
    me.name = name                      # keep the mesh name free of .001
    return ob


def apply_transform(ob):
    """Freeze location/rotation/scale into the mesh. Only for unparented objects."""
    if ob.parent is not None or ob.type != "MESH":
        return ob
    ob.data.transform(ob.matrix_basis)
    ob.matrix_basis = Matrix.Identity(4)
    return ob


def set_origin(ob, world_point):
    """Move the object origin to world_point without moving the geometry."""
    p = Vector(world_point)
    local = ob.matrix_world.inverted() @ p
    ob.data.transform(Matrix.Translation(-local))
    ob.matrix_world = ob.matrix_world @ Matrix.Translation(local)
    return ob


def join_meshes(name, objects, collection="LOW"):
    """Merge several mesh objects into one new object in world space. Sources are left alone."""
    bm = bmesh.new()
    dg = bpy.context.evaluated_depsgraph_get()
    for ob in objects:
        eo = ob.evaluated_get(dg)
        me = eo.to_mesh()
        tmp = bmesh.new()
        tmp.from_mesh(me)
        bmesh.ops.transform(tmp, matrix=eo.matrix_world, verts=tmp.verts)
        tmp_me = bpy.data.meshes.new("_tmp_join")
        tmp.to_mesh(tmp_me)
        tmp.free()
        bm.from_mesh(tmp_me)
        bpy.data.meshes.remove(tmp_me)
        eo.to_mesh_clear()
    return new_mesh_object(name, bm, collection)


def duplicate(ob, name, collection=None):
    new = ob.copy()
    new.data = ob.data.copy()
    new.name = name
    new.data.name = name
    col(collection or ob.users_collection[0].name).objects.link(new)
    return own(new)


def shade_smooth(ob, sharp_angle=math.radians(30)):
    """Smooth shading with sharp edges marked by angle. Marked sharp edges always split normals in 4.1+."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) == 2:
            e.smooth = e.calc_face_angle(0.0) <= sharp_angle
    bm.to_mesh(me)
    bm.free()
    if hasattr(me, "use_auto_smooth"):      # 4.0 only; removed in 4.1
        me.use_auto_smooth = True
        me.auto_smooth_angle = math.pi
    return ob


def push(ob, center, radius, strength, direction=None, falloff="smooth"):
    """Code sculpting: move vertices within radius of center along their normal (or direction)."""
    me = ob.data
    c = ob.matrix_world.inverted() @ Vector(center)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    d = None if direction is None else (ob.matrix_world.to_3x3().inverted() @ Vector(direction)).normalized()
    for v in bm.verts:
        t = (v.co - c).length / radius
        if t >= 1.0:
            continue
        w = (1 - t * t) ** 2 if falloff == "smooth" else (1 - t)
        v.co += (d if d is not None else v.normal) * strength * w
    bm.to_mesh(me)
    bm.free()
    return ob


def taper(ob, axis="Z", top_scale=0.5, bottom=None, top=None):
    """Scale cross sections linearly along an axis (limb tapering, spires, hulls)."""
    me = ob.data
    idx = "XYZ".index(axis)
    cos = [v.co[idx] for v in me.vertices]
    lo = min(cos) if bottom is None else bottom
    hi = max(cos) if top is None else top
    for v in me.vertices:
        t = 0 if hi == lo else max(0.0, min(1.0, (v.co[idx] - lo) / (hi - lo)))
        s = 1 + (top_scale - 1) * t
        for j in range(3):
            if j != idx:
                v.co[j] *= s
    return ob


# UV

def smart_uv(ob, angle=66.0, margin=0.02, seams_from_sharp=True):
    """Quick unwrap for blockouts, props and hard surface: Smart UV Project through the operator,
    with seams taken from marked sharp edges when asked. Hero deforming parts get seams placed
    by hand in the phase script (mark_seams) and unwrap_by_seams instead."""
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    if seams_from_sharp:
        bpy.ops.mesh.edges_select_sharp(sharpness=math.radians(angle))
        bpy.ops.mesh.mark_seam(clear=False)
        bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def mark_seams(ob, edge_filter):
    """edge_filter(bmesh_edge) -> bool. Marks seams by rule, e.g. lambda e: abs(e.verts[0].co.x) < 1e-4."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    n = 0
    for e in bm.edges:
        if edge_filter(e):
            e.seam = True
            n += 1
    bm.to_mesh(me)
    bm.free()
    log("seams marked on", ob.name, n)
    return ob


def unwrap_by_seams(ob, margin=0.02, method="ANGLE_BASED"):
    """Unwrap along marked seams, then pack islands."""
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.unwrap(method=method, margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


# MATERIALS

def material(name, color=(0.5, 0.5, 0.5, 1), roughness=0.5, metallic=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    if bpy.app.version < (5, 0, 0) and not m.use_nodes:   # 5.0+ materials always use nodes
        m.use_nodes = True
    # look nodes up by type: display names are translated in non-English Blender UIs
    bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    return m


def assign(ob, mat):
    if ob.data.materials:
        ob.data.materials[0] = mat
    else:
        ob.data.materials.append(mat)
    return ob


# RIG HELPERS

def armature(name, bones, collection="RIG_DEF"):
    """bones = [(name, head, tail, parent_name_or_None, roll_deg, deform_bool), ...]"""
    arm = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, arm)
    col(collection).objects.link(ob)
    own(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, head, tail, parent, roll, deform in bones:
        eb = arm.edit_bones.new(bname)
        eb.head, eb.tail = Vector(head), Vector(tail)
        eb.roll = math.radians(roll)
        eb.use_deform = deform
        if parent:
            eb.parent = arm.edit_bones[parent]
            eb.use_connect = (Vector(head) - arm.edit_bones[parent].tail).length < 1e-5
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def bind(mesh_ob, arm_ob, method="ARMATURE_AUTO"):
    """Parent with automatic weights. Weight painting corrections come after, in a later phase."""
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    mesh_ob.select_set(True)
    arm_ob.select_set(True)
    bpy.context.view_layer.objects.active = arm_ob
    bpy.ops.object.parent_set(type=method)
    return mesh_ob


def socket(name, location, parent=None, parent_bone=None, rotation=(0, 0, 0), size=0.1, **props):
    """Semantic attachment point. Local +Y = forward of whatever attaches, +Z = its up."""
    ob = bpy.data.objects.new(name, None)
    ob.empty_display_type = "ARROWS"
    ob.empty_display_size = size
    col("SOCKETS").objects.link(ob)
    own(ob)
    if parent is not None:
        ob.parent = parent
        if parent_bone:
            ob.parent_type = "BONE"
            ob.parent_bone = parent_bone
    ob.matrix_world = Matrix.Translation(Vector(location)) @ Euler(rotation).to_matrix().to_4x4()
    for k, v in props.items():
        ob[k] = v
    return ob


def lod_copy(ob, level, ratio):
    """Make <name>_LOD<level> from a LOD0 object with a Decimate at ratio. Rework silhouettes by hand after."""
    base = ob.name.replace("_LOD0", "")
    new = duplicate(ob, base + "_LOD" + str(level))
    decimate(new, ratio)
    return new


# BUILD

# Game units (route_miniatures.gd): round tile radius 3.15. Faces -Y (open shop side toward the map camera).
# Measured from ref/concept_simple.png and the part sheets ref/parts_truck.png, ref/parts_props.png.
TILE_R = 3.15
TILE_H = 0.0             # room version: the truck stands on the room floor
WHEEL_R = 0.66           # concept: wheels ≈ half the cab height, chunky
WHEEL_W = 0.42
TRUCK_Y = 0.0            # room version: truck centred, the room places it behind the counter spot
CAB_X0, CAB_X1 = -2.75, -1.35
CAB_H = 1.6
BODY_X0, BODY_X1 = -1.30, 2.35
BODY_W = 1.95            # Y depth of cab and box
CHASSIS_Z = TILE_H + WHEEL_R + 0.05
BODY_H = 1.95            # concept: box top ≈ cab top + 0.35
SILL_H = 0.5             # lower side panel under the open bay

def mats():
    m = {}
    def mk(k, n, c, r, met=0.0): m[k] = material(n, c + (1,), r, met)
    mk("sand", "M_Sand", (0.80, 0.68, 0.45), 0.85)
    mk("sand_side", "M_SandSide", (0.72, 0.66, 0.42), 0.85)
    mk("olive", "M_TruckOlive", (0.42, 0.48, 0.28), 0.55)
    mk("olive_dark", "M_TruckOliveDark", (0.30, 0.35, 0.21), 0.6)
    mk("canvas", "M_Canvas", (0.88, 0.80, 0.62), 0.85)
    mk("wood", "M_Wood", (0.58, 0.36, 0.18), 0.65)
    mk("wood_dark", "M_WoodDark", (0.40, 0.25, 0.13), 0.7)
    mk("tyre", "M_Tyre", (0.13, 0.13, 0.14), 0.9)
    mk("metal", "M_MetalPolished", (0.62, 0.64, 0.66), 0.2, 1.0)
    mk("iron", "M_IronDark", (0.28, 0.28, 0.30), 0.35, 1.0)
    mk("glass", "M_Glass", (0.12, 0.14, 0.16), 0.1)
    mk("pine", "M_Pine", (0.42, 0.56, 0.34), 0.8)
    mk("rock", "M_Rock", (0.74, 0.72, 0.75), 0.9)
    mk("sign", "M_SignOlive", (0.36, 0.42, 0.26), 0.7)
    mk("sign_text", "M_SignText", (0.94, 0.90, 0.80), 0.7)
    mk("amber", "M_Amber", (1.0, 0.62, 0.15), 0.4)
    glow = material("M_LanternGlow", (1.0, 0.85, 0.45, 1), 0.3)
    b = glow.node_tree.nodes.get("Principled BSDF")
    if b:
        b.inputs["Emission Color"].default_value = (1.0, 0.75, 0.3, 1)
        b.inputs["Emission Strength"].default_value = 3.0
    m["glow"] = glow
    return m

def soft(ob, w=0.05, seg=2):
    bevel(ob, width=w, segments=seg, angle_limit=40)   # room version: two segments, seen up close
    return ob

def B(name, size, loc, mat, w=0.05, rot=(0, 0, 0)):
    ob = box(name, size, location=loc, rotation=rot)
    assign(ob, mat)
    return soft(ob, w) if w else ob

def tile(m):
    p = cylinder("Tile_Plinth", TILE_R, TILE_H - 0.1, segments=16, location=(0, 0, (TILE_H - 0.1) / 2)); assign(p, m["sand_side"]); soft(p, 0.06)
    t = cylinder("Tile_Top", TILE_R - 0.08, 0.14, segments=16, location=(0, 0, TILE_H - 0.07)); assign(t, m["sand"]); soft(t, 0.05)

def wheel(m, x, y):
    t = cylinder("Truck_Tyre", WHEEL_R, WHEEL_W, axis="Y", segments=12, location=(x, y, TILE_H + WHEEL_R)); assign(t, m["tyre"]); soft(t, 0.08, 2)
    h = cylinder("Truck_Hub", WHEEL_R * 0.38, WHEEL_W + 0.04, axis="Y", segments=10, location=(x, y, TILE_H + WHEEL_R)); assign(h, m["olive"]); soft(h, 0.03)
    c = cylinder("Truck_HubCap", WHEEL_R * 0.18, WHEEL_W + 0.1, axis="Y", segments=8, location=(x, y, TILE_H + WHEEL_R)); assign(c, m["metal"])

def truck(m):
    y = TRUCK_Y; half = BODY_W / 2
    # chassis and fenders
    B("Truck_Chassis", (BODY_X1 - CAB_X0 - 0.2, BODY_W - 0.5, 0.32), ((CAB_X0 + BODY_X1) / 2, y, CHASSIS_Z), m["iron"], 0.04)
    for x in (CAB_X0 + 0.65, BODY_X1 - 0.75):
        for s in (-1, 1):
            wheel(m, x, y + s * (half - 0.12))
            B("Truck_Fender", (1.35, 0.5, 0.18), (x, y + s * (half - 0.12), TILE_H + 2 * WHEEL_R + 0.12), m["olive"], 0.06)
    # cab: squat block with a slanted windscreen, windows, lights, bumper
    cz = CHASSIS_Z + 0.16
    B("Truck_Cab", (CAB_X1 - CAB_X0, BODY_W, CAB_H), ((CAB_X0 + CAB_X1) / 2, y, cz + CAB_H / 2), m["olive"], 0.12)
    B("Truck_CabRoof", (CAB_X1 - CAB_X0 - 0.15, BODY_W - 0.15, 0.12), ((CAB_X0 + CAB_X1) / 2 + 0.05, y, cz + CAB_H + 0.05), m["olive_dark"], 0.05)
    B("Truck_Windscreen", (0.06, BODY_W - 0.45, 0.62), (CAB_X0 - 0.01, y, cz + CAB_H - 0.42), m["glass"], 0.03)
    B("Truck_SideWindow", (0.7, 0.06, 0.55), ((CAB_X0 + CAB_X1) / 2 + 0.05, y - half - 0.01, cz + CAB_H - 0.42), m["glass"], 0.03)
    B("Truck_Grille", (0.06, 0.9, 0.42), (CAB_X0 - 0.02, y, cz + 0.45), m["olive_dark"], 0.03)
    for s in (-1, 1):
        l = cylinder("Truck_Headlight", 0.14, 0.08, axis="X", segments=10, location=(CAB_X0 - 0.03, y + s * (half - 0.3), cz + 0.5)); assign(l, m["amber"])
        mirror_arm = B("Truck_Mirror", (0.08, 0.1, 0.32), (CAB_X0 + 0.25, y + s * (half + 0.08), cz + CAB_H - 0.35), m["iron"], 0.02)
    B("Truck_Bumper", (0.22, BODY_W + 0.1, 0.24), (CAB_X0 - 0.1, y, cz + 0.08), m["metal"], 0.05)
    # box body: floor, back wall, end walls, roof frame, front sill — open bay on the -Y side
    bz = CHASSIS_Z + 0.16
    L = BODY_X1 - BODY_X0; cx = (BODY_X0 + BODY_X1) / 2
    B("Body_Floor", (L, BODY_W, 0.14), (cx, y, bz + 0.07), m["olive_dark"], 0.03)
    B("Body_Back", (L, 0.14, BODY_H), (cx, y + half - 0.07, bz + BODY_H / 2), m["olive"], 0.05)
    for x in (BODY_X0 + 0.08, BODY_X1 - 0.08):
        B("Body_End", (0.16, BODY_W, BODY_H), (x, y, bz + BODY_H / 2), m["olive"], 0.06)
    B("Body_Sill", (L, 0.16, SILL_H), (cx, y - half + 0.08, bz + SILL_H / 2), m["olive"], 0.06)
    for i, x in enumerate((BODY_X0 + 0.5, BODY_X1 - 0.5)):
        r = B("Body_Reflector%d" % i, (0.16, 0.04, 0.08), (x, y - half - 0.01, bz + 0.12), m["amber"], 0.01)
    # wooden bay lining and two shelves
    B("Bay_Lining", (L - 0.36, 0.06, BODY_H - SILL_H - 0.1), (cx, y + half - 0.17, bz + SILL_H + (BODY_H - SILL_H) / 2), m["wood"], 0)
    for i, z in enumerate((bz + SILL_H + 0.05, bz + SILL_H + 0.62)):
        B("Bay_Shelf%d" % i, (L - 0.9, BODY_W - 0.45, 0.08), (cx - 0.25, y + 0.1, z), m["wood"], 0.02)
    B("Bay_Divider", (0.1, BODY_W - 0.45, BODY_H - SILL_H - 0.1), (BODY_X1 - 0.85, y + 0.1, bz + SILL_H + (BODY_H - SILL_H) / 2), m["wood_dark"], 0.02)
    # canvas: puffy roof, rolled-up front edge with two straps, two hanging side flaps
    top = bz + BODY_H
    B("Tarp_Roof", (L + 0.16, BODY_W + 0.16, 0.48), (cx, y, top + 0.18), m["canvas"], 0.16)   # puffier canvas, as the concept
    roll = cylinder("Tarp_Roll", 0.17, L + 0.05, axis="X", segments=10, location=(cx, y - half - 0.05, top - 0.02)); assign(roll, m["canvas"]); soft(roll, 0.03)
    for x in (BODY_X0 + 0.35, BODY_X1 - 0.35):
        s = cylinder("Tarp_Strap", 0.19, 0.08, axis="X", segments=10, location=(x, y - half - 0.05, top - 0.02)); assign(s, m["wood_dark"])
        f = profile_extrude("Tarp_Flap", [(-0.22, 0), (0.22, 0), (0.12, -0.95), (0.0, -1.1), (-0.12, -0.95)], 0.05,
                            location=(x, y - half - 0.12, top - 0.1), rotation=(math.radians(90), 0, 0))
        assign(f, m["canvas"]); soft(f, 0.02)

def goods(m):
    y = TRUCK_Y; half = BODY_W / 2
    bz = CHASSIS_Z + 0.16; s0 = bz + SILL_H + 0.09; s1 = bz + SILL_H + 0.66
    for i, x in enumerate((-0.75, -0.05, 0.65)):            # three helmets on the top shelf
        h = sphere("Goods_Helmet%d" % i, 0.27, location=(x, y - 0.2, s1), u=10, v=6, scale=(1, 1, 0.75)); assign(h, m["olive"])
        r = cylinder("Goods_HelmetRim%d" % i, 0.3, 0.05, segments=10, location=(x, y - 0.2, s1 + 0.02)); assign(r, m["olive_dark"])
    for i, (x, mat) in enumerate(((-0.75, m["olive"]), (-0.05, m["olive"]), (0.65, m["wood"]))):   # ammo boxes below
        B("Goods_Ammo%d" % i, (0.55, 0.42, 0.36), (x, y - 0.15, s0 + 0.18), mat, 0.04)
        B("Goods_AmmoLatch%d" % i, (0.1, 0.03, 0.08), (x, y - 0.37, s0 + 0.24), m["metal"], 0.01)
    rx = BODY_X1 - 0.5                                       # rifle rack in the right bay
    B("Rack_Base", (0.5, 0.35, 0.1), (rx, y - 0.25, s0 + 0.05), m["wood_dark"], 0.02)
    for i, dx in enumerate((-0.11, 0.11)):
        B("Rifle_Stock%d" % i, (0.1, 0.07, 0.42), (rx + dx, y - 0.25, s0 + 0.3), m["wood"], 0.02)
        B("Rifle_Body%d" % i, (0.08, 0.06, 0.36), (rx + dx, y - 0.25, s0 + 0.68), m["iron"], 0.015)
        B("Rifle_Barrel%d" % i, (0.04, 0.04, 0.3), (rx + dx, y - 0.25, s0 + 1.0), m["metal"], 0)

def props(m):
    z = TILE_H
    # The SHOP sign post was removed by the author (2 Oct): the truck alone reads as the shop.
    # folding table with an ammo box and a lantern
    tx, ty = -0.55, -1.55
    B("Table_Top", (1.25, 0.6, 0.1), (tx, ty, z + 0.72), m["wood"], 0.03)
    for s in (-1, 1):
        B("Table_LegA", (0.08, 0.5, 0.75), (tx + s * 0.45, ty, z + 0.36), m["wood_dark"], 0.02, rot=(math.radians(18), 0, 0))
        B("Table_LegB", (0.08, 0.5, 0.75), (tx + s * 0.45, ty, z + 0.36), m["wood_dark"], 0.02, rot=(math.radians(-18), 0, 0))
    B("Table_Ammo", (0.5, 0.3, 0.26), (tx - 0.25, ty, z + 0.9), m["olive"], 0.03)
    lantern(m, tx + 0.3, ty, z + 0.95, small=True)
    # jerrycans, crate, barrel, pine, rock
    for i, (x, y) in enumerate(((0.3, -2.05), (0.7, -1.9))):
        B("Prop_Jerrycan%d" % i, (0.36, 0.2, 0.52), (x, y, z + 0.26), m["olive"], 0.04)
        B("Prop_JerrycanCap%d" % i, (0.12, 0.08, 0.08), (x - 0.08, y, z + 0.56), m["olive_dark"], 0.02)
    B("Prop_Crate", (0.72, 0.72, 0.62), (1.3, -1.85, z + 0.31), m["wood"], 0.05, rot=(0, 0, math.radians(-8)))
    for i, (dx, dz) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        B("Prop_CrateCorner%d" % i, (0.12, 0.76, 0.12), (1.3 + dx * 0.32, -1.85, z + 0.31 + dz * 0.26), m["metal"], 0.02, rot=(0, 0, math.radians(-8)))
    barrel = profile_spin("Prop_Barrel", [(0, 0), (0.33, 0), (0.36, 0.1), (0.37, 0.4), (0.36, 0.7), (0.33, 0.8), (0, 0.8)], steps=12, location=(2.2, -1.35, z))
    assign(barrel, m["metal"])
    for i, h in enumerate((0.25, 0.55)):
        r = cylinder("Prop_BarrelRing%d" % i, 0.385, 0.05, segments=12, location=(2.2, -1.35, z + h)); assign(r, m["iron"])
    tr = cylinder("Prop_PineTrunk", 0.1, 0.35, segments=6, location=(2.75, -0.15, z + 0.17)); assign(tr, m["wood_dark"])   # concept: pine at the right end, beside the box
    for i, (r, zz, h) in enumerate(((0.6, 0.35, 0.75), (0.48, 0.85, 0.7), (0.34, 1.3, 0.65))):
        t = cylinder("Prop_PineTier%d" % i, r, h, segments=7, radius_top=0.05, location=(2.75, -0.15, z + zz + h / 2)); assign(t, m["pine"])
    rk = sphere("Prop_Rock", 0.33, location=(-1.55, -2.35, z + 0.12), u=7, v=5, scale=(1.25, 1.0, 0.75)); assign(rk, m["rock"])

def lantern(m, x, y, z, small=False):
    k = 0.75 if small else 1.0
    cap = cylinder("Lantern_Cap", 0.17 * k, 0.12 * k, segments=6, radius_top=0.05 * k, location=(x, y, z + 0.28 * k)); assign(cap, m["iron"])
    g = cylinder("Lantern_Glass", 0.13 * k, 0.3 * k, segments=6, location=(x, y, z + 0.08 * k)); assign(g, m["glow"])
    b = cylinder("Lantern_Base", 0.16 * k, 0.07 * k, segments=6, location=(x, y, z - 0.1 * k)); assign(b, m["iron"])
    if not small:
        h = cylinder("Lantern_Ring", 0.03, 0.2, segments=6, location=(x, y, z + 0.44)); assign(h, m["iron"])

def open_top(m):
    # Room camera looks from high above: the canvas roof is rolled to the back, steel bows stay, the shelves show.
    for ob in [o for o in bpy.data.objects if o.name.startswith("Tarp_Roof")]:
        bpy.data.objects.remove(ob, do_unlink=True)
    y = TRUCK_Y; half = BODY_W / 2; top = CHASSIS_Z + 0.16 + BODY_H
    L = BODY_X1 - BODY_X0; cx = (BODY_X0 + BODY_X1) / 2
    for i in range(4):
        x = BODY_X0 + 0.2 + i * (L - 0.4) / 3
        B("Bow_Top%d" % i, (0.08, BODY_W + 0.05, 0.08), (x, y, top + 0.32), m["metal"], 0.02)
        for s in (-1, 1):
            B("Bow_Side%d" % i, (0.08, 0.08, 0.36), (x, y + s * half, top + 0.15), m["metal"], 0.02)
    roll = cylinder("Tarp_RolledBack", 0.24, L + 0.1, axis="X", segments=12, location=(cx, y + half - 0.05, top + 0.42)); assign(roll, m["canvas"]); soft(roll, 0.04)
    for x in (BODY_X0 + 0.4, BODY_X1 - 0.4):
        s = cylinder("Tarp_RollStrap", 0.26, 0.1, axis="X", segments=12, location=(x, y + half - 0.05, top + 0.42)); assign(s, m["wood_dark"])


def goods_room(m):
    # Room version (seen up close): fuller shelves — a second row of helmets, more ammo boxes, grenades, a radio,
    # crates on the sill and a hanging lantern in the bay.
    goods(m)
    y = TRUCK_Y; bz = CHASSIS_Z + 0.16; s0 = bz + SILL_H + 0.09; s1 = bz + SILL_H + 0.66
    for i, x in enumerate((-0.4, 0.3)):
        h = sphere("Goods_HelmetBack%d" % i, 0.25, location=(x, y + 0.25, s1), u=10, v=6, scale=(1, 1, 0.75)); assign(h, m["olive_dark"])
    for i, x in enumerate((-0.4, 0.3)):
        B("Goods_AmmoBack%d" % i, (0.5, 0.38, 0.32), (x, y + 0.3, s0 + 0.16), m["olive_dark"], 0.03)
    for i, x in enumerate((-1.05, -0.95, -0.85)):
        g = sphere("Goods_Grenade%d" % i, 0.07, location=(x - 0.1, y - 0.35, s1 + 0.0), u=8, v=6, scale=(1, 1, 1.25)); assign(g, m["olive"])
        c = cylinder("Goods_GrenadeCap%d" % i, 0.03, 0.05, segments=6, location=(x - 0.1, y - 0.35, s1 + 0.1)); assign(c, m["metal"])
    B("Goods_Radio", (0.38, 0.22, 0.26), (0.65, y + 0.2, s1 + 0.1), m["olive_dark"], 0.03)
    B("Goods_RadioDial", (0.1, 0.03, 0.1), (0.6, y + 0.08, s1 + 0.12), m["metal"], 0.01)
    c = cylinder("Goods_RadioAntenna", 0.012, 0.4, segments=6, location=(0.78, y + 0.2, s1 + 0.42)); assign(c, m["metal"])
    sill = bz + SILL_H + 0.02
    for i, (x, w) in enumerate(((-1.0, 0.5), (1.2, 0.45))):
        B("Sill_Crate%d" % i, (w, 0.42, 0.3), (x, y - BODY_W / 2 - 0.05, sill + 0.15), m["wood"], 0.03)
    lantern(m, -0.1, y - 0.2, bz + BODY_H - 0.2, small=True)

def build(scene, args):
    scene.view_settings.view_transform = "Standard"
    m = mats()
    truck(m); open_top(m); goods_room(m)
    log("built", len([o for o in bpy.data.objects if o.get("owner") == OWNER_TAG]), "objects")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--master", required=True)
    a = p.parse_args(argv_after_dashes())
    scene = open_master(a.master)
    clear_owned()
    build(scene, a)
    save_master(a.master)
    log("saved", a.master)
