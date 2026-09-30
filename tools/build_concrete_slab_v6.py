"""Second indestructible concrete family (replaces the plain slab): a heavy block on a
recessed plinth, so a dark shadow gap runs round the bottom, plus a shallow groove band.

Run: Blender -b -P tools/build_concrete_slab_v6.py
Writes assets/models/concrete_v1/concrete_smooth.glb and concrete_smooth_half_0..7.glb.
Same quadrant shapes and 0.96 box as tools/build_concrete_fence.py (collision sections
are unchanged: the plinth inset only removes a sliver of the bottom 0.13).
"""
import os, bpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "models", "concrete_v1")
E, H = .48, .96
GAP_H, GAP_IN = .13, .075        # plinth height and inset: the visible gap under the block
GROOVE = (.52, .56, .018)        # band from .. to, depth
UP = (0.0, 1.0, 0.0)
ALL = {(0, 0), (1, 0), (0, 1), (1, 1)}
SHAPES = {"": ALL, "_half_0": {(0, 0), (0, 1)}, "_half_1": {(1, 0), (1, 1)}, "_half_2": {(0, 0), (1, 0)},
          "_half_3": {(0, 1), (1, 1)}, "_half_4": ALL - {(1, 1)}, "_half_5": ALL - {(0, 1)},
          "_half_6": ALL - {(0, 0)}, "_half_7": ALL - {(1, 0)}}

add = lambda a, b: tuple(x + y for x, y in zip(a, b))
mul = lambda a, s: tuple(x * s for x in a)
sub = lambda a, b: tuple(x - y for x, y in zip(a, b))
dot = lambda a, b: sum(x * y for x, y in zip(a, b))
cross = lambda a, b: (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


class Builder:
    def __init__(self): self.verts, self.faces = [], []
    def poly(self, pts, expected):
        n = cross(sub(pts[1], pts[0]), sub(pts[2], pts[0]))
        if dot(n, expected) < 0: pts = list(reversed(pts))
        s = len(self.verts); self.verts.extend(pts); self.faces.append(tuple(range(s, s + len(pts))))


def side(b, normal, plane, lo, hi, outer):
    """Vertical face above the plinth; outer faces get a groove band and the overhang underside."""
    right = cross(UP, normal)
    sign = sum(right)
    u0, u1 = sorted((lo * sign, hi * sign))
    p = lambda u, v, d=0.0: add(add(mul(normal, plane - d), mul(right, u)), mul(UP, v))
    if not outer:
        b.poly([p(u0, GAP_H), p(u1, GAP_H), p(u1, H), p(u0, H)], normal); return
    g0, g1, gd = GROOVE
    for v0, v1, d in ((GAP_H, g0, 0), (g0, g1, gd), (g1, H, 0)):
        b.poly([p(u0, v0, d), p(u1, v0, d), p(u1, v1, d), p(u0, v1, d)], normal)
    for v in (g0, g1):
        b.poly([p(u0, v, 0), p(u1, v, 0), p(u1, v, gd), p(u0, v, gd)], (0, 1 if v == g0 else -1, 0))
    b.poly([p(u0, GAP_H, 0), p(u1, GAP_H, 0), p(u1, GAP_H, GAP_IN), p(u0, GAP_H, GAP_IN)], (0, -1, 0))


def build(quads):
    b = Builder()
    for qx, qz in quads:
        x0, x1 = (-E, 0.0) if qx == 0 else (0.0, E)
        z0, z1 = (-E, 0.0) if qz == 0 else (0.0, E)
        out = lambda dx, dz: (qx + dx, qz + dz) not in quads
        b.poly([(x0, H, z0), (x1, H, z0), (x1, H, z1), (x0, H, z1)], UP)
        px0 = x0 + (GAP_IN if out(-1, 0) else 0); px1 = x1 - (GAP_IN if out(1, 0) else 0)
        pz0 = z0 + (GAP_IN if out(0, -1) else 0); pz1 = z1 - (GAP_IN if out(0, 1) else 0)
        b.poly([(px0, 0, pz0), (px1, 0, pz0), (px1, 0, pz1), (px0, 0, pz1)], (0, -1, 0))
        # recessed plinth sides (only where the block is exposed); inner joins stay open
        if out(1, 0): b.poly([(px1, 0, pz0), (px1, 0, pz1), (px1, GAP_H, pz1), (px1, GAP_H, pz0)], (1, 0, 0))
        if out(-1, 0): b.poly([(px0, 0, pz0), (px0, 0, pz1), (px0, GAP_H, pz1), (px0, GAP_H, pz0)], (-1, 0, 0))
        if out(0, 1): b.poly([(px0, 0, pz1), (px1, 0, pz1), (px1, GAP_H, pz1), (px0, GAP_H, pz1)], (0, 0, 1))
        if out(0, -1): b.poly([(px0, 0, pz0), (px1, 0, pz0), (px1, GAP_H, pz0), (px0, GAP_H, pz0)], (0, 0, -1))
        # overhang underside also fills the corner where two exposed sides meet
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if not out(dx, dz): continue
            normal = (float(dx), 0.0, float(dz))
            if dx: side(b, normal, (x1 if dx > 0 else x0) * dx, z0, z1, True)
            else: side(b, normal, (z1 if dz > 0 else z0) * dz, x0, x1, True)
    return b


def material():
    mat = bpy.data.materials.get("ENV7_concrete") or bpy.data.materials.new("ENV7_concrete")
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.29, 0.31, 0.27, 1); bsdf.inputs["Roughness"].default_value = .9
    return mat


def export(name, b, mat):
    for ob in list(bpy.data.objects): bpy.data.objects.remove(ob, do_unlink=True)
    verts = [(x, -z, y) for x, y, z in b.verts]      # Godot (x,y,z) -> Blender (x,-z,y)
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], b.faces); me.materials.append(mat); me.update()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=True, export_apply=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
mat = material()
for suffix, quads in SHAPES.items():
    export("concrete_smooth" + suffix, build(quads), mat)
print("CONCRETE SLAB 9 shapes")
