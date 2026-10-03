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

PHASE = "03_forms"
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

# Shared look for the route stops (same palette and tile as the merchant truck, art_requests/merchant_point_v2).
TILE_R = 3.15
TILE_H = 0.36            # common tile thickness: base() plinth -.08 + tile .28; placed at y -0.08 in game

def mats():
    m = {}
    def mk(k, n, c, r, met=0.0): m[k] = material(n, c + (1,), r, met)
    mk("sand", "M_Sand", (0.80, 0.68, 0.45), 0.85)
    mk("sand_side", "M_SandSide", (0.72, 0.66, 0.42), 0.85)
    mk("olive", "M_Olive", (0.42, 0.48, 0.28), 0.55)
    mk("olive_dark", "M_OliveDark", (0.30, 0.35, 0.21), 0.6)
    mk("canvas", "M_Canvas", (0.88, 0.80, 0.62), 0.85)
    mk("wood", "M_Wood", (0.58, 0.36, 0.18), 0.65)
    mk("wood_dark", "M_WoodDark", (0.40, 0.25, 0.13), 0.7)
    mk("tyre", "M_Tyre", (0.13, 0.13, 0.14), 0.9)
    mk("metal", "M_MetalPolished", (0.62, 0.64, 0.66), 0.2, 1.0)
    mk("iron", "M_IronDark", (0.28, 0.28, 0.30), 0.35, 1.0)
    mk("glass", "M_Glass", (0.12, 0.14, 0.16), 0.1)
    mk("pine", "M_Pine", (0.42, 0.56, 0.34), 0.8)
    mk("rock", "M_Rock", (0.74, 0.72, 0.75), 0.9)
    mk("amber", "M_Amber", (1.0, 0.62, 0.15), 0.4)
    mk("bag", "M_Sandbag", (0.80, 0.70, 0.52), 0.9)
    mk("board", "M_Chalkboard", (0.20, 0.27, 0.24), 0.8)
    mk("white", "M_Chalk", (0.92, 0.92, 0.88), 0.8)
    mk("cream", "M_Cream", (0.93, 0.82, 0.62), 0.7)
    mk("black", "M_Black", (0.08, 0.08, 0.09), 0.6)
    mk("orange", "M_OrangePaint", (0.93, 0.36, 0.10), 0.45)
    mk("yellow", "M_YellowPaint", (0.98, 0.70, 0.12), 0.45)
    mk("red", "M_RedPaint", (0.82, 0.22, 0.16), 0.5)
    mk("concrete", "M_Concrete", (0.38, 0.38, 0.40), 0.8)
    mk("gold", "M_Gold", (1.0, 0.76, 0.25), 0.2, 1.0)
    glow = material("M_Glow", (1.0, 0.85, 0.45, 1), 0.3)
    b = glow.node_tree.nodes.get("Principled BSDF")
    if b:
        b.inputs["Emission Color"].default_value = (1.0, 0.75, 0.3, 1)
        b.inputs["Emission Strength"].default_value = 3.0
    m["glow"] = glow
    return m

def soft(ob, w=0.05, seg=1):
    bevel(ob, width=w, segments=seg, angle_limit=40)   # one segment: soft look, light mesh for the map
    return ob

def B(name, size, loc, mat, w=0.05, rot=(0, 0, 0)):
    ob = box(name, size, location=loc, rotation=rot)
    assign(ob, mat)
    return soft(ob, w) if w else ob

def C(name, r, h, loc, mat, seg=10, axis="Z", top=None, w=0.0):
    ob = cylinder(name, r, h, segments=seg, axis=axis, radius_top=top, location=loc)
    assign(ob, mat)
    return soft(ob, w) if w else ob

def tile(m):
    C("Tile_Plinth", TILE_R, TILE_H - 0.1, (0, 0, (TILE_H - 0.1) / 2), m["sand_side"], 16, w=0.06)
    C("Tile_Top", TILE_R - 0.08, 0.14, (0, 0, TILE_H - 0.07), m["sand"], 16, w=0.05)

def pine(m, x, y, s=1.0):
    z = TILE_H
    C("Pine_Trunk", 0.1 * s, 0.35 * s, (x, y, z + 0.17 * s), m["wood_dark"], 6)
    for i, (r, zz, h) in enumerate(((0.6, 0.35, 0.75), (0.48, 0.85, 0.7), (0.34, 1.3, 0.65))):
        C("Pine_Tier%d" % i, r * s, h * s, (x, y, z + (zz + h / 2) * s), m["pine"], 7, top=0.05 * s)

def sandbag_arc(m, cx, cy, radius, a0, a1, count, rows=2):
    for row in range(rows):
        n = count - row
        for i in range(n):
            t = (i + 0.5 + row * 0.5) / count
            a = math.radians(a0 + (a1 - a0) * t)
            x, y = cx + radius * math.cos(a), cy + radius * math.sin(a)
            B("Sandbag", (0.78, 0.44, 0.3), (x, y, TILE_H + 0.15 + row * 0.28), m["bag"], 0.1, rot=(0, 0, a + math.pi / 2))

def run_build(build_fn):
    p = argparse.ArgumentParser()
    p.add_argument("--master", required=True)
    a = p.parse_args(argv_after_dashes())
    scene = open_master(a.master)
    clear_owned()
    scene.view_settings.view_transform = "Standard"
    build_fn(scene, mats())
    save_master(a.master)
    log("built", len([o for o in bpy.data.objects if o.get("owner") == OWNER_TAG]), "objects")

# Mechanic stop (vehicle repair). Faces -Y. Measured from mechanic/ref/parts.png and concept_simple.png.
WR = 0.58                 # truck wheel radius (parts sheet: ≈ half the cab height)
TY = 0.75                 # truck on the back half
CAB_X0, CAB_X1, BED_X1 = -2.6, -1.3, 1.25
TW = 1.75                 # truck width (Y)

def wheel(m, x, y, r, w, name="Wheel"):
    C(name + "_Tyre", r, w, (x, y, TILE_H + r), m["tyre"], 12, axis="Y", w=0.06)
    C(name + "_Hub", r * 0.42, w + 0.04, (x, y, TILE_H + r), m["olive"], 10, axis="Y", w=0.02)
    C(name + "_Cap", r * 0.15, w + 0.1, (x, y, TILE_H + r), m["metal"], 8, axis="Y")

def truck(m):
    z = TILE_H; cz = z + WR + 0.2; half = TW / 2
    B("Truck_Chassis", (BED_X1 - CAB_X0, TW - 0.5, 0.3), ((CAB_X0 + BED_X1) / 2, TY, z + WR + 0.05), m["iron"], 0.04)
    for x in (CAB_X0 + 0.65, BED_X1 - 0.6):
        for s in (-1, 1):
            wheel(m, x, TY + s * (half - 0.15), WR, 0.4, "Truck_Wheel")
    B("Truck_Cab", (CAB_X1 - CAB_X0, TW, 1.55), ((CAB_X0 + CAB_X1) / 2, TY, cz + 0.78), m["olive"], 0.12)
    B("Truck_Windscreen", (0.06, TW - 0.4, 0.55), (CAB_X0 - 0.01, TY, cz + 1.18), m["glass"], 0.03)
    B("Truck_SideWindow", (0.65, 0.06, 0.5), ((CAB_X0 + CAB_X1) / 2 + 0.05, TY - half - 0.01, cz + 1.18), m["glass"], 0.03)
    B("Truck_Grille", (0.06, 0.85, 0.4), (CAB_X0 - 0.02, TY, cz + 0.45), m["olive_dark"], 0.03)
    for s in (-1, 1):
        C("Truck_Headlight", 0.13, 0.08, (CAB_X0 - 0.03, TY + s * (half - 0.3), cz + 0.5), m["amber"], 10, axis="X")
    for i in range(3):
        B("Truck_RoofLight%d" % i, (0.12, 0.16, 0.08), (CAB_X0 + 0.35, TY - 0.35 + i * 0.35, cz + 1.6), m["amber"], 0.02)
    B("Truck_Bumper", (0.22, TW + 0.1, 0.24), (CAB_X0 - 0.1, TY, cz + 0.1), m["metal"], 0.05)
    bz = cz + 0.05
    B("Bed_Floor", (BED_X1 - CAB_X1 - 0.05, TW, 0.16), ((CAB_X1 + BED_X1) / 2 + 0.02, TY, bz), m["olive_dark"], 0.03)
    for s in (-1, 1):
        B("Bed_Side", (BED_X1 - CAB_X1 - 0.05, 0.1, 0.38), ((CAB_X1 + BED_X1) / 2 + 0.02, TY + s * (half - 0.05), bz + 0.26), m["olive"], 0.03)
    B("Bed_Tail", (0.1, TW, 0.38), (BED_X1 - 0.05, TY, bz + 0.26), m["olive"], 0.03)
    B("Bed_Canvas", (1.05, TW - 0.2, 0.8), (CAB_X1 + 0.6, TY, bz + 0.5), m["canvas"], 0.14)
    B("Bed_RedCan", (0.25, 0.08, 0.3), (CAB_X1 + 0.45, TY - half - 0.02, bz + 0.2), m["red"], 0.03)

def crane(m):
    bx, by = BED_X1 - 0.45, TY - 0.1
    bz = TILE_H + WR + 0.33
    C("Crane_Turret", 0.32, 0.3, (bx, by, bz + 0.15), m["iron"], 10, w=0.03)
    B("Crane_Mast", (0.34, 0.34, 1.6), (bx, by, bz + 1.1), m["yellow"], 0.06)
    # boom from the mast top out to the right-front, over the buggy
    tip = Vector((bx + 1.25, by - 0.55, bz + 2.55))   # concept: boom rises to the right, engine hangs beside the buggy
    root = Vector((bx, by, bz + 1.85))
    d = tip - root
    boom = box("Crane_Boom", (d.length, 0.24, 0.24), location=(root + tip) / 2)
    boom.rotation_euler = d.to_track_quat("X", "Z").to_euler()
    assign(boom, m["yellow"]); soft(boom, 0.05)
    C("Crane_Pin", 0.1, 0.36, tuple(root), m["iron"], 8, axis="Y")
    C("Crane_Chain", 0.03, 0.55, (tip.x, tip.y, tip.z - 0.3), m["iron"], 6)
    B("Crane_Hook", (0.14, 0.08, 0.14), (tip.x, tip.y, tip.z - 0.62), m["metal"], 0.02)
    ez = tip.z - 1.02
    B("Engine_Block", (0.6, 0.45, 0.42), (tip.x, tip.y, ez), m["olive_dark"], 0.05)
    for i in range(3):
        B("Engine_Fin%d" % i, (0.62, 0.48, 0.04), (tip.x, tip.y, ez + 0.08 + i * 0.1 - 0.1), m["metal"], 0.01)

def buggy(m):
    x, y = 0.75, -1.2; z = TILE_H + 0.35          # raised on the jack stands; concept: big, front-centre
    r = 0.42
    for dx in (-0.72, 0.72):
        for s in (-1, 1):
            C("Buggy_Tyre", r, 0.32, (x + dx, y + s * 0.64, z + r - 0.05), m["tyre"], 10, axis="Y", w=0.05)
            C("Buggy_Hub", r * 0.45, 0.36, (x + dx, y + s * 0.64, z + r - 0.05), m["olive"], 8, axis="Y")
    B("Buggy_Body", (1.8, 1.05, 0.44), (x, y, z + 0.68), m["olive"], 0.08)
    B("Buggy_Nose", (0.45, 0.95, 0.34), (x - 1.05, y, z + 0.6), m["olive"], 0.08)
    for s in (-1, 1):
        C("Buggy_Light", 0.09, 0.06, (x - 1.29, y + s * 0.25, z + 0.6), m["amber"], 8, axis="X")
        B("Buggy_CagePost", (0.07, 0.07, 0.6), (x - 0.25, y + s * 0.38, z + 1.1), m["iron"], 0.015)
        B("Buggy_CagePostB", (0.07, 0.07, 0.6), (x + 0.45, y + s * 0.38, z + 1.1), m["iron"], 0.015)
        B("Buggy_CageRail", (0.75, 0.07, 0.07), (x + 0.1, y + s * 0.38, z + 1.4), m["iron"], 0.015)
    B("Buggy_CageTop", (0.07, 0.83, 0.07), (x - 0.25, y, z + 1.4), m["iron"], 0.015)
    B("Buggy_Seat", (0.35, 0.6, 0.3), (x + 0.2, y, z + 0.92), m["olive_dark"], 0.05)
    for dx in (-0.7, 0.7):
        B("Jack_Base", (0.4, 0.4, 0.06), (x + dx, y, TILE_H + 0.03), m["iron"], 0.02)
        C("Jack_Leg", 0.16, 0.38, (x + dx, y, TILE_H + 0.22), m["orange"], 4, top=0.05)

def toolchest(m):
    x, y = -1.55, -1.45; z = TILE_H
    B("Tool_Chest", (0.85, 0.55, 0.8), (x, y, z + 0.48), m["red"], 0.05)
    for i in range(4):
        B("Tool_Drawer%d" % i, (0.7, 0.04, 0.12), (x, y - 0.28, z + 0.3 + i * 0.16), m["metal"], 0.01)
    for dx in (-0.35, 0.35):
        C("Tool_Caster", 0.06, 0.06, (x + dx, y, z + 0.05), m["black"], 8, axis="Y")
    B("Tool_Wrench", (0.5, 0.1, 0.04), (x, y, z + 0.9), m["metal"], 0.01)

def build(scene, m):
    tile(m); truck(m); crane(m); buggy(m); toolchest(m)

run_build(build)
