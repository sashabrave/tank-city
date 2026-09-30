"""Light, abstract biome props for the battlefield rim: few faces, soft shapes, no detail.

Run: /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/build_biome_props.py
Output: assets/models/biome_props/<name>.glb. Materials are named ENV7_<role> so Visuals.apply_environment_palette
tints them from the room biome (olive = foliage, steel = rock, light/paper = pale, bag = sand, dark = char).
All props stay low (<= .45) so they never cover the edge cells from the tilted camera. Origin at the ground centre.
"""
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/models/biome_props")
ROLES = {"olive": (.45, .5, .38), "steel": (.42, .43, .4), "light": (.8, .8, .74), "bag": (.72, .68, .55), "dark": (.2, .2, .19), "paper": (.9, .9, .86)}


def material(role):
    m = bpy.data.materials.get("ENV7_" + role)
    if m is None:
        m = bpy.data.materials.new("ENV7_" + role)
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*ROLES[role], 1); bsdf.inputs["Roughness"].default_value = .9
    return m


class Prop:
    def __init__(self, seed):
        self.bm = bmesh.new(); self.roles = []; self.rng = random.Random(seed)

    def add(self, geom_verts, role):
        faces = {f for v in geom_verts for f in v.link_faces}
        idx = list(ROLES).index(role)
        for f in faces: f.material_index = idx

    def blob(self, c, r, role, squash=1.0, seg=7, rings=4, jitter=.08):
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=1)
        for v in res["verts"]:
            v.co = Vector((v.co.x * r * (1 + self.rng.uniform(-jitter, jitter)), v.co.y * r * (1 + self.rng.uniform(-jitter, jitter)),
                           max(v.co.z, -.35) * r * squash)) + Vector(c)
        self.add(res["verts"], role)

    def cone(self, c, r1, r2, h, role, seg=6, tilt=(0, 0)):
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=h)
        m = Matrix.Translation(Vector(c) + Vector((0, 0, h / 2))) @ Matrix.Rotation(tilt[0], 4, 'X') @ Matrix.Rotation(tilt[1], 4, 'Y')
        bmesh.ops.transform(self.bm, matrix=m, verts=res["verts"])
        self.add(res["verts"], role)

    def export(self, name):
        me = bpy.data.meshes.new(name); self.bm.to_mesh(me); self.bm.free()
        for role in ROLES: me.materials.append(material(role))
        for p in me.polygons: p.use_smooth = True
        me.set_sharp_from_angle(angle=math.radians(50))
        ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
        bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
        # Drop unused slots so the GLB carries only the roles it uses.
        used = {p.material_index for p in me.polygons}
        for i in reversed(range(len(me.materials))):
            if i not in used:
                ob.active_material_index = i; bpy.ops.object.material_slot_remove()
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True, export_yup=True, export_animations=False)
        print("BIOME", name, len(me.polygons))
        bpy.data.objects.remove(ob)


def rocks(n, seed):
    p = Prop(seed); r = p.rng
    for i in range(n):
        a = r.uniform(0, math.tau); d = r.uniform(0, .14) if i else 0
        p.blob((math.cos(a) * d, math.sin(a) * d, 0), r.uniform(.07, .14) * (1.3 if i == 0 else 1), "steel", squash=r.uniform(.5, .8), seg=6, rings=3, jitter=.15)
    return p


def build():
    os.makedirs(OUT, exist_ok=True)
    rocks(3, 1).export("rock_0")
    rocks(2, 2).export("rock_1")
    p = Prop(3)  # flat slab
    p.blob((0, 0, 0), .2, "steel", squash=.28, seg=7, rings=3, jitter=.12); p.export("rock_flat")
    p = Prop(4)  # round bush of three puffs
    for (x, y, rr) in ((0, 0, .15), (.12, .05, .1), (-.1, .07, .09)): p.blob((x, y, .05), rr, "olive", squash=.85)
    p.export("bush")
    p = Prop(5)  # grass tuft: a few thin cones
    for i in range(6):
        a = i * math.tau / 6 + p.rng.uniform(-.3, .3)
        p.cone((math.cos(a) * .05, math.sin(a) * .05, 0), .025, .0, p.rng.uniform(.14, .24), "olive", seg=4, tilt=(math.sin(a) * .4, -math.cos(a) * .4))
    p.export("tuft")
    p = Prop(6)  # stump with a moss cap
    p.cone((0, 0, 0), .1, .085, .16, "dark", seg=7); p.blob((0, 0, .16), .09, "olive", squash=.35, seg=7, rings=3)
    p.export("stump")
    p = Prop(7)  # log lying down
    p.cone((0, 0, .07), .07, .065, .42, "dark", seg=7, tilt=(0, math.pi / 2)); p.export("log")
    p = Prop(8)  # cactus: capsule trunk and one arm
    p.cone((0, 0, 0), .07, .06, .3, "olive", seg=7); p.blob((0, 0, .3), .062, "olive", squash=1)
    p.cone((.06, 0, .12), .035, .03, .12, "olive", seg=6, tilt=(0, .9)); p.blob((.14, 0, .2), .034, "olive")
    p.export("cactus")
    p = Prop(9)  # reeds
    for i in range(7):
        a = p.rng.uniform(0, math.tau); d = p.rng.uniform(0, .08); h = p.rng.uniform(.22, .4)
        p.cone((math.cos(a) * d, math.sin(a) * d, 0), .012, .006, h, "olive", seg=4, tilt=(p.rng.uniform(-.15, .15), p.rng.uniform(-.15, .15)))
        if i % 3 == 0: p.blob((math.cos(a) * d, math.sin(a) * d, h), .02, "dark", squash=2.2, seg=5, rings=3)
    p.export("reeds")
    p = Prop(10)  # ice crystals
    for i in range(4):
        a = i * 1.7; d = .06 if i else 0
        p.cone((math.cos(a) * d, math.sin(a) * d, 0), .045, 0, p.rng.uniform(.18, .34), "paper", seg=5, tilt=(math.sin(a) * .3, -math.cos(a) * .3))
    p.export("crystal")
    p = Prop(11)  # snow mound
    p.blob((0, 0, 0), .18, "paper", squash=.4, seg=8, rings=4); p.blob((.12, .05, 0), .1, "paper", squash=.45); p.export("snow_mound")
    p = Prop(12)  # sand dune ripple
    p.blob((0, 0, 0), .24, "bag", squash=.22, seg=8, rings=3, jitter=.05); p.export("dune")
    p = Prop(13)  # ash cone with embers colour from 'dark'
    p.cone((0, 0, 0), .16, .02, .16, "dark", seg=7); p.blob((.1, .06, 0), .07, "steel", squash=.5); p.export("ash_cone")


bpy.ops.wm.read_factory_settings(use_empty=True)
build()
