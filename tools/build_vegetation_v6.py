"""v6 miniature forests: fuller, rounder, more natural shapes in the cat-army low-poly style.

Run: Blender -b --factory-startup --python tools/build_vegetation_v6.py -- [--render]
Keeps the vegetation contract (see assets/source/vegetation/README.md): 5 families x 3
variants, one mesh per GLB named <family>_<variant>, roots at z=0, max footprint 0.94,
COLOR_0 = WindData (flexibility, phase, frequency), StandardMaterials whose albedo the
game tints per biome. Fewer, chunkier trees than v1: tiers and cushions instead of spikes.
"""
import bpy, math, random, os, sys
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/models/vegetation")
PREVIEW = os.path.join(ROOT, "tmp/vegetation_v6")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
MATS = [("Bark", (.26, .21, .16)), ("Needles", (.22, .36, .24)), ("Tips", (.36, .5, .3)), ("Palm", (.38, .52, .26)),
        ("Charcoal", (.2, .19, .18)), ("Ash", (.43, .4, .37)), ("Snow", (.8, .86, .87)), ("Stone", (.45, .47, .42)),
        ("Dry grass", (.5, .45, .3))]
BARK, NEEDLES, TIPS, PALM, CHAR, ASH, SNOW, STONE, DRY = range(9)


class Tile:
    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.verts, self.faces, self.mats, self.wind = [], [], [], []
        self.flex = self.phase = self.period = 0.0

    def tree(self):
        self.phase, self.period = self.rng.random(), self.rng.random()

    def face(self, pts, mat):
        start = len(self.verts)
        self.verts.extend(pts)
        self.faces.append(tuple(range(start, start + len(pts))))
        self.mats.append(mat)
        self.wind.extend([(min(1, max(0, p[2]) / 1.6) ** 1.6 * self.flex, self.phase, self.period, 1) for p in pts])

    def trunk(self, a, b, r1, r2, mat=BARK, sides=6):
        a, b = Vector(a), Vector(b)
        ax = (b - a).normalized()
        u = ax.cross(Vector((0, 1, 0))).normalized()
        if u.length < .1: u = Vector((1, 0, 0))
        v = ax.cross(u).normalized()
        ring = lambda c, r: [c + (u * math.cos(i * math.tau / sides) + v * math.sin(i * math.tau / sides)) * r for i in range(sides)]
        r1s, r2s = ring(a, r1), ring(b, r2)
        for i in range(sides):
            j = (i + 1) % sides
            self.face([r1s[i], r1s[j], r2s[j], r2s[i]], mat)
        self.face(list(reversed(r1s)), mat); self.face(r2s, mat)

    def blob(self, c, r, mat, squash=.8, seg=8, rings=5, jitter=.12, top_mat=None):
        """Faceted cushion / cloud: low UV sphere with a flat-ish base and jittered verts."""
        c = Vector(c)
        grid = []
        for k in range(rings + 1):
            t = k / rings
            phi = -math.pi * .35 + t * math.pi * .85          # clipped base, rounded top
            row = []
            for i in range(seg):
                a = i * math.tau / seg + (k % 2) * math.pi / seg
                rr = r * math.cos(phi) * (1 + self.rng.uniform(-jitter, jitter))
                row.append((c.x + math.cos(a) * rr, c.y + math.sin(a) * rr, c.z + r * squash * math.sin(phi) * (1 + self.rng.uniform(-jitter, jitter) * .5)))
            grid.append(row)
        for k in range(rings):
            for i in range(seg):
                j = (i + 1) % seg
                m = top_mat if (top_mat is not None and k >= rings - 2) else mat
                self.face([grid[k][i], grid[k][j], grid[k + 1][j], grid[k + 1][i]], m)
        self.face(list(reversed(grid[0])), mat)
        top = (c.x, c.y, c.z + r * squash * .98)
        for i in range(seg):
            self.face([grid[-1][i], grid[-1][(i + 1) % seg], top], top_mat if top_mat is not None else mat)

    def tier(self, c, r, h, mat, top_mat=None, n=9, droop=.35):
        """Rounded spruce tier: a wide skirt with a drooping lip and a soft shoulder."""
        x, y, z = c
        a0 = self.rng.random()
        lip, rim, shoulder = [], [], []
        for i in range(n):
            a = a0 + i * math.tau / n
            rr = r * (.9 + .1 * self.rng.random())
            lip.append((x + math.cos(a) * rr * .92, y + math.sin(a) * rr * .92, z - h * droop * .3))
            rim.append((x + math.cos(a) * rr, y + math.sin(a) * rr, z + h * .12))
            shoulder.append((x + math.cos(a) * rr * .55, y + math.sin(a) * rr * .55, z + h * .62))
        tip = (x, y, z + h)
        for i in range(n):
            j = (i + 1) % n
            self.face([lip[i], lip[j], rim[j], rim[i]], mat)
            self.face([rim[i], rim[j], shoulder[j], shoulder[i]], mat)
            self.face([shoulder[i], shoulder[j], tip], mat if top_mat is None else top_mat)  # snow cap only
        self.face(list(reversed(lip)), mat)

    def rock(self, c, r):
        self.flex = 0
        self.blob(c, r, STONE, squash=.55, seg=6, rings=3, jitter=.22)


LAYOUTS = [[(-.24, -.2), (.22, -.16), (.0, .24)],
           [(-.22, .02), (.24, .12), (.02, -.26)],
           [(-.2, -.22), (.25, -.05), (-.16, .24), (.2, .28)]]


def build(family, variant):
    t = Tile(9100 + variant * 131 + sum(map(ord, family)))  # stable across Python runs
    rng = t.rng
    for i, (x, y) in enumerate(LAYOUTS[variant]):
        x += rng.uniform(-.04, .04); y += rng.uniform(-.04, .04)
        scale = rng.uniform(.82, 1.08) * (.78 if i == 3 else 1)
        t.tree(); t.flex = .3 if family == "charred" else 1.0
        if family in ("spruce", "frost"):
            h = 1.25 * scale
            t.trunk((x, y, 0), (x, y, h * .35), .06, .045)
            for k in range(3):
                z = h * (.22 + k * .22)
                r = (.34 - k * .075) * scale
                snow = SNOW if family == "frost" else None
                t.tier((x, y, z), r, h * (.36 - k * .03), NEEDLES if k % 2 == 0 else TIPS, snow)
        elif family == "broadleaf":
            h = 1.05 * scale
            t.trunk((x, y, 0), (x + .02, y, h * .55), .065, .04)
            t.trunk((x + .02, y, h * .45), (x + .12, y + .05, h * .7), .03, .018)
            t.blob((x, y, h * .78), .3 * scale, NEEDLES, squash=.78)
            t.blob((x + .13, y + .08, h * .7), .2 * scale, TIPS, squash=.8)
            t.blob((x - .12, y - .06, h * .66), .19 * scale, TIPS, squash=.8)
        elif family == "palm":
            h = 1.02 * scale
            lean = rng.uniform(-.1, .1)
            seg = 4
            for k in range(seg):  # segmented trunk with little rings
                a = Vector((x + lean * k / seg, y, h * k / seg)); b = Vector((x + lean * (k + 1) / seg, y, h * (k + 1) / seg))
                t.trunk(a, b, .072 - k * .007, .062 - k * .007)
            top = Vector((x + lean, y, h))
            t.blob(top, .07, BARK, squash=.9, seg=6, rings=3)
            for j in range(7):
                a = j * math.tau / 7 + rng.uniform(-.15, .15)
                d = Vector((math.cos(a), math.sin(a), 0)); side = Vector((-math.sin(a), math.cos(a), 0))
                mid = top + d * .2 + Vector((0, 0, .07)); end = top + d * .42 + Vector((0, 0, -.12))
                w = .09
                t.face([top, mid + side * w, mid - side * w], PALM)
                t.face([mid + side * w, end, mid], PALM); t.face([mid, end, mid - side * w], TIPS)
                t.face([mid - side * w, mid + side * w, top], PALM)
        elif family == "charred":
            h = 1.15 * scale
            t.trunk((x, y, 0), (x + .02, y, h), .085, .045, CHAR)
            t.trunk((x + .02, y, h), (x + .05, y + .01, h + .08), .045, .012, CHAR)
            for k in range(2):
                a = k * 2.6 + i
                z = h * (.5 + k * .25)
                end = (x + math.cos(a) * .2, y + math.sin(a) * .2, z + .14)
                t.trunk((x, y, z), end, .032, .012, CHAR)
            t.flex = 0
            t.blob((x, y, .0), .1, ASH, squash=.4, seg=6, rings=2)
    # Edge dressing: bushes and stones round the tile, no square base.
    for j in range(8):
        a = (j + .3 + rng.uniform(-.2, .2)) * math.tau / 8
        x, y = math.cos(a) * .4, math.sin(a) * .4
        t.tree(); t.flex = .6
        if j % 3 == 0:
            t.rock((x, y, 0), .07 + rng.random() * .04)
        elif family == "charred":
            t.flex = 0; t.blob((x, y, 0), .07 + rng.random() * .03, ASH if j % 2 else DRY, squash=.5, seg=6, rings=3)
        elif family == "palm":
            t.blob((x, y, 0), .08 + rng.random() * .03, DRY if j % 2 else PALM, squash=.6, seg=6, rings=3)
        else:
            t.blob((x, y, 0), .1 + rng.random() * .03, NEEDLES if j % 2 else TIPS, squash=.75, seg=7, rings=3,
                   top_mat=SNOW if family == "frost" else None)
    name = f"{family}_{variant:02d}"
    mesh = bpy.data.meshes.new(name); mesh.from_pydata(t.verts, [], t.faces)
    for mname, color in MATS:
        m = bpy.data.materials.get("R13 lush " + mname)
        if m is None:
            m = bpy.data.materials.new("R13 lush " + mname)
            m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1)
            m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .9
        mesh.materials.append(m)
    for p, idx in zip(mesh.polygons, t.mats): p.material_index = idx; p.use_smooth = False
    colors = mesh.color_attributes.new(name="WindData", type='FLOAT_COLOR', domain='POINT')
    for i, value in enumerate(t.wind): colors.data[i].color = value
    mesh.color_attributes.active_color = colors
    xs = [v.co.x for v in mesh.vertices]; ys = [v.co.y for v in mesh.vertices]; bottom = min(v.co.z for v in mesh.vertices)
    s = min(1.0, .94 / max(max(xs) - min(xs), max(ys) - min(ys))); cx = (max(xs) + min(xs)) / 2; cy = (max(ys) + min(ys)) / 2
    for v in mesh.vertices: v.co.x = (v.co.x - cx) * s; v.co.y = (v.co.y - cy) * s; v.co.z -= bottom
    mesh.update()
    ob = bpy.data.objects.new(name, mesh); bpy.context.scene.collection.objects.link(ob)
    return ob, len(mesh.polygons)


bpy.ops.wm.read_factory_settings(use_empty=True)
report = []
objects = []
for row, family in enumerate(["spruce", "palm", "charred", "broadleaf", "frost"]):
    for variant in range(3):
        ob, faces = build(family, variant)
        bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, f"{ob.name}.glb"), use_selection=True, use_active_scene=True,
                                  export_all_vertex_colors=False, export_vertex_color='ACTIVE')
        ob.location = (variant * 1.2, row * 1.3, 0)
        objects.append(ob); report.append(f"{ob.name}:{faces}")
print("VEGETATION", " ".join(report))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "assets/source/vegetation/vegetation_tiles_v6.blend"))
if "--render" in ARGS:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from v6_common import preview_scene, still
    scene = bpy.context.scene
    cam = preview_scene(scene, lens=45, res=900)
    for ob in objects: ob.location.z = 0
    still(scene, cam, os.path.join(PREVIEW, "vegetation.png"), 20, 38, 8.5, (1.2, 2.6, .3))
