"""Shared low-poly kit for the v6 art pass (infantry, weapons, vehicles, props).

One palette texture per asset family: every part gets flat UVs at a colour
cell, so a whole model is one or two surfaces. Softness comes from chamfers
and smooth shading, not from polygons. Authored +Y forward, Z up, metres.
"""
import bpy, bmesh, math, json, os
from mathutils import Vector, Matrix

D = math.radians
CELL = 4

# One colour language for every v6 model. Runtime code may swap camo/fur cells.
PALETTE = {
    "camo_a": "5d6147", "camo_b": "525840", "camo_c": "6a694b",      # friendly woodland
    "vest": "4a5039", "pouch": "545a41", "black": "232323", "strap": "2e2f2c",
    "band": "e0692a", "sole": "3a3a38",
    "fur": "d9853b", "fur_dark": "a45a22", "muzzle": "efe6d6", "nose": "c9736f", "ear_inner": "e3a39a",
    "lamp": "fff1c9",
    "gun": "2f3236", "gun_light": "4a4e52", "furniture": "5f6448", "hull": "7a8062",
    "hull_light": "b9b39c", "hull_dark": "4f5443", "rubber": "262626", "glass": "9fb6bd",
    "canvas": "7d7a5f", "canvas_dark": "5f5d48", "concrete": "9a9d93", "concrete_dark": "74786f",
    "stone": "a8a79c", "wood": "7a5a3c", "flag": "c8452f", "gold": "c9a24a",
    "bronze": "7b8a6e", "marble": "cfcabb", "steel": "9aa1a4", "hazard": "e3b23c", "tarp": "6b6e52", "tarp_dark": "55583f",
    "screen": "6fd8e0", "screen_amber": "f2b74a", "glow_red": "ff4a3a", "desk": "c4bfae",
}
EMISSIVE = {"lamp": "fff1c9", "screen": "5fc8d2", "screen_amber": "e8a53a", "glow_red": "ff3a2a"}
NAMES = list(PALETTE)


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4 for x in c)


def write_palette_json(path):
    with open(path, "w") as f:
        json.dump({"cell": CELL, "names": NAMES, "colors": PALETTE, "emissive": EMISSIVE}, f, indent=1)


class Kit:
    """Builds parts into PARTS; `mat` is a palette cell name or a named special material."""

    def __init__(self, scene, material_name="V6_palette_fabric", emissive=True, soft=True, share=None):
        self.scene = scene
        self.soft = soft  # False: chamfers exactly as given (hard-surface: guns, vehicles)
        self.parts = []
        # share=another Kit: reuse its palette and special materials (one model, several nodes).
        self.special = share.special if share else {}
        self.pal = share.pal if share else self._palette_material(material_name, emissive)

    # ---------------------------------------------------------- materials
    def material(self, name, color_hex, rough=.8, metallic=0.0, emission=None):
        m = bpy.data.materials.new(name)
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*srgb(color_hex), 1)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metallic
        if emission:
            bsdf.inputs["Emission Color"].default_value = (*srgb(emission[0]), 1)
            bsdf.inputs["Emission Strength"].default_value = emission[1]
        return m

    def add_special(self, key, mat):
        self.special[key] = mat
        return mat

    def _image(self, name, pick):
        w = CELL * len(NAMES)
        img = bpy.data.images.new(name, w, CELL)
        px = []
        for _y in range(CELL):
            for n in NAMES:
                h = pick(n)
                px += [int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255, 1] * CELL
        img.pixels = px
        img.pack()
        return img

    def _palette_material(self, name, emissive):
        m = bpy.data.materials.new(name)
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = self._image(name + "_albedo", lambda n: PALETTE[n]); tex.interpolation = 'Closest'
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = .85
        if emissive:
            etex = nt.nodes.new("ShaderNodeTexImage")
            etex.image = self._image(name + "_emission", lambda n: EMISSIVE.get(n, "000000")); etex.interpolation = 'Closest'
            nt.links.new(etex.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 2.5
        return m

    @staticmethod
    def cell_uv(name):
        return ((NAMES.index(name) * CELL + CELL / 2) / (CELL * len(NAMES)), .5)

    # ---------------------------------------------------------- core
    def finish(self, bm, name, mat, bone=None, smooth=80, face_cell=None):
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new(name, me)
        self.scene.collection.objects.link(ob)
        me.materials.append(self.special.get(mat, self.pal))
        uv = me.uv_layers.new(name="UVMap").data
        for p in me.polygons:
            cell = face_cell(p) if face_cell else None
            u = self.cell_uv(cell or (mat if mat in PALETTE else "black"))
            for li in p.loop_indices: uv[li].uv = u
            p.use_smooth = True
        me.set_sharp_from_angle(angle=D(smooth))
        self.parts.append((ob, bone))
        return ob

    def rbox(self, name, center, size, mat, bone=None, bevel=.03, seg=1, smooth=75, face_cell=None, rot=None):
        """Chamfered box; smooth shading makes it read as soft fabric / moulded plastic."""
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1)
        bmesh.ops.scale(bm, vec=size, verts=bm.verts)
        b = min(max(bevel * 1.7, min(size) * .3), min(size) * .48) if self.soft else min(bevel, min(size) * .45)
        if b > .0005:
            bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=b, segments=seg, affect='EDGES', profile=.5)
        if rot: bmesh.ops.rotate(bm, matrix=rot, verts=bm.verts)
        bmesh.ops.translate(bm, vec=center, verts=bm.verts)
        return self.finish(bm, name, mat, bone, smooth, face_cell)

    def ellipsoid(self, name, center, radii, mat, bone=None, seg=8, rings=5, smooth=80, face_cell=None):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1)
        bmesh.ops.scale(bm, vec=radii, verts=bm.verts)
        bmesh.ops.translate(bm, vec=center, verts=bm.verts)
        return self.finish(bm, name, mat, bone, smooth, face_cell)

    def cylinder(self, name, a, b, radius, mat, bone=None, sides=8, radius_b=None, caps=True, smooth=40, face_cell=None):
        """Straight cylinder / cone between points a and b."""
        a, b = Vector(a), Vector(b)
        d = (b - a).normalized()
        side = d.cross(Vector((0, 0, 1)))
        if side.length < .1: side = d.cross(Vector((1, 0, 0)))
        side.normalize(); up = side.cross(d).normalized()
        rb = radius if radius_b is None else radius_b
        bm = bmesh.new()
        ra = [bm.verts.new(a + (side * math.cos(t) + up * math.sin(t)) * radius) for t in (2 * math.pi * k / sides for k in range(sides))]
        rr = [bm.verts.new(b + (side * math.cos(t) + up * math.sin(t)) * rb) for t in (2 * math.pi * k / sides for k in range(sides))]
        for k in range(sides): bm.faces.new((ra[k], ra[(k + 1) % sides], rr[(k + 1) % sides], rr[k]))
        if caps:
            bm.faces.new(ra[::-1]); bm.faces.new(rr)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return self.finish(bm, name, mat, bone, smooth, face_cell)

    def tube(self, name, points, radii, mat, bones=None, sides=6, smooth=80, face_cell=None, caps=True):
        """Tapered capped tube through points (limbs, tails)."""
        bm = bmesh.new()
        pts = [Vector(p) for p in points]
        rings = []
        for i, (p, r) in enumerate(zip(pts, radii)):
            d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            side = d.cross(Vector((0, 1, 0)))
            if side.length < .1: side = d.cross(Vector((1, 0, 0)))
            side.normalize(); up = side.cross(d).normalized()
            rings.append([bm.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * r)
                          for a in (2 * math.pi * k / sides for k in range(sides))])
        for a, b in zip(rings, rings[1:]):
            for k in range(sides):
                bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
        if caps:
            for ring, tip in ((rings[0], pts[0] - (pts[1] - pts[0]).normalized() * radii[0] * .5),
                              (rings[-1], pts[-1] + (pts[-1] - pts[-2]).normalized() * radii[-1] * .5)):
                c = bm.verts.new(tip)
                for k in range(sides): bm.faces.new((ring[k], ring[(k + 1) % sides], c))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return self.finish(bm, name, mat, bones, smooth, face_cell)

    def band(self, name, center, radius, height, mat, bone=None, axis=(0, 0, 1), sides=8, scale_y=1.0, skip=None):
        """Open cylinder band: one quad per side. skip(center) drops hidden quads."""
        bm = bmesh.new()
        lo, hi = [], []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            x, y = radius * math.sin(a), radius * math.cos(a) * scale_y
            lo.append(bm.verts.new((x, y, -height / 2))); hi.append(bm.verts.new((x * 1.02, y * 1.02, height / 2)))
        for k in range(sides):
            bm.faces.new((lo[k], lo[(k + 1) % sides], hi[(k + 1) % sides], hi[k]))
        for f in bm.faces:
            if f.normal.dot(f.calc_center_median() * Vector((1, 1, 0))) < 0: f.normal_flip()
        if skip: bmesh.ops.delete(bm, geom=[f for f in bm.faces if skip(f.calc_center_median())], context='FACES')
        rot = Vector((0, 0, 1)).rotation_difference(Vector(axis)).to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=Matrix.Translation(center) @ rot, verts=bm.verts)
        return self.finish(bm, name, mat, bone, 80)

    def prism(self, name, outline, z0, z1, mat, bone=None, smooth=35, face_cell=None, axis="z"):
        """Extruded 2D outline (x, y) between z0..z1: gun bodies, shields, stocks.
        axis='x' extrudes along X instead (outline given as (y, z))."""
        bm = bmesh.new()
        if axis == "z":
            lo = [bm.verts.new((x, y, z0)) for x, y in outline]; hi = [bm.verts.new((x, y, z1)) for x, y in outline]
        else:
            lo = [bm.verts.new((z0, y, z)) for y, z in outline]; hi = [bm.verts.new((z1, y, z)) for y, z in outline]
        n = len(outline)
        for k in range(n): bm.faces.new((lo[k], lo[(k + 1) % n], hi[(k + 1) % n], hi[k]))
        bm.faces.new(lo[::-1]); bm.faces.new(hi)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return self.finish(bm, name, mat, bone, smooth, face_cell)

    def join(self, name):
        bpy.ops.object.select_all(action='DESELECT')
        for ob, _ in self.parts: ob.select_set(True)
        bpy.context.view_layer.objects.active = self.parts[0][0]
        bpy.ops.object.join()
        ob = bpy.context.active_object
        ob.name = ob.data.name = name
        return ob

    def tris(self):
        return sum(len(p.vertices) - 2 for ob, _ in self.parts for p in ob.data.polygons)


def superellipse(a, b, t, n=4.0, notch=0.0):
    c, s = math.cos(t), math.sin(t)
    x = a * math.copysign(abs(c) ** (2 / n), c)
    y = b * math.copysign(abs(s) ** (2 / n), s)
    if y < 0 and notch: y += notch * math.exp(-(x / (a * .25)) ** 2)
    return x, y


def rounded_rect(w, h, r, steps=1):
    """Outline of a chamfered/rounded rectangle centred at 0 (for prisms)."""
    pts = []
    for cx, cy, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
        for k in range(steps + 1):
            a = D(a0 + 90 * k / steps)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def camo_cell(p, cells=("camo_a", "camo_b", "camo_c"), scale=1.0):
    """Blobby low-frequency camo from the face centre: neighbouring faces share a colour."""
    x, y, z = (p.center * scale) if hasattr(p, "center") else p
    n = math.sin(x * 21 + y * 7) + math.sin(y * 17 - z * 23 + 1.3) + math.sin(z * 19 + x * 11 + 2.1)
    return cells[0] if n < -.55 else cells[1] if n < .6 else cells[2]


def empty(scene, name, loc, parent=None, size=.02):
    ob = bpy.data.objects.new(name, None)
    scene.collection.objects.link(ob)
    ob.empty_display_size = size
    ob.location = loc
    if parent: ob.parent = parent
    return ob


def preview_scene(scene, lens=70, res=720):
    floor_bm = bmesh.new(); bmesh.ops.create_grid(floor_bm, x_segments=1, y_segments=1, size=8)
    fm = bpy.data.meshes.new("floor"); floor_bm.to_mesh(fm); floor_bm.free()
    floor = bpy.data.objects.new("preview_floor", fm); scene.collection.objects.link(floor)
    fmat = bpy.data.materials.new("preview_floor")
    fmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*srgb("9e9a95"), 1)
    fm.materials.append(fmat)
    wall = floor.copy(); wall.data = fm; wall.name = "preview_wall"; scene.collection.objects.link(wall)
    wall.rotation_euler = (D(90), 0, 0); wall.location = (0, -6, 0)
    for name, loc, energy, size, rot in (("key", (1.6, 2.2, 2.6), 260, 2.0, (-40, 25, 145)),
                                         ("fill", (-2.4, 1.0, 1.4), 70, 3.0, (-70, 0, -110)),
                                         ("rim", (-.6, -1.8, 2.2), 120, 1.5, (40, -10, 0))):
        ld = bpy.data.lights.new(name, 'AREA'); ld.energy = energy; ld.size = size
        lo = bpy.data.objects.new(name, ld); scene.collection.objects.link(lo)
        lo.location = loc; lo.rotation_euler = [D(a) for a in rot]
    world = bpy.data.worlds.new("preview"); scene.world = world
    world.node_tree.nodes["Background"].inputs[0].default_value = (*srgb("b7b2ac"), 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = .6
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scene.collection.objects.link(cam)
    cam.data.lens = lens; scene.camera = cam
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try: scene.render.engine = engine; break
        except TypeError: pass
    scene.render.resolution_x, scene.render.resolution_y = res, res
    return cam


def aim_camera(cam, yaw, pitch=12, dist=3.0, target=(0, 0, .5)):
    t = Vector(target)
    d = Vector((math.sin(D(yaw)) * math.cos(D(pitch)), math.cos(D(yaw)) * math.cos(D(pitch)), math.sin(D(pitch))))
    cam.location = t + d * dist
    cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler()


def still(scene, cam, path, yaw, pitch, dist=3.0, target=(0, 0, .5)):
    aim_camera(cam, yaw, pitch, dist, target)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
