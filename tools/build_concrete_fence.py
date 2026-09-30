"""Soviet PO-2 fence relief for indestructible concrete blocks.

Run: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/build_concrete_fence.py
Writes assets/models/concrete_v1/concrete_0.glb and concrete_0_half_0..7.glb.

Scale matches the previous relief: 2 columns x 2 rows per 0.96 face, 0.09 margin.
The panel inside the frame is recessed; each cell is a faceted PO-2 figure rising
from it almost to the frame: a plateau shifted to the upper left, short steep slopes
on the top/left and long gentle slopes to the right/bottom. Nothing leaves the 0.96 box.
Half shapes are real cuts: cut faces stay plain, outer faces keep the relief scale.
"""
import os
import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "models", "concrete_v1")
E = 0.48          # half extent
H = 0.96          # height
M = 0.09          # outer margin
G = 0.02          # rib between cells
D = 0.055         # panel recess below the frame
P = 0.008         # plateau depth below the frame
UP = (0.0, 1.0, 0.0)

ALL = {(0, 0), (1, 0), (0, 1), (1, 1)}
SHAPES = {
    "": ALL,
    "_half_0": {(0, 0), (0, 1)},
    "_half_1": {(1, 0), (1, 1)},
    "_half_2": {(0, 0), (1, 0)},
    "_half_3": {(0, 1), (1, 1)},
    "_half_4": ALL - {(1, 1)},
    "_half_5": ALL - {(0, 1)},
    "_half_6": ALL - {(0, 0)},
    "_half_7": ALL - {(1, 0)},
}


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def mul(a, s):
    return tuple(x * s for x in a)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


class Builder:
    def __init__(self):
        self.verts = []
        self.faces = []

    def poly(self, points, expected):
        normal = cross(sub(points[1], points[0]), sub(points[2], points[0]))
        if dot(normal, expected) < 0:
            points = list(reversed(points))
        start = len(self.verts)
        self.verts.extend(points)
        self.faces.append(tuple(range(start, start + len(points))))


def rows():
    h = (H - 2 * M - G) / 2
    return [(M, M + h), (M + h + G, H - M)]


def columns():
    w = (2 * E - 2 * M - G) / 2
    return [(-E + M, -E + M + w), (E - M - w, E - M)]


def face(builder, normal, plane, lo, hi, relief):
    """Wall segment on plane normal*plane, spanning world-axis [lo, hi] along the face."""
    right = cross(UP, normal)
    axis_sign = sum(right)  # right is a unit axis vector: +1 or -1
    # Segment and cells in u-space (u grows to the viewer's right).
    u_lo, u_hi = sorted((lo * axis_sign, hi * axis_sign))
    cells = []
    if relief:
        for c0, c1 in columns():
            a, b = sorted((c0 * axis_sign, c1 * axis_sign))
            if a >= u_lo - 1e-6 and b <= u_hi + 1e-6:
                for v0, v1 in rows():
                    cells.append((a, b, v0, v1))

    def point(u, v, depth=0.0):
        return add(add(mul(normal, plane - depth), mul(right, u)), mul(UP, v))

    us = sorted({u_lo, u_hi} | {c[0] for c in cells} | {c[1] for c in cells})
    vs = sorted({0.0, H} | {c[2] for c in cells} | {c[3] for c in cells})
    for i in range(len(us) - 1):
        for j in range(len(vs) - 1):
            cu = (us[i] + us[i + 1]) / 2
            cv = (vs[j] + vs[j + 1]) / 2
            if any(c[0] < cu < c[1] and c[2] < cv < c[3] for c in cells):
                continue
            builder.poly([point(us[i], vs[j]), point(us[i + 1], vs[j]), point(us[i + 1], vs[j + 1]), point(us[i], vs[j + 1])], normal)
    for u0, u1, v0, v1 in cells:
        w = u1 - u0
        h = v1 - v0
        p0, p1 = u0 + 0.018, u1 - 0.5 * w
        q0, q1 = v0 + 0.45 * h, v1 - 0.018
        edge = [point(u0, v0), point(u1, v0), point(u1, v1), point(u0, v1)]
        rim = [point(u0, v0, D), point(u1, v0, D), point(u1, v1, D), point(u0, v1, D)]
        top = [point(p0, q0, P), point(p1, q0, P), point(p1, q1, P), point(p0, q1, P)]
        builder.poly(top, normal)
        centre = point((u0 + u1) / 2, (v0 + v1) / 2, D)
        for k in range(4):
            builder.poly([rim[k], rim[(k + 1) % 4], top[(k + 1) % 4], top[k]], normal)
            # Pocket wall from the frame down to the recessed panel, facing the cell centre.
            mid = mul(add(edge[k], edge[(k + 1) % 4]), 0.5)
            builder.poly([edge[k], edge[(k + 1) % 4], rim[(k + 1) % 4], rim[k]], sub(centre, mid))


def build(quadrants):
    builder = Builder()
    for qx, qz in quadrants:
        x0, x1 = (-E, 0.0) if qx == 0 else (0.0, E)
        z0, z1 = (-E, 0.0) if qz == 0 else (0.0, E)
        builder.poly([(x0, H, z0), (x1, H, z0), (x1, H, z1), (x0, H, z1)], UP)
        builder.poly([(x0, 0, z0), (x1, 0, z0), (x1, 0, z1), (x0, 0, z1)], (0, -1, 0))
        for dx, dz in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
            nx, nz = qx + dx, qz + dz
            outer = not (0 <= nx <= 1 and 0 <= nz <= 1)
            if not outer and (nx, nz) in quadrants:
                continue
            normal = (float(dx), 0.0, float(dz))
            if dx:
                plane = (x1 if dx > 0 else x0) * dx
                face(builder, normal, plane, z0, z1, outer)
            else:
                plane = (z1 if dz > 0 else z0) * dz
                face(builder, normal, plane, x0, x1, outer)
    return builder


def material():
    mat = bpy.data.materials.get("ENV7_concrete") or bpy.data.materials.new("ENV7_concrete")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.29, 0.31, 0.27, 1)
        bsdf.inputs["Roughness"].default_value = 0.9
    return mat


def export(name, builder, mat):
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    # Godot (x, y, z) -> Blender (x, -z, y); the glTF exporter converts back to +Y up.
    verts = [(x, -z, y) for x, y, z in builder.verts]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], builder.faces)
    mesh.materials.append(mat)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=True, export_apply=True)


def main():
    mat = material()
    for suffix, quadrants in SHAPES.items():
        export("concrete_0" + suffix, build(quadrants), mat)


main()
