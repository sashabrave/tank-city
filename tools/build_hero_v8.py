"""Hero cat v8: hand-built parts from the GPT Image 2.5 sheets (art_requests/hero_cat_v8).

Run:  Blender -b --factory-startup --python tools/build_hero_v8.py -- [--check]
Output: assets/source/hero_v8_parts.blend   objects hero_head / hero_helmet / hero_body, each face with a palette cell
        (custom property "cells") and a vertex-group hint per part ("bones").
--check renders orthographic silhouettes (front / side / top) and compares them with blueprint.json
        (tools/hero_v8_refs.py): IoU per view and red/green overlays in tmp/hero_v8/.

Space: v6 (+Y forward, Z up, metres), height 1.1 to the ear tips on the blueprint; the head and helmet are then
scaled 1.2x from the neck (toy proportions, user request 2 Oct 2026), so the cat stands ~1.2. Proportions follow the blueprint:
helmet dome .73-1.0 (widest .85, +-.25), face .65-.8, collar .6, shoulders .55, paws .40-.45 at +-.3,
belt .35, knees .18, boots to .12. The neck stump is narrower than the collar and sits inside it.
Every part is a loft of super-ellipse rings (asymmetric radii), so its silhouette can be matched to the sheet.
"""
import bpy, bmesh, math, os, sys, json
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v6_common import camo_cell

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/source/hero_v8_parts.blend")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
D = math.radians

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ---------------------------------------------------------------- mesh kit
class Part:
    """One output object: faces carry palette cells; vertices carry a bone list for skinning."""
    def __init__(self, name):
        self.name, self.bm, self.cells, self.vbones = name, bmesh.new(), [], {}

    def face(self, verts, cell):
        f = self.bm.faces.new(verts); self.cells.append(cell); return f

    def tag(self, verts, bones):
        for v in verts: self.vbones[v] = bones

    def finish(self, smooth=48):
        bm = self.bm
        bm.verts.index_update(); bm.faces.index_update()
        me = bpy.data.meshes.new(self.name)
        bones = [None] * len(bm.verts)
        for v, b in self.vbones.items():
            if v.is_valid: bones[v.index] = b
        bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new(self.name, me); scene.collection.objects.link(ob)
        ob["cells"] = self.cells
        ob["bones"] = json.dumps([b if b else "" for b in bones])
        for p in me.polygons: p.use_smooth = True
        me.set_sharp_from_angle(angle=D(smooth))
        return ob

def sup(t, n):
    """Super-ellipse unit point at angle t (n=2 ellipse, larger = boxier)."""
    c, s = math.cos(t), math.sin(t)
    return math.copysign(abs(c) ** (2 / n), c), math.copysign(abs(s) ** (2 / n), s)

def loft(P, rings, cell, bones, sides=12, cap0=True, cap1=True, frame=None, face_cell=None):
    """rings: list of (centre Vector, rx_minus, rx_plus, ry_minus, ry_plus, n). Ring plane is XY unless
    `frame(i)` gives (u, v) axes (for limbs along a path). Returns ring vertex lists."""
    out = []
    for i, (c, xm, xp, ym, yp, n) in enumerate(rings):
        u, v = frame(i) if frame else (Vector((1, 0, 0)), Vector((0, 1, 0)))
        ring = []
        for k in range(sides):
            a, b = sup(2 * math.pi * k / sides, n)
            ring.append(P.bm.verts.new(c + u * (a * (xp if a > 0 else xm)) + v * (b * (yp if b > 0 else ym))))
        P.tag(ring, bones(i, c) if callable(bones) else bones)
        out.append(ring)
    for i in range(len(out) - 1):
        r0, r1 = out[i], out[i + 1]
        for k in range(sides):
            q = (r0[k], r0[(k + 1) % sides], r1[(k + 1) % sides], r1[k])
            P.face(q, face_cell(i, k, q) if face_cell else cell)
    for ring, flip, on in ((out[0], True, cap0), (out[-1], False, cap1)):
        if not on: continue
        c = P.bm.verts.new(sum((v.co for v in ring), Vector()) / len(ring)); P.tag([c], P.vbones[ring[0]])
        for k in range(sides):
            tri = (ring[(k + 1) % sides], ring[k], c) if flip else (ring[k], ring[(k + 1) % sides], c)
            P.face(tri, face_cell(-1, k, tri) if face_cell else cell)
    return out

def path_frames(pts):
    """Parallel-transport frames along a polyline (for limbs and the tail)."""
    frames = []
    t0 = (pts[1] - pts[0]).normalized()
    u = Vector((1, 0, 0)) if abs(t0.x) < .9 else Vector((0, 1, 0))
    u = (u - t0 * u.dot(t0)).normalized()
    for i in range(len(pts)):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        u = (u - t * u.dot(t)).normalized(); v = t.cross(u)
        frames.append((u, v))
    return frames

def box(P, c, size, cell, bones, bevel=0.0, rot=Matrix.Identity(3)):
    """Chamfered box (8 corners cut): reads soft, costs 26 faces."""
    hx, hy, hz = (s / 2 for s in size)
    b = min(hx, hy, hz) * bevel
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=(hx * 2, hy * 2, hz * 2), verts=bm.verts)
    if b > 1e-4: bmesh.ops.bevel(bm, geom=bm.verts[:] + bm.edges[:], offset=b, segments=1, affect='EDGES', clamp_overlap=True)
    m = Matrix.Translation(c) @ rot.to_4x4()
    vmap = {v: P.bm.verts.new(m @ v.co) for v in bm.verts}
    P.tag(vmap.values(), bones)
    for f in bm.faces: P.face([vmap[v] for v in f.verts], cell)
    bm.free()

def blob(P, c, r, cell, bones, seg=8, rings=5, rot=Matrix.Identity(3), face_cell=None):
    """Ellipsoid made from rings (so face_cell can paint caps)."""
    rr = []
    for j in range(1, rings):
        phi = math.pi * j / rings
        rr.append((Vector((0, 0, -math.cos(phi) * r[2])), math.sin(phi) * r[0], math.sin(phi) * r[0],
                   math.sin(phi) * r[1], math.sin(phi) * r[1], 2))
    m = Matrix.Translation(c) @ rot.to_4x4()
    start = len(P.bm.verts)
    rings_v = loft(P, rr, cell, bones, sides=seg, face_cell=face_cell)
    for ring in rings_v:
        for v in ring: v.co = m @ v.co
    P.bm.verts.ensure_lookup_table()
    for v in P.bm.verts[start:]:
        if v not in {x for ring in rings_v for x in ring}: pass
    # caps were created at ring centroids: move them to the poles
    caps = [v for v in P.bm.verts[start:] if v not in {x for ring in rings_v for x in ring}]
    if len(caps) == 2:
        caps[0].co = m @ Vector((0, 0, -r[2])); caps[1].co = m @ Vector((0, 0, r[2]))
    return rings_v

def rot_to(z_axis, up=Vector((0, 0, 1))):
    z = z_axis.normalized(); x = up.cross(z)
    if x.length < 1e-4: x = Vector((1, 0, 0))
    x.normalize(); y = z.cross(x)
    return Matrix((x, y, z)).transposed()

# ---------------------------------------------------------------- proportions (from blueprint.json)
H_TOP, H_WIDE, H_RIM_F, H_RIM_B = 1.0, .85, .83, .73     # helmet dome
HELM_RX, HELM_RY, HELM_CY = .25, .24, -.02
EYE_Z, EYE_X, FACE_Y = .765, .078, .175
NECK_Z0, COLLAR_Z = .58, .615
SH_X, SH_Z = .175, .555
PAW_C = Vector((.3, .085, .375))     # a little longer than the concept: two paws must reach the rifle
BELT_Z = .35
HIP_X, KNEE_Z, ANKLE_Z = .085, .18, .1

# ---------------------------------------------------------------- head (bone "head")
def build_head():
    P = Part("hero_head")
    HB = ["head"]
    # Skull: chibi round head, cheeks widest at .73, flatter face plane, top under the helmet.
    prof = [(.6, .07, .065, .06, 2), (.625, .12, .1, .1, 2.2), (.66, .17, .145, .135, 2.3), (.7, .19, .165, .16, 2.4),
            (.75, .195, .17, .17, 2.4), (.8, .19, .17, .168, 2.3), (.86, .175, .165, .16, 2.2), (.92, .145, .14, .135, 2.1),
            (.95, .1, .095, .095, 2), (.97, .045, .045, .045, 2)]
    loft(P, [(Vector((0, -.005, z)), rx, rx, yb, yf, n) for z, rx, yb, yf, n in prof], "fur", HB, sides=14,
         face_cell=lambda i, k, q: "fur_dark" if (i in (5, 6, 7) and sum(v.co.y for v in q) / 4 < -.05 and k % 3 == 0) else "fur")
    # Muzzle and chin (cream), nose (pink).
    blob(P, Vector((0, FACE_Y - .005, .7)), (.075, .045, .05), "muzzle", HB, seg=8, rings=4)
    for s in (-1, 1):
        blob(P, Vector((s * .036, FACE_Y + .012, .705)), (.04, .03, .034), "muzzle", HB, seg=8, rings=4)
    blob(P, Vector((0, FACE_Y + .04, .728)), (.019, .012, .013), "nose", HB, seg=6, rings=3)
    # Mouth line: two thin dark wedges under the nose.
    for s in (-1, 1):
        box(P, Vector((s * .014, FACE_Y + .043, .694)), (.026, .006, .005), "black", HB, bevel=0, rot=Matrix.Rotation(D(-18 * s), 3, 'Y'))
    # Eyes: amber iris, dark pupil and a white glint, layered on the face plane.
    for s in (-1, 1):
        c = Vector((s * EYE_X, FACE_Y - .014, EYE_Z))
        n = Vector((s * .35, 1, .05)).normalized()
        R = rot_to(n)
        blob(P, c, (.04, .046, .016), "hazard", HB, seg=8, rings=3, rot=R)
        blob(P, c + n * .01, (.026, .032, .01), "black", HB, seg=8, rings=3, rot=R)
        blob(P, c + n * .018 + Vector((-s * .01, 0, .014)), (.009, .009, .004), "muzzle", HB, seg=6, rings=3, rot=R)
    # Ears: four-sided pyramids through the helmet, pink inner face toward the front.
    for s in (-1, 1):
        base = Vector((s * .15, -.005, .9)); up = Vector((s * .42, .02, 1)).normalized()
        side = Vector((0, 1, 0)).cross(up).normalized() * s; fwd = up.cross(side).normalized() * s
        w, t, h = .07, .04, .17
        b = [P.bm.verts.new(base + side * w + fwd * t), P.bm.verts.new(base - side * w + fwd * t),
             P.bm.verts.new(base - side * w - fwd * t), P.bm.verts.new(base + side * w - fwd * t)]
        inner = [P.bm.verts.new(base + side * w * .55 + fwd * (t + .002) + up * .03), P.bm.verts.new(base - side * w * .55 + fwd * (t + .002) + up * .03)]
        tip = P.bm.verts.new(base + up * h + fwd * .01)
        P.tag(b + inner + [tip], HB)
        fr = Vector((0, 1, 0))
        quads = [(b[0], b[1], tip), (b[1], b[2], tip), (b[2], b[3], tip), (b[3], b[0], tip)]
        for q in quads:
            nrm = (q[1].co - q[0].co).cross(q[2].co - q[0].co)
            if nrm.dot(sum((v.co for v in q), Vector()) / 3 - base) < 0: q = q[::-1]
            front = abs((sum((v.co for v in q), Vector()) / 3 - base).dot(fwd)) > .02 and (sum((v.co for v in q), Vector()) / 3 - base).dot(fwd) > 0
            P.face(q, "fur")
        tri = (inner[0], inner[1], tip) if s > 0 else (inner[1], inner[0], tip)
        P.face(tri, "ear_inner")
        P.face(b[::-1] if s > 0 else b, "fur")
    # Whiskers: three per side, thin 3-sided sticks.
    for s in (-1, 1):
        for dz, ang in ((.012, 6), (0, -2), (-.012, -10)):
            a = Vector((s * .06, FACE_Y + .03, .708 + dz))
            d = Vector((s * math.cos(D(ang)), .25, math.sin(D(ang)))).normalized()
            loft(P, [(a, .003, .003, .003, .003, 2), (a + d * .065, .0015, .0015, .0015, .0015, 2)], "muzzle", HB,
                 sides=3, frame=lambda i, d=d: path_frames([Vector(), d])[0], cap0=False, cap1=False)
    return P.finish(smooth=40)

# ---------------------------------------------------------------- helmet (bone "head")
def helmet_rim(theta):
    """Rim height around the head: high over the eyes (front, theta=90deg), low at the back."""
    f = (math.sin(theta) + 1) / 2          # 1 front, 0 back
    return H_RIM_B + (H_RIM_F - H_RIM_B) * f ** 1.6

def build_helmet():
    P = Part("hero_helmet")
    HB = ["head"]
    seg, rows = 20, 8
    ears = [(math.atan2(-.005 + .0, s * .15), ) for s in (-1, 1)]
    def shell_pt(theta, t, grow=0.0):
        """t: 0 at the rim, 1 at the top. Dome profile from the helmet sheet (flat-ish crown, widest low)."""
        zr = helmet_rim(theta)
        h = math.sin(t * math.pi / 2) * .965               # rings bunch up toward the crown, last ring stays open
        z = zr + (H_TOP - zr) * h
        r = math.sqrt(max(0.0, 1 - h ** 2.4)) ** .9            # super-dome: full width down low
        flare = .012 * max(0.0, 1 - t * 6)                      # lip flares out at the rim
        x = math.cos(theta) * (HELM_RX * r + flare + grow); y = HELM_CY + math.sin(theta) * (HELM_RY * r + flare + grow)
        return Vector((x, y, z))
    # Ear cut-outs in (theta, height) space, around where the ears pass the shell.
    def shell_dist(p):
        """>0 outside the outer shell surface (radial test at the point's own angle and height)."""
        th = math.atan2(p.y - HELM_CY, p.x)
        zr = helmet_rim(th)
        h = min(1.0, max(0.0, (p.z - zr) / (H_TOP - zr)))
        r = math.sqrt(max(0.0, 1 - h ** 2.4)) ** .9
        ex = Vector((math.cos(th) * HELM_RX * r, math.sin(th) * HELM_RY * r))
        return Vector((p.x, p.y - HELM_CY)).length - ex.length
    holes = []
    for s in (-1, 1):   # where each ear axis leaves the shell (ears from build_head: base, up)
        base = Vector((s * .15, -.005, .9)); up = Vector((s * .42, .02, 1)).normalized()
        p = base
        for _ in range(80):
            if shell_dist(p) > 0: break
            p = p + up * .004
        holes.append((math.atan2(p.y - HELM_CY, p.x), p.z, .3, .04))
    print("ear holes", [(round(math.degrees(t)), round(z, 3)) for t, z, *_ in holes])
    def in_hole(theta, z):
        for th, zc, dth, dz in holes:
            d = (theta - th + math.pi) % (2 * math.pi) - math.pi
            if (d / dth) ** 2 + ((z - zc) / dz) ** 2 < 1: return True
        return False
    grid_o, grid_i = [], []
    for j in range(rows + 1):
        t = j / rows
        ro, ri = [], []
        for k in range(seg):
            th = 2 * math.pi * k / seg
            po = shell_pt(th, t); pi = shell_pt(th, t, grow=-.016)
            ro.append(P.bm.verts.new(po)); ri.append(P.bm.verts.new(pi))
        grid_o.append(ro); grid_i.append(ri)
    top_o = P.bm.verts.new(Vector((0, HELM_CY, H_TOP))); top_i = P.bm.verts.new(Vector((0, HELM_CY, H_TOP - .016)))
    P.tag([v for r in grid_o + grid_i for v in r] + [top_o, top_i], HB)
    def cell_at(th, z, outer):
        if not outer: return "camo_b"
        band = helmet_rim(th) + .035 < z < helmet_rim(th) + .07 and math.sin(th) < .55
        return "strap" if band else None
    hole = set()
    for j in range(rows):
        for k in range(seg):
            th = 2 * math.pi * (k + .5) / seg
            zc = (grid_o[j][k].co.z + grid_o[j + 1][k].co.z) / 2
            if in_hole(th, zc): hole.add((j, k))
    holes_faces = len(hole)
    for j in range(rows):
        for k in range(seg):
            k1 = (k + 1) % seg
            th = 2 * math.pi * (k + .5) / seg
            zc = (grid_o[j][k].co.z + grid_o[j + 1][k].co.z) / 2
            if (j, k) in hole:
                # wall only towards solid neighbours: the cut-out gets a clean rim of shell thickness
                for (nj, nk), (a, b) in (((j - 1, k), ((j, k), (j, k1))), ((j + 1, k), ((j + 1, k1), (j + 1, k))),
                                         ((j, (k - 1) % seg), ((j + 1, k), (j, k))), ((j, k1), ((j, k1), (j + 1, k1)))):
                    if (nj, nk) in hole or nj < 0 or nj >= rows: continue
                    oa, ob_ = grid_o[a[0]][a[1]], grid_o[b[0]][b[1]]
                    ia, ib = grid_i[a[0]][a[1]], grid_i[b[0]][b[1]]
                    P.face((ob_, oa, ia, ib), "camo_b")
                continue
            q = (grid_o[j][k], grid_o[j][k1], grid_o[j + 1][k1], grid_o[j + 1][k])
            P.face(q, cell_at(th, zc, True) or "camo_a")
            if j < 3:   # inside of the shell only near the rim, where the camera can see it
                P.face((grid_i[j + 1][k], grid_i[j + 1][k1], grid_i[j][k1], grid_i[j][k]), "camo_b")
    for k in range(seg):
        k1 = (k + 1) % seg
        P.face((grid_o[rows][k], grid_o[rows][k1], top_o), "camo_a")
        P.face((grid_i[0][k], grid_i[0][k1], grid_o[0][k1], grid_o[0][k]), "camo_a")     # rim edge
    # Side rails (small bumps at the temples) and the goggles strap anchors.
    for s in (-1, 1):
        th = math.atan2(.03 - HELM_CY, s * HELM_RX)
        p = shell_pt(th, .22, grow=.008)
        box(P, p, (.022, .07, .03), "strap", HB, bevel=.3, rot=rot_to(Vector((s, 0, 0)), Vector((0, 0, 1))))
    # Goggles: one black frame with two amber lenses on the brow above the rim.
    gz = H_RIM_F + .065
    for s in (-1, 1):
        th = math.atan2(1, s * .42)
        p = shell_pt(th, .25, grow=.004); p.z = gz
        n = Vector((math.cos(th) / HELM_RX, math.sin(th) / HELM_RY, .25)).normalized()
        R = rot_to(n)
        loft(P, [(Vector((0, 0, 0)), .062, .062, .045, .045, 3.2), (Vector((0, 0, .03)), .06, .06, .043, .043, 3.2),
                 (Vector((0, 0, .03)), .047, .047, .032, .032, 3), (Vector((0, 0, .02)), .047, .047, .032, .032, 3)],
             "strap", HB, sides=8, cap0=False, cap1=True,
             face_cell=lambda i, k, q: "lens" if i == -1 else "strap")
        for v in P.bm.verts[-33:]:
            pass
    # place the two goggle lofts: the last 2*(4*8+1) verts were built at the origin; move them onto the brow
    P.bm.verts.ensure_lookup_table()
    n_per = 4 * 8 + 1
    for idx, s in enumerate((-1, 1)):
        th = math.atan2(1, s * .42)
        p = shell_pt(th, .25, grow=.0); p.z = gz
        n = Vector((math.cos(th) / HELM_RX, math.sin(th) / HELM_RY, .25)).normalized()
        m = Matrix.Translation(p) @ rot_to(n).to_4x4()
        start = len(P.bm.verts) - (2 - idx) * n_per
        for v in P.bm.verts[start:start + n_per]: v.co = m @ v.co
    # nose bridge between the lenses
    box(P, shell_pt(math.pi / 2, .25, grow=.012) + Vector((0, 0, gz - shell_pt(math.pi / 2, .25).z)), (.05, .02, .022), "strap", HB, bevel=0)
    ob = P.finish(smooth=55)
    print("helmet hole cells", holes_faces)
    return ob

# ---------------------------------------------------------------- body: torso, vest, belt, pack, arms, legs, boots, tail
def torso_bones(i, c):
    return ["spine"] if c.z > .42 else (["spine", "pelvis"] if c.z > .36 else ["pelvis"])

def build_body():
    P = Part("hero_body")
    # Shirt torso and hips (camo), from the crotch up to the collar.
    prof = [(.27, .1, .1, .09, 2.4), (.31, .15, .115, .105, 2.6), (.35, .152, .118, .11, 2.8), (.42, .158, .12, .118, 2.8),
            (.5, .168, .122, .12, 2.6), (.55, .165, .115, .11, 2.3), (.585, .12, .095, .09, 2.1), (.6, .085, .075, .07, 2)]
    loft(P, [(Vector((0, 0, z)), rx, rx, yb, yf, n) for z, rx, yb, yf, n in prof], "camo_a", torso_bones, sides=12,
         face_cell=lambda i, k, q: camo_cell(type("F", (), {"center": sum((v.co for v in q), Vector()) / len(q)})()))
    # Collar: a snug olive ring standing up around the neck stump.
    loft(P, [(Vector((0, -.005, .585)), .115, .115, .1, .1, 2.2), (Vector((0, -.005, .615)), .108, .108, .095, .095, 2.2),
             (Vector((0, -.005, .615)), .092, .092, .08, .08, 2.2), (Vector((0, -.005, .595)), .09, .09, .078, .078, 2.2)],
         "camo_b", ["spine"], sides=10, cap0=False, cap1=False)
    # Plate carrier: front and back plates, cummerbund, shoulder straps, two chest pouches.
    vest = [(.37, .165, .135, .135, 3.4), (.45, .172, .138, .138, 3.4), (.53, .17, .13, .13, 3), (.56, .14, .12, .118, 2.6)]
    loft(P, [(Vector((0, 0, z)), rx, rx, yb, yf, n) for z, rx, yb, yf, n in vest], "vest", ["spine"], sides=12, cap0=True, cap1=False,
         face_cell=lambda i, k, q: "pouch" if i == 0 else "vest")
    for s in (-1, 1):
        box(P, Vector((s * .085, .005, .575)), (.05, .25, .03), "vest", ["spine"], bevel=.3)            # shoulder strap over the top
        box(P, Vector((s * .085, .143, .56)), (.034, .012, .02), "strap", ["spine"], bevel=0)          # strap buckle front
        box(P, Vector((s * .058, .158, .455)), (.095, .04, .1), "pouch", ["spine"], bevel=.3)           # magazine pouch
        box(P, Vector((s * .058, .17, .49)), (.098, .03, .03), "vest", ["spine"], bevel=0)             # pouch flap
    # Belt with a buckle.
    loft(P, [(Vector((0, 0, BELT_Z - .02)), .158, .158, .122, .124, 3), (Vector((0, 0, BELT_Z + .02)), .158, .158, .122, .124, 3)],
         "strap", ["pelvis"], sides=12, cap0=False, cap1=False)
    box(P, Vector((0, .128, BELT_Z)), (.05, .012, .034), "black", ["pelvis"], bevel=0)
    # Daypack: rounded body, flap lid, two buckle straps, side pouch, top handle, padded shoulder straps.
    pk_y = -.135 - .055
    loft(P, [(Vector((0, pk_y, z)), rx, rx, .055, .05, n) for z, rx, n in
             ((.37, .12, 3.2), (.39, .14, 3.6), (.5, .145, 3.6), (.57, .135, 3.2), (.59, .1, 2.8))], "vest", ["spine"], sides=10,
         face_cell=lambda i, k, q: "pouch" if 2 <= k <= 4 or 9 <= k <= 11 else "vest")
    box(P, Vector((0, pk_y - .045, .54)), (.27, .04, .1), "pouch", ["spine"], bevel=.35)                # flap lid
    for s in (-1, 1):
        box(P, Vector((s * .06, pk_y - .066, .49)), (.022, .01, .1), "strap", ["spine"], bevel=0)       # flap strap
        box(P, Vector((s * .06, pk_y - .07, .445)), (.03, .012, .025), "black", ["spine"], bevel=0)    # buckle
        box(P, Vector((s * .158, pk_y + .005, .44)), (.04, .07, .1), "pouch", ["spine"], bevel=.35)     # side pouch
        box(P, Vector((s * .1, -.115, .5)), (.03, .02, .17), "strap", ["spine"], bevel=0)               # shoulder strap (back)
    box(P, Vector((0, pk_y, .6)), (.08, .02, .02), "strap", ["spine"], bevel=0)                        # carry handle
    box(P, Vector((0, pk_y - .056, .41)), (.2, .008, .012), "strap", ["spine"], bevel=0)               # MOLLE row
    box(P, Vector((0, pk_y - .056, .385)), (.2, .008, .012), "strap", ["spine"], bevel=0)
    # Arms: sleeve from shoulder to wrist, cuff, armband (left), shoulder cap; fur paw with toes and pads.
    for side, s in (("L", -1), ("R", 1)):
        sh = Vector((s * SH_X, .0, SH_Z)); paw = Vector((s * PAW_C.x, PAW_C.y, PAW_C.z))
        el = sh.lerp(paw, .5) + Vector((s * .02, -.015, .01)); wr = sh.lerp(paw, .82)
        pts = [sh + Vector((-s * .02, 0, .02)), sh, sh.lerp(el, .5), el, el.lerp(wr, .5), wr]
        fr = path_frames(pts)
        radii = [.06, .066, .062, .058, .055, .054]
        def arm_bones(i, c, side=side):
            return [f"upper_arm.{side}"] if i <= 2 else ([f"upper_arm.{side}", f"forearm.{side}"] if i == 3 else [f"forearm.{side}"])
        loft(P, [(p, r, r, r * .95, r * .95, 2.2) for p, r in zip(pts, radii)], "camo_a", arm_bones, sides=8, frame=lambda i: fr[i],
             face_cell=lambda i, k, q, side=side: "band" if side == "L" and i == 2 else camo_cell(type("F", (), {"center": sum((v.co for v in q), Vector()) / len(q)})()))
        cuff = wr - (wr - el).normalized() * .01
        loft(P, [(cuff - (wr - el).normalized() * .012, .062, .062, .06, .06, 2.4), (cuff + (wr - el).normalized() * .014, .062, .062, .06, .06, 2.4)],
             "camo_b", [f"forearm.{side}"], sides=8, frame=lambda i, f=fr[-1]: f, cap0=False, cap1=False)
        d = (paw - wr).normalized()
        R = rot_to(d)
        blob(P, wr + d * .045, (.05, .048, .055), "fur", [f"hand.{side}"], seg=8, rings=4, rot=R)
        fwd = Vector((0, 1, 0))
        for t in range(3):   # toes across the front of the fist
            off = Vector((s * (-.018 + t * .012) * 0, 0, 0))
            p = wr + d * .075 + fwd * .028 + (Vector((1, 0, 0)) * s) * (-.022 + t * .022)
            blob(P, p, (.014, .013, .015), "fur", [f"hand.{side}"], seg=5, rings=3)
        blob(P, wr + d * .05 - fwd * .035, (.022, .01, .022), "ear_inner", [f"hand.{side}"], seg=6, rings=3, rot=R)  # palm pad
    # Legs: cargo trousers hip to boot, knee pad and thigh pocket.
    for side, s in (("L", -1), ("R", 1)):
        hip = Vector((s * HIP_X, 0, .31)); knee = Vector((s * .088, .012, KNEE_Z)); ank = Vector((s * .088, 0, ANKLE_Z + .03))
        pts = [hip + Vector((0, 0, .03)), hip, hip.lerp(knee, .5), knee, knee.lerp(ank, .5), ank]
        fr = path_frames(pts)
        radii = [.085, .088, .086, .08, .078, .075]
        def leg_bones(i, c, side=side):
            return ["pelvis", f"thigh.{side}"] if i == 0 else ([f"thigh.{side}"] if i <= 2 else ([f"thigh.{side}", f"shin.{side}"] if i == 3 else [f"shin.{side}"]))
        loft(P, [(p, r, r, r * .92, r * .92, 2.3) for p, r in zip(pts, radii)], "camo_a", leg_bones, sides=8, frame=lambda i: fr[i], cap0=False,
             face_cell=lambda i, k, q: camo_cell(type("F", (), {"center": sum((v.co for v in q), Vector()) / len(q)})()))
        box(P, knee + Vector((0, .072, -.005)), (.08, .03, .075), "vest", [f"shin.{side}"], bevel=.35)                # knee pad
        box(P, hip.lerp(knee, .45) + Vector((s * .086, .0, 0)), (.03, .085, .085), "pouch", [f"thigh.{side}"], bevel=.3)  # cargo pocket
        box(P, hip.lerp(knee, .45) + Vector((s * .1, .0, .035)), (.02, .088, .022), "camo_b", [f"thigh.{side}"], bevel=0)  # pocket flap
        # Boot: chunky shaft + rounded toe + sole slab.
        x0 = s * .088
        sections = [(-.075, .062, .13), (-.04, .07, .14), (.0, .074, .14), (.05, .074, .1), (.1, .07, .075), (.14, .055, .06)]
        rings = [(Vector((x0, y, h / 2 + .012)), w, w, h / 2, h / 2, 3.2) for y, w, h in sections]
        fr_b = [(Vector((1, 0, 0)), Vector((0, 0, 1)))] * len(rings)
        loft(P, rings, "black", [f"foot.{side}"], sides=8, frame=lambda i: fr_b[i])
        box(P, Vector((x0, .03, .008)), (.138, .215, .016), "sole", [f"foot.{side}"], bevel=0)
        loft(P, [(Vector((x0, -.005, .13)), .078, .078, .072, .072, 2.6), (Vector((x0, -.005, .16)), .078, .078, .072, .072, 2.6)],
             "black", [f"shin.{side}"], sides=8, cap0=False, cap1=False)      # boot collar over the trouser hem
    # Tail: ginger with darker rings, from the seat down-back and curling up at the tip (blueprint side view).
    pts = [Vector((0, -.1, .33)), Vector((0, -.17, .29)), Vector((0, -.24, .26)), Vector((0, -.3, .255)), Vector((0, -.34, .275)), Vector((0, -.36, .31))]
    fr = path_frames(pts)
    radii = [.034, .038, .04, .039, .035, .026]
    def tail_bones(i, c):
        return ["tail"] if i <= 1 else ["tail.001"]
    loft(P, [(p, r, r, r, r, 2) for p, r in zip(pts, radii)], "fur", tail_bones, sides=8, frame=lambda i: fr[i],
         face_cell=lambda i, k, q: "fur_dark" if i in (1, 3) else "fur")
    return P.finish(smooth=45)

head = build_head()
helm = build_helmet()
body = build_body()
# Toy proportions: head and helmet 20% larger than the blueprint, grown from the neck (body, rig and gun keep scale).
HEAD_SCALE, NECK_PIVOT = 1.2, Vector((0, 0, .6))
for ob in (head, helm):
    ob.data.transform(Matrix.Translation(NECK_PIVOT) @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-NECK_PIVOT))
for ob in (head, helm, body):
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data); bm.free()
tris = {ob.name: sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in (head, helm, body)}
print("TRIS", tris, "total", sum(tris.values()))
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("SAVED", OUT)
