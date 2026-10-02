"""v6 infantry: serious chibi military cats. Model, skinned rig, armed animations, previews.

Run (all kinds):  for k in soldier grenadier shield sniper rpg_soldier; do
    Blender -b --factory-startup --python tools/build_infantry_v6.py -- --kind $k [--species dog] [--render] [--video]; done
--species dog builds the enemy variant (floppy ears, long snout, curled tail) as infantry_v6/dog_<kind>.glb;
body, rig, clips and materials are the same, so kit_model.gd drives both.
Build tools/build_weapons_v6.py first: weapons.json gives each rifle's support point.
Authored facing +Y (becomes Godot -Z), 1 unit = 1 m, height ~1.05.
Bone names match infantry_v5 plus tail/tail.001, so kit_model.gd keeps working.
--mesh v8 (cat soldier only): the hero mesh is hand-built by tools/build_hero_v8.py from the GPT Image 2.5
sheets in art_requests/hero_cat_v8 (toy proportions, head +20%); rig, clips, weapon socket and lamp are the
v6 code with the v8 proportions. Output goes to the usual soldier.glb.

Budget for old Android: ~2k triangles and 3 surfaces (team-paint helmet, glossy
goggle lens, one palette texture). Fur, camo and the chest lamp are palette
cells: kit_model.gd swaps fur/camo per unit at runtime without new surfaces.
"""
import bpy, bmesh, math, os, sys, json
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v6_common import Kit, D, superellipse, camo_cell, aim_camera, preview_scene

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
KIND = ARGS[ARGS.index("--kind") + 1] if "--kind" in ARGS else "soldier"
SPECIES = ARGS[ARGS.index("--species") + 1] if "--species" in ARGS else "cat"
DOG = SPECIES == "dog"
MESH = ARGS[ARGS.index("--mesh") + 1] if "--mesh" in ARGS else "v6"
V8 = MESH == "v8"
assert MESH == "v6" or (V8 and KIND == "soldier" and not DOG), "--mesh v8 is the cat soldier only"
PREFIX = "dog_" if DOG else ""
OUT_DIR = os.path.join(ROOT, "assets/models/infantry_v6")
OUT_GLB = os.path.join(OUT_DIR, f"{PREFIX}{KIND}.glb")
OUT_BLEND = os.path.join(ROOT, f"assets/source/infantry_{MESH}_{KIND}.blend" if MESH != "v6" else f"assets/source/infantry_v6_{PREFIX}{KIND}.blend")
PREVIEW = os.path.join(ROOT, f"tmp/infantry_{MESH}", PREFIX + KIND)
HOLD = json.load(open(os.path.join(OUT_DIR, "weapons.json")))
WEAPON = {"soldier": "rifle", "grenadier": "grenade_launcher", "shield": "shotgun", "sniper": "sniper", "rpg_soldier": "rpg"}[KIND]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30
K = Kit(scene)
# Helmet keeps the v5 name: kit_model.gd swaps it for team paint. Open shell -> double-sided.
HELMET = K.add_special("helmet", K.material("Hero_warm_ivory", "dcd6c6", .7))
HELMET.use_backface_culling = False
# Visor: murky brushed metal, not orange glass.
K.add_special("lens", K.material("V6_goggle_lens", "7d858a", .6, metallic=.85))
UNIFORM = lambda p: camo_cell(p)          # every uniform-covered part gets faceted camo

# ---------------------------------------------------------------- proportions
SH_L = Vector((-.165, .01, .51))
ELB_L = SH_L + Vector((-.64, .06, -.77)).normalized() * .178
WRI_L = ELB_L + Vector((-.55, .16, -.82)).normalized() * .17
HAND_L = WRI_L + Vector((-.45, .2, -.87)).normalized() * .07
HIP_L = Vector((-.08, 0, .27))
KNEE_L = Vector((-.082, .012, .168))
ANK_L = Vector((-.082, 0, .088))
TOE_L = Vector((-.082, .12, .035))
TAIL = [Vector((0, -.1, .28)), Vector((0, -.19, .215)), Vector((0, -.28, .225)), Vector((0, -.34, .3)), Vector((0, -.355, .4))]
mirror = lambda v: Vector((-v.x, v.y, v.z))
HELMET_C = Vector((0, -.01, .8))
HELMET_R = .268
HELMET_SCALE = Vector((1, 1.02, .9))
# Two-handed: rifle across the chest, grip at the right hip, muzzle forward-left.
# Shield: pistol-grip weapon one-handed at the right side, shield on the left arm.
ONE_HAND = KIND == "shield"
GRIP = Vector((.13, .2, .42)) if ONE_HAND else Vector((.02, .16, .38))
GUN_YAW, GUN_PITCH = (0, -4) if ONE_HAND else (42, -6)
SUPPORT_LOCAL = Vector(HOLD[WEAPON]["support"])
LAMP = Vector((-.105, .15, .545))
if V8:
    # Hand-built v8 cat (tools/build_hero_v8.py): toy proportions, short arms, rifle close across the chest.
    SH_L = Vector((-.175, 0, .555))
    _paw = Vector((-.3, .085, .375))
    ELB_L = SH_L.lerp(_paw, .5) + Vector((-.02, -.015, .01))
    WRI_L = SH_L.lerp(_paw, .82)
    HAND_L = _paw + (_paw - WRI_L).normalized() * .03
    HIP_L = Vector((-.085, 0, .31)); KNEE_L = Vector((-.088, .012, .18)); ANK_L = Vector((-.088, 0, .1)); TOE_L = Vector((-.088, .13, .04))
    TAIL = [Vector((0, -.1, .33)), Vector((0, -.17, .29)), Vector((0, -.24, .26)), Vector((0, -.3, .255)), Vector((0, -.36, .31))]
    LAMP = Vector((-.085, .15, .535))
    GRIP = Vector((.05, .16, .43))
    GUN_YAW = 58

# ---------------------------------------------------------------- head
def shell_normal(co, c=HELMET_C, sc=HELMET_SCALE):
    d = co - c
    return Vector((d.x / sc.x ** 2, d.y / sc.y ** 2, d.z / sc.z ** 2)).normalized()

def on_shell(co, c=HELMET_C, sc=HELMET_SCALE, r=HELMET_R):
    d = co - c
    return abs((d.x / sc.x) ** 2 + (d.y / sc.y) ** 2 + (d.z / sc.z) ** 2 - r ** 2) < 2e-3

def dome(name, mat, c, r, sc, low_z, face_top, face_half, segs=16, rings=9, face_cell=None, lip=.014):
    """Low-poly shell (helmet or hood) with analytic ellipsoid normals and a face opening."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    bmesh.ops.scale(bm, vec=sc, verts=bm.verts)
    bmesh.ops.translate(bm, vec=c, verts=bm.verts)
    geom = lambda: bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom(), plane_co=(0, 0, low_z), plane_no=(0, -.3, 1), clear_inner=True)
    bmesh.ops.bisect_plane(bm, geom=geom(), plane_co=(0, 0, face_top), plane_no=(0, 0, 1))
    for x in (-face_half, face_half):
        zone = [f for f in bm.faces if (q := f.calc_center_median()).z < face_top and q.y > 0]
        zg = list({*zone, *(e for f in zone for e in f.edges), *(v for f in zone for v in f.verts)})
        bmesh.ops.bisect_plane(bm, geom=zg, plane_co=(x, 0, 0), plane_no=(1, 0, 0))
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if (q := f.calc_center_median()).z < face_top and abs(q.x) < face_half and q.y > 0], context='FACES')
    bmesh.ops.dissolve_degenerate(bm, dist=.006, edges=bm.edges[:])
    ext = bmesh.ops.extrude_edge_only(bm, edges=[e for e in bm.edges if e.is_boundary])
    for v in (v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)):
        n = shell_normal(v.co, c, sc); n.z = 0; n.normalize()
        v.co += n * lip * .7 + Vector((0, 0, -lip))
    for f in bm.faces:  # explicit winding; recalc flips parts of an open shell
        q = f.calc_center_median()
        want = shell_normal(q, c, sc) if all(on_shell(v.co, c, sc, r) for v in f.verts) else shell_normal(q, c, sc) - Vector((0, 0, .8))
        if f.normal.dot(want) < 0: f.normal_flip()
    ob = K.finish(bm, name, mat, "head", smooth=180, face_cell=face_cell)
    normals = []
    for v in ob.data.vertices:
        n = shell_normal(v.co, c, sc)
        if not on_shell(v.co, c, sc, r): n = (n * Vector((1, 1, 0))).normalized() * .6 + Vector((0, 0, -.8))
        normals.append(n.normalized())
    ob.data.normals_split_custom_set_from_vertices(normals)
    return ob

def ear(side, base_c, radius, sc, cell_out="fur"):
    """Cat ear pushed through the shell: a flattened pyramid, pink inside."""
    s = -1 if side == "L" else 1
    d = Vector((s * .58, .1, .82)).normalized()
    base = base_c + Vector((d.x * sc.x, d.y * sc.y, d.z * sc.z)) * radius * .86
    up = d
    side_v = Vector((0, 1, 0)).cross(up).normalized()
    fwd = up.cross(side_v).normalized()
    w, t, h = .078, .04, .15
    bm = bmesh.new()
    b = [bm.verts.new(base + side_v * w + fwd * t), bm.verts.new(base - side_v * w + fwd * t),
         bm.verts.new(base - side_v * w - fwd * t), bm.verts.new(base + side_v * w - fwd * t)]
    tip = bm.verts.new(base + up * h + fwd * .01)
    inner_front = bm.faces.new((b[0], b[1], tip))
    for i in range(1, 4): bm.faces.new((b[i], b[(i + 1) % 4], tip))
    bm.faces.new(b[::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    front = fwd
    K.finish(bm, f"v6_ear_{side}", cell_out, "head", smooth=30,
             face_cell=lambda p: "ear_inner" if p.normal.dot(front) > .6 else cell_out)

def dog_ear(side, base_c, radius, sc, cell_out="fur_dark"):
    """Floppy dog ear: a soft flap tucked under the helmet rim, hanging down and a little outwards."""
    s = -1 if side == "L" else 1
    # Flared out past the helmet so the flaps read from the top-down battle camera.
    top = base_c + Vector((s * radius * sc.x * .92, .02, -.04))
    ob = K.ellipsoid(f"v6_ear_{side}", (0, 0, -.1), (.04, .088, .125), cell_out, "head", seg=6, rings=4,
                     face_cell=lambda p: "ear_inner" if p.normal.x * -s > .7 else cell_out)
    ob.data.transform(Matrix.Translation(top) @ Matrix.Rotation(-D(48) * s, 4, 'Y') @ Matrix.Rotation(D(-10), 4, 'X'))

def goggles():
    N = 16
    c = HELMET_C + Vector((0, 0, -.028))
    R = .262
    wrap = lambda u, v, r: c + Vector((r * math.sin(u / r), r * math.cos(u / r) * HELMET_SCALE.y, v))
    ts = [2 * math.pi * (k + .5) / N for k in range(N)]
    outer = [superellipse(.225, .068, t, 5, .018) for t in ts]
    inner = [superellipse(.19, .042, t, 4.5, .02) for t in ts]
    mid = [((ox + ix) / 2, (oy + iy) / 2) for (ox, oy), (ix, iy) in zip(outer, inner)]
    bm = bmesh.new()
    rings = [[bm.verts.new(wrap(x * sc, y * sc, R + dr)) for x, y in pts]
             for pts, dr, sc in ((outer, 0, 1), (mid, .038, 1), (inner, .026, 1), (inner, .012, .96))]
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(N): bm.faces.new((r0[k], r0[(k + 1) % N], r1[(k + 1) % N], r1[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    K.finish(bm, "v6_goggle_frame", "strap", "head", smooth=70)
    bm = bmesh.new()
    rim = [bm.verts.new(wrap(x * .98, y * .98, R + .02)) for x, y in inner]
    tip = bm.verts.new(wrap(0, 0, R + .032))
    for k in range(N): bm.faces.new((rim[k], rim[(k + 1) % N], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    lens = K.finish(bm, "v6_goggle_lens", "lens", "head", smooth=180)
    lens.data.normals_split_custom_set_from_vertices(
        [Vector((v.co.x - c.x, v.co.y - c.y, (v.co.z - c.z) * 2.5)).normalized() for v in lens.data.vertices])
    K.band("v6_strap", c, .279, .044, "strap", "head", sides=12, scale_y=HELMET_SCALE.y, skip=lambda p: p.y > .15)

def cat_face():
    """Fur face under the goggles: cheeks, muzzle, nose, whiskers. Stern, not cute-round."""
    K.ellipsoid("v6_face", (0, .085, .69), (.17, .16, .13), "fur", "head", seg=10, rings=6)
    for s in (-1, 1):
        K.ellipsoid("v6_cheek", (s * .046, .205, .652), (.056, .046, .04), "muzzle", "head", seg=6, rings=4)
        for k, (dz, ang) in enumerate(((.012, 8), (-.008, -6))):
            a = Vector((s * .07, .225, .655 + dz)); b = a + Vector((s * math.cos(D(ang)), .15, math.sin(D(ang)))).normalized() * .085
            K.cylinder("v6_whisker", a, b, .0035, "strap", "head", sides=3, caps=False, smooth=10)
    K.ellipsoid("v6_chin", (0, .19, .622), (.04, .03, .024), "muzzle", "head", seg=6, rings=4)
    K.ellipsoid("v6_nose", (0, .247, .676), (.02, .012, .013), "nose", "head", seg=6, rings=3)

def dog_face():
    """Dog face under the goggles: a wide, chubby, short snout with puffy jowls and a big black nose (not a fox)."""
    K.ellipsoid("v6_face", (0, .085, .69), (.17, .16, .13), "fur", "head", seg=10, rings=6)
    K.ellipsoid("v6_snout", (0, .255, .64), (.115, .105, .078), "muzzle", "head", seg=7, rings=4)
    for s in (-1, 1):
        K.ellipsoid("v6_jowl", (s * .072, .26, .608), (.062, .07, .048), "muzzle", "head", seg=5, rings=3)
    K.ellipsoid("v6_chin", (0, .2, .6), (.04, .035, .022), "fur", "head", seg=5, rings=3)
    K.ellipsoid("v6_nose", (0, .352, .675), (.05, .03, .032), "nose", "head", seg=6, rings=3)
    K.ellipsoid("v6_tongue", (0, .32, .575), (.02, .024, .008), "ear_inner", "head", seg=4, rings=2)

def build_head():
    if KIND == "sniper":
        # Ghillie hood over a thin helmet: white brim still shows the team colour.
        dome("v6_helmet", "helmet", HELMET_C, HELMET_R, HELMET_SCALE, .66, .755, .155, segs=14, rings=8)
        hc = HELMET_C + Vector((0, -.018, .012))
        dome("v6_hood", "camo_a", hc, .292, Vector((1.02, 1.04, .97)), .56, .79, .185, segs=14, rings=9,
             face_cell=lambda p: camo_cell(p, scale=1.4), lip=.02)
        for s in "LR": (dog_ear if DOG else ear)(s, hc, .292, Vector((1.02, 1.04, .97)), cell_out="camo_b")
    else:
        dome("v6_helmet", "helmet", HELMET_C, HELMET_R, HELMET_SCALE, .64, .755, .155)
        for s in "LR": (dog_ear(s, HELMET_C, HELMET_R, HELMET_SCALE) if DOG else ear(s, HELMET_C, HELMET_R, HELMET_SCALE))
    dog_face() if DOG else cat_face()
    goggles()

# ---------------------------------------------------------------- torso & gear
def lamp():
    K.cylinder("v6_lamp_body", LAMP - Vector((0, .035, 0)), LAMP, .024, "gun", "spine", sides=6)
    K.cylinder("v6_lamp_lens", LAMP, LAMP + Vector((0, .006, 0)), .019, "lamp", "spine", sides=6)
    K.rbox("v6_lamp_clip", LAMP - Vector((0, .03, .032)), (.02, .02, .04), "strap", "spine", bevel=.005)

def grenade(name, c, bone, axis=(0, 0, 1), r=.028, h=.07):
    a = Vector(c) - Vector(axis) * h / 2; b = Vector(c) + Vector(axis) * h / 2
    K.cylinder(name, a, b, r, "vest", bone, sides=6)
    K.band(name + "_band", Vector(c) + Vector(axis) * h * .18, r * 1.04, h * .18, "band", bone, axis=axis, sides=6)
    K.cylinder(name + "_cap", b, b + Vector(axis) * .012, r * .55, "gun", bone, sides=6)

def build_body():
    K.rbox("v6_torso", (0, 0, .445), (.33, .23, .31), "camo_a", ["pelvis", "spine"], bevel=.09, seg=2, face_cell=UNIFORM)
    K.rbox("v6_pants", (0, 0, .28), (.28, .2, .12), "camo_a", ["pelvis"], bevel=.05, face_cell=UNIFORM)
    K.rbox("v6_belt", (0, 0, .318), (.305, .215, .042), "strap", "pelvis", bevel=.016)
    heavy = KIND == "shield"
    K.rbox("v6_vest", (0, .005, .465), (.36 if heavy else .35, .27 if heavy else .26, .215 if heavy else .205), "vest", "spine", bevel=.045)
    if KIND != "sniper":
        K.rbox("v6_pack", (0, -.165, .45), (.29, .09, .24), "vest", "spine", bevel=.035)
        for x in (-.075, .075):
            K.rbox("v6_pouch_b", (x, -.215, .45), (.12, .035, .19), "pouch", "spine", bevel=.018)
    if KIND == "grenadier":
        for i, x in enumerate((-.085, 0, .085)):
            grenade(f"v6_nade_{i}", (x, .158, .47), "spine")
        grenade("v6_hip_nade", (.16, .02, .3), "pelvis", r=.024, h=.06)
    elif KIND == "shield":
        K.rbox("v6_plate", (0, .15, .47), (.26, .05, .17), "vest", "spine", bevel=.03)
        K.rbox("v6_plate_low", (0, .14, .375), (.22, .045, .06), "vest", "spine", bevel=.015)
        for s in (-1, 1):
            K.rbox("v6_pauldron", (s * .19, .01, .55), (.12, .15, .07), "vest", f"upper_arm.{'L' if s < 0 else 'R'}", bevel=.03)
    elif KIND == "rpg_soldier":
        for x in (-.075, .075):
            K.rbox("v6_pouch_f", (x, .15, .47), (.128, .055, .12), "pouch", "spine", bevel=.024)
        for s in (-1, 1):  # two spare warheads in the pack
            K.ellipsoid("v6_spare", (s * .07, -.19, .62), (.04, .04, .075), "furniture", "spine", seg=6, rings=4, smooth=45)
            K.cylinder("v6_spare_tail", (s * .07, -.19, .52), (s * .07, -.19, .56), .018, "gun", "spine", sides=6)
    else:
        for x in (-.075, .075):
            K.rbox("v6_pouch_f", (x, .15, .47), (.128, .055, .12), "pouch", "spine", bevel=.024)
    if KIND == "sniper":
        cape()
    lamp()

def cape():
    """Ghillie cape over the shoulders and back with a ragged hem (double-sided sheet)."""
    bm = bmesh.new()
    cols, rows = 12, 3
    grid = []
    for r in range(rows + 1):
        t = r / rows
        z = .6 - t * .34
        rad = .2 + t * .08
        row = []
        for c in range(cols + 1):
            a = D(-120 + 240 * c / cols)          # wraps from the left shoulder round the back
            zz = z - (.05 if (r == rows and c % 2) else 0)
            row.append(bm.verts.new((rad * math.sin(a) * 1.05, -rad * math.cos(a) * .9 - .02, zz)))
        grid.append(row)
    for r in range(rows):
        for c in range(cols):
            bm.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))
    # Inner copy, flipped and pulled in a little: the sheet reads from both sides.
    dup = bmesh.ops.duplicate(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:])
    inner = [g for g in dup["geom"] if isinstance(g, bmesh.types.BMFace)]
    for v in (g for g in dup["geom"] if isinstance(g, bmesh.types.BMVert)):
        v.co -= Vector((v.co.x, v.co.y + .02, 0)).normalized() * .006
    bmesh.ops.reverse_faces(bm, faces=inner)
    K.finish(bm, "v6_cape", "camo_a", ["spine", "pelvis"], smooth=50, face_cell=lambda p: camo_cell(p, scale=1.4))

def build_arm(side):
    m = (lambda v: v) if side == "L" else mirror
    sh, el, wr, ha = m(SH_L), m(ELB_L), m(WRI_L), m(HAND_L)
    b = lambda n: f"{n}.{side}"
    K.ellipsoid(f"v6_shoulder_{side}", sh, (.08, .082, .08), "camo_a", b("upper_arm"), seg=6, rings=4, face_cell=UNIFORM)
    K.tube(f"v6_arm_{side}", [sh, sh.lerp(el, .5), el, el.lerp(wr, .5), wr],
           [.07, .068, .064, .06, .057], "camo_a", [b("upper_arm"), b("forearm")], face_cell=UNIFORM)
    K.band(f"v6_cuff_{side}", wr - (wr - el).normalized() * .012, .062, .032, "vest", b("forearm"), axis=(wr - el).normalized(), sides=6)
    if side == "L":
        K.band("v6_armband", sh.lerp(el, .55), .072, .052, "band", b("upper_arm"), axis=(el - sh).normalized(), sides=7)
    hd = (ha - wr).normalized()
    # Paw: fur mitten with a darker thumb pad.
    K.ellipsoid(f"v6_paw_{side}", wr + hd * .055, (.06, .062, .072), "fur", b("hand"), seg=6, rings=4)
    K.ellipsoid(f"v6_thumb_{side}", wr + hd * .03 + Vector((0, .048, 0)) + m(Vector((.015, 0, 0))), (.026, .032, .028), "fur_dark", b("hand"), seg=5, rings=3)

def boot(side, ank):
    x0 = ank.x
    sections = [(-.068, .045, .085), (-.045, .064, .13), (.0, .07, .135), (.055, .07, .095), (.105, .064, .07), (.14, .045, .052)]
    P = 8
    bm = bmesh.new(); rings = []
    for y, w, h in sections:
        ring = []
        for k in range(P):
            t = 2 * math.pi * (k + .5) / P
            sx, sz = superellipse(w, h / 2, t, 3.2)
            ring.append(bm.verts.new((x0 + sx, y, max(h / 2 + sz, .0))))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(P): bm.faces.new((a[k], a[(k + 1) % P], b[(k + 1) % P], b[k]))
    for ring, y in ((rings[0], -.078), (rings[-1], .152)):
        c = bm.verts.new((x0, y, sum(v.co.z for v in ring) / P * .9))
        for k in range(P): bm.faces.new((ring[k], ring[(k + 1) % P], c))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    K.finish(bm, f"v6_boot_{side}", "black", f"foot.{side}", smooth=70, face_cell=lambda p: "sole" if p.center.z < .022 else None)

def build_leg(side):
    m = (lambda v: v) if side == "L" else mirror
    hip, knee, ank = m(HIP_L), m(KNEE_L), m(ANK_L)
    b = lambda n: f"{n}.{side}"
    K.tube(f"v6_leg_{side}", [hip + Vector((0, 0, .04)), hip, hip.lerp(knee, .5), knee, ank + Vector((0, 0, .03))],
           [.08, .083, .08, .074, .066], "camo_a", [b("thigh"), b("shin")], face_cell=UNIFORM)
    K.rbox(f"v6_cargo_{side}", hip.lerp(knee, .5) + m(Vector((-.078, 0, 0))), (.03, .075, .07), "pouch", b("thigh"), bevel=.012)
    boot(side, ank)

def build_tail():
    if DOG:  # short, thick, curled up over the back
        curl = [TAIL[0], TAIL[1] + Vector((0, .02, .03)), TAIL[2] + Vector((0, .04, .1)), TAIL[3] + Vector((0, .1, .12)), TAIL[4] + Vector((0, .15, .06))]
        K.tube("v6_tail", curl, [.05, .052, .048, .042, .032], "fur", ["tail", "tail.001"], sides=6,
               face_cell=lambda p: "muzzle" if p.center.z > .42 else "fur")
        return
    K.tube("v6_tail", TAIL, [.046, .042, .038, .034, .028], "fur", ["tail", "tail.001"], sides=6,
           face_cell=lambda p: "fur_dark" if p.center.z > .33 else "fur")

def import_v8():
    """Palette faces straight from the parts file: UV1 = palette cell (plain v6 material), lens on its own surface."""
    with bpy.data.libraries.load(os.path.join(ROOT, "assets/source/hero_v8_parts.blend")) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith("hero_")]
    lens = K.special["lens"].node_tree.nodes["Principled BSDF"]   # amber glass, as in the concept
    lens.inputs["Base Color"].default_value = (.75, .2, .03, 1); lens.inputs["Metallic"].default_value = .1
    lens.inputs["Roughness"].default_value = .22
    for ob in dst.objects:
        scene.collection.objects.link(ob)
        me = ob.data; cells = list(ob["cells"])
        me.materials.clear(); me.materials.append(K.pal); me.materials.append(K.special["lens"])
        uv = me.uv_layers.new(name="UVMap")
        for p in me.polygons:
            c = cells[p.index]
            if c == "lens": p.material_index = 1; c = "black"
            u = K.cell_uv(c)
            for li in p.loop_indices: uv.data[li].uv = u
        K.parts.append((ob, "HINT"))
    lamp()

if V8:
    import_v8()
else:
    build_head(); build_body(); build_tail()
    for s in "LR": build_arm(s); build_leg(s)

# ---------------------------------------------------------------- armature
arm_data = bpy.data.armatures.new(f"{KIND}_Rig")
rig = bpy.data.objects.new(f"{KIND}_Rig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
FWD = Vector((0, 1, 0)); UP = Vector((0, 0, 1))

def bone(name, head, tail, parent=None, roll_to=FWD, connect=False):
    eb = arm_data.edit_bones.new(name)
    eb.head, eb.tail = Vector(head), Vector(tail)
    eb.align_roll(roll_to)
    if parent: eb.parent = arm_data.edit_bones[parent]; eb.use_connect = connect
    return eb

bone("root", (0, 0, 0), (0, .15, 0), roll_to=UP)
bone("pelvis", (0, 0, .3), (0, 0, .37), "root")
bone("spine", (0, 0, .37), (0, 0, .58), "pelvis", connect=True)
bone("head", (0, 0, .6), (0, 0, .95), "spine")
for s in "LR":
    m = (lambda v: v) if s == "L" else mirror
    bone(f"upper_arm.{s}", m(SH_L), m(ELB_L), "spine")
    bone(f"forearm.{s}", m(ELB_L), m(WRI_L), f"upper_arm.{s}", connect=True)
    bone(f"hand.{s}", m(WRI_L), m(HAND_L), f"forearm.{s}", connect=True)
    bone(f"thigh.{s}", m(HIP_L), m(KNEE_L), "pelvis")
    bone(f"shin.{s}", m(KNEE_L), m(ANK_L), f"thigh.{s}", connect=True)
    bone(f"foot.{s}", m(ANK_L), m(TOE_L), f"shin.{s}", roll_to=UP, connect=True)
bone("weapon", GRIP, GRIP + Vector((0, .06, 0)), "spine", roll_to=UP)
bone("tail", TAIL[0], TAIL[1], "pelvis", roll_to=UP)
bone("tail.001", TAIL[1], TAIL[4], "tail", roll_to=UP, connect=True)
bpy.ops.object.mode_set(mode='OBJECT')

# ---------------------------------------------------------------- skinning
def seg_dist(p, a, b):
    ab = b - a
    t = max(0, min(1, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length

bones = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm_data.bones}

def hint_weights(ob):
    """v8: every vertex lists its bones (build_hero_v8.py); blend them by distance like the v6 tubes."""
    hints = json.loads(ob["bones"])
    groups = {}
    for v, names in zip(ob.data.vertices, hints):
        names = names or ["spine"]
        w = {n: 1 / (seg_dist(v.co, *bones[n]) ** 6 + 1e-9) for n in names}; tot = sum(w.values())
        for n in names:
            if n not in groups: groups[n] = ob.vertex_groups.new(name=n)
            groups[n].add([v.index], w[n] / tot, 'REPLACE')

for ob, target in K.parts:
    if target == "HINT":
        hint_weights(ob); continue
    names = [target] if isinstance(target, str) else target
    groups = {n: ob.vertex_groups.new(name=n) for n in names}
    for v in ob.data.vertices:
        if len(names) == 1:
            groups[names[0]].add([v.index], 1.0, 'REPLACE'); continue
        w = {n: 1 / (seg_dist(v.co, *bones[n]) ** 6 + 1e-9) for n in names}
        tot = sum(w.values())
        for n in names: groups[n].add([v.index], w[n] / tot, 'REPLACE')

if "--budget" in ARGS:
    from collections import Counter
    tally = Counter()
    for ob, _ in K.parts:
        tally[ob.name.split(".")[0].rstrip("_LR")] += sum(len(p.vertices) - 2 for p in ob.data.polygons)
    for k, v in tally.most_common(): print(f"BUDGET {v:5d} {k}")

if V8:
    K.parts.sort(key=lambda e: not e[0].name.startswith("hero_"))
body = K.join(f"{KIND}_body")
body.parent = rig
body.modifiers.new("Armature", 'ARMATURE').object = rig

def bone_child(name, bone_name, local=Matrix.Identity(4)):
    """Empty placed at the bone HEAD (Blender bone-parenting otherwise uses the tail)."""
    ob = bpy.data.objects.new(name, None); scene.collection.objects.link(ob)
    ob.empty_display_size = .03
    ob.parent = rig; ob.parent_type = 'BONE'; ob.parent_bone = bone_name
    bpy.context.view_layer.update()
    ob.matrix_world = rig.matrix_world @ arm_data.bones[bone_name].matrix_local @ local
    return ob

def spine_point(name, world):
    return bone_child(name, "spine", arm_data.bones["spine"].matrix_local.inverted() @ Matrix.Translation(world))

socket = bone_child("WeaponSocket", "weapon")
flash = spine_point("Flashlight", LAMP + Vector((0, .01, 0)))
EXPORT = [rig, body, socket, flash]

shield_pivot = None
if KIND == "shield":
    # Separate rigid panel: actor.gd tilts shield_panel_pivot (raise / hold / lower).
    PIVOT = Vector((-.13, .31, .41))  # bottom edge clears the knees while running
    shield_pivot = spine_point("shield_panel_pivot", PIVOT)
    sk = Kit(scene, "V6_palette_fabric_shield", emissive=False, soft=False)
    sk.pal = K.pal
    from v6_common import rounded_rect
    sk.prism("shield_panel", rounded_rect(.42, .7, .07), -.02, .02, "gun", axis="x", smooth=30)
    panel = sk.parts[0][0]
    panel.rotation_euler = (0, 0, D(90))
    bpy.context.view_layer.objects.active = panel
    panel.select_set(True); bpy.ops.object.transform_apply(rotation=True)
    sk.rbox("shield_window", (0, .024, .2), (.22, .012, .055), "band", bevel=.004)
    for x in (-.15, .15):
        for z in (-.25, .25):
            sk.ellipsoid("shield_bolt", (x, .024, z), (.012, .008, .012), "gun_light", seg=5, rings=3)
    sk.rbox("shield_handle", (0, -.045, 0), (.03, .04, .12), "strap", bevel=.008)
    sh_mesh = sk.join("shield_panel")
    sh_mesh.parent = shield_pivot
    sh_mesh.matrix_parent_inverse = Matrix.Identity(4)
    sh_mesh.location = (0, 0, .03)
    EXPORT += [shield_pivot, sh_mesh]

# ---------------------------------------------------------------- hand IK
ik_r = bone_child("ik_grip_R", "weapon", Matrix.Translation((0, -.03, -.01)))
aim_r = bone_child("ik_aim_R", "weapon", Matrix.Translation((0, .2, -.02)))
pole_r = bone_child("ik_pole_R", "spine", Matrix.Translation((.45, -.1, -.25)))
pole_l = bone_child("ik_pole_L", "spine", Matrix.Translation((-.45, -.05, -.25)))
if ONE_HAND:
    ik_l = bpy.data.objects.new("ik_grip_L", None); scene.collection.objects.link(ik_l)
    ik_l.parent = shield_pivot; ik_l.location = (0, -.07, .03)
    aim_l = bpy.data.objects.new("ik_aim_L", None); scene.collection.objects.link(aim_l)
    aim_l.parent = shield_pivot; aim_l.location = (0, -.06, .25)
else:
    ik_l = bone_child("ik_grip_L", "weapon", Matrix.Translation(SUPPORT_LOCAL + Vector((0, -.01, -.012))))
    aim_l = bone_child("ik_aim_L", "weapon", Matrix.Translation((.05, .3, -.05)))
IK_OBJECTS = [ik_r, ik_l, aim_r, aim_l, pole_l, pole_r]

def add_arm_ik():
    for s, tgt, aim, pole in (("R", ik_r, aim_r, pole_r), ("L", ik_l, aim_l, pole_l)):
        c = rig.pose.bones[f"forearm.{s}"].constraints.new('IK')
        c.target = tgt; c.chain_count = 2; c.pole_target = pole; c.pole_angle = D(-90)
        if V8:   # short toy arms: let the IK chain stretch a little to reach the fore grip
            c.use_stretch = True
            for b in (f"upper_arm.{s}", f"forearm.{s}"): rig.pose.bones[b].ik_stretch = .25
        t = rig.pose.bones[f"hand.{s}"].constraints.new('DAMPED_TRACK')
        t.target = aim

def remove_arm_ik():
    for pb in rig.pose.bones:
        for c in list(pb.constraints): pb.constraints.remove(c)

# ---------------------------------------------------------------- animation helpers
def fcurves(act):
    if getattr(act, "layers", None):
        return [fc for layer in act.layers for strip in layer.strips for cb in strip.channelbags for fc in cb.fcurves]
    return list(act.fcurves)

ZERO = ((0, 0, 0), (0, 0, 0))
def apply_pose(pose):
    for pb in rig.pose.bones:
        pb.rotation_mode = 'XYZ'
        rot, loc = pose.get(pb.name, ZERO)
        pb.rotation_euler = [D(a) for a in rot]; pb.location = loc

def lowest_z():
    bpy.context.view_layer.update()
    ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = ev.to_mesh(); z = min((rig.matrix_world @ v.co).z for v in me.vertices); ev.to_mesh_clear()
    return z

def ground(pose, lift=0.0, up_axis_scale=1.0):
    for _ in range(4):
        apply_pose(pose)
        err = lowest_z() - lift
        if abs(err) < .0005: break
        r, (lx, ly, lz) = pose["pelvis"]
        pose["pelvis"] = (r, (lx, ly - err * up_axis_scale, lz))
    return pose

def key_action(name, frames, poses, loop_end=None, cyclic=True):
    act = bpy.data.actions.new(name)
    rig.animation_data_create(); rig.animation_data.action = act
    seq = list(zip(frames, poses)) + ([(loop_end, poses[0])] if loop_end else [])
    for f, pose in seq:
        apply_pose(pose)
        for pb in rig.pose.bones:
            pb.keyframe_insert("rotation_euler", frame=f); pb.keyframe_insert("location", frame=f)
    act.use_fake_user = True
    if cyclic:
        for fc in fcurves(act): fc.modifiers.new('CYCLES')
    return act

def bake(act, start, end):
    rig.animation_data.action = act
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.pose.select_all(action='SELECT')
    bpy.ops.nla.bake(frame_start=start, frame_end=end, step=1, only_selected=False, visual_keying=True,
                     clear_constraints=False, use_current_action=True, bake_types={'POSE'})
    bpy.ops.object.mode_set(mode='OBJECT')
    act.frame_range = (start, end)

GUN = lambda pitch=0, yaw=0, roll=0, loc=(0, 0, 0): ((GUN_PITCH + pitch, roll, GUN_YAW + yaw), loc)
def TAILP(pitch=0, sway=0, pitch2=0, sway2=0):
    return {"tail": ((pitch, 0, sway), (0, 0, 0)), "tail.001": ((pitch2, 0, sway2), (0, 0, 0))}

# ---------------------------------------------------------------- run (armed) = hero_walk
LEG = [(30, -12), (8, -36), (-24, -16), (-34, -48), (-16, -104), (18, -122), (52, -88), (46, -34)]
FOOT_GLOBAL = {0: 12, 1: 0, 2: -32}
FOOT_SWING = {3: -24, 4: 6, 5: 12, 6: 10, 7: 12}
PELVIS_PITCH = 8

def foot_angle(k):
    th, sh = LEG[k]
    return FOOT_GLOBAL[k] - (th + sh - PELVIS_PITCH) if k in FOOT_GLOBAL else FOOT_SWING[k]

def legs(k):
    L, R = LEG[k], LEG[(k + 4) % 8]
    return {
        "thigh.L": ((L[0], 0, -3), (0, 0, 0)), "shin.L": ((L[1], 0, 0), (0, 0, 0)), "foot.L": ((foot_angle(k), 0, 0), (0, 0, 0)),
        "thigh.R": ((R[0], 0, 3), (0, 0, 0)), "shin.R": ((R[1], 0, 0), (0, 0, 0)), "foot.R": ((foot_angle((k + 4) % 8), 0, 0), (0, 0, 0)),
    }

def run_body(k, armed):
    phase = k / 8 * 2 * math.pi
    twist = (6 if armed else 8) * math.cos(phase)
    step = (k % 4) / 4 * 2 * math.pi
    pose = {
        "pelvis": ((PELVIS_PITCH, twist, 3 * math.sin(phase)), (0, 0, 0)),
        "spine": ((7 - 3 * math.cos(step), -(1.6 if armed else 2.2) * twist, -3 * math.sin(phase)), (0, 0, 0)),
        "head": ((-11 + 3 * math.cos(step - .8), twist * (.7 if armed else 1.1), 1.5 * math.sin(phase)), (0, 0, 0)),
        **legs(k),
        # Tail streams back and flicks with the bounce, a beat behind the hips.
        **TAILP(14 + 8 * math.cos(step - 1.4), -6 * math.cos(phase - .6), 10 + 12 * math.cos(step - 2.0), -10 * math.cos(phase - 1.2)),
    }
    if armed:
        pose["weapon"] = GUN(2 * math.cos(step - 1.2), 3 * math.cos(phase), 3 * math.sin(phase), (0, 0, .008 * math.cos(step - 1.2)))
    else:
        swing = math.cos(phase)
        pose.update({
            "upper_arm.L": ((-8 - 50 * swing, 0, -24), (0, 0, 0)), "forearm.L": ((58 - 26 * swing, 0, 0), (0, 0, 0)),
            "hand.L": ((8, 0, 0), (0, 0, 0)),
            "upper_arm.R": ((-8 + 50 * swing, 0, 24), (0, 0, 0)), "forearm.R": ((58 + 26 * swing, 0, 0), (0, 0, 0)),
            "hand.R": ((8, 0, 0), (0, 0, 0)),
        })
    return pose

LIFT = {0: 0, 1: 0, 2: 0, 3: .035}
def run_poses(armed):
    return [ground(run_body(k, armed), LIFT[k % 4], 1 / math.cos(D(PELVIS_PITCH))) for k in range(8)]

def idle_pose(t):
    b = math.sin(t * 2 * math.pi)
    look = math.sin(t * 2 * math.pi + 1)
    return ground({
        "pelvis": ((1, 0, .8 * b), (0, 0, 0)),
        "spine": ((2 + 1.5 * b, 1.5 * look, -.8 * b), (0, 0, 0)),
        "head": ((-3 - 1.5 * b, 5 * look, 0), (0, 0, 0)),
        "thigh.L": ((2, 0, -2), (0, 0, 0)), "shin.L": ((-4, 0, 0), (0, 0, 0)), "foot.L": ((1, 0, 0), (0, 0, 0)),
        "thigh.R": ((1, 0, 3), (0, 0, 0)), "shin.R": ((-3, 0, 0), (0, 0, 0)), "foot.R": ((1, 0, 0), (0, 0, 0)),
        "weapon": GUN(1.5 * b, 0, 0, (0, 0, .005 * b)),
        # Slow, lazy tail sway; the tip lags and curls.
        **TAILP(4, 16 * math.sin(t * 2 * math.pi), 18, 22 * math.sin(t * 2 * math.pi - 1.1)),
    })

STAND = idle_pose(0)
def with_(base, **over):
    p = dict(base); p.update(over); return p

def fire_poses():
    kick = with_(STAND, weapon=GUN(9, 2, 0, (0, -.035, .01)), spine=((-3, 0, 0), (0, 0, 0)), head=((-6, 0, 0), (0, 0, 0)))
    settle = with_(STAND, weapon=GUN(2, 0, 0, (0, -.008, 0)))
    return [STAND, kick, settle, STAND]

def hit_poses():
    flinch = with_(STAND, pelvis=((-4, 5, 0), (0, 0, -.02)), spine=((-14, 6, 4), (0, 0, 0)),
                   head=((-16, -8, 0), (0, 0, 0)), weapon=GUN(10, -6, 8, (0, -.02, .02)), **TAILP(40, 0, 30, 0))
    return [STAND, flinch, with_(STAND, spine=((4, 0, 0), (0, 0, 0))), STAND]

def death_poses():
    P = lambda rot, loc, **o: with_(STAND, pelvis=(rot, loc), **o)
    L = lambda tl, sl, fl, tr, sr, fr: {"thigh.L": ((tl, 0, -12), (0, 0, 0)), "shin.L": ((sl, 0, 0), (0, 0, 0)), "foot.L": ((fl, 0, 0), (0, 0, 0)),
                                        "thigh.R": ((tr, 0, 14), (0, 0, 0)), "shin.R": ((sr, 0, 0), (0, 0, 0)), "foot.R": ((fr, 0, 0), (0, 0, 0))}
    keys = [
        (1, STAND, 0),
        (4, P((-6, 4, 0), (0, 0, -.01), spine=((-18, 4, 0), (0, 0, 0)), head=((-22, 0, 0), (0, 0, 0)),
              weapon=GUN(14, 8, 10, (0, -.03, .03)), **TAILP(45, 10, 30, 20)), 0),
        (10, P((-24, 6, -4), (0, 0, -.05), spine=((-14, 0, 0), (0, 0, 0)), head=((-8, 6, 0), (0, 0, 0)),
               **L(48, -80, 30, 40, -72, 28), weapon=GUN(20, 12, 12), **TAILP(30, 20, 20, 30)), 0),
        (16, P((-62, 4, -6), (0, 0, -.14), spine=((-12, 0, 0), (0, 0, 0)), head=((6, 8, 0), (0, 0, 0)),
               **L(62, -50, 10, 55, -40, 8), weapon=GUN(-20, 18, 20), **TAILP(0, 30, 0, 30)), .05),
        (21, P((-90, 2, -4), (0, 0, -.24), spine=((-6, 0, 0), (0, 0, 0)), head=((-14, 12, 0), (0, 0, 0)),
               **L(12, -24, -6, 4, -18, -8), weapon=GUN(-55, 28, 34), **TAILP(-40, 35, -10, 40)), 0),
        (25, P((-84, 2, -4), (0, 0, -.25), spine=((-2, 0, 0), (0, 0, 0)), head=((4, 14, 0), (0, 0, 0)),
               **L(22, -30, -4, 14, -24, -6), weapon=GUN(-50, 28, 34), **TAILP(-30, 38, 0, 45)), .018),
        (31, P((-88, 2, -4), (0, 0, -.25), spine=((-5, 0, 0), (0, 0, 0)), head=((-6, 16, 0), (0, 0, 0)),
               **L(-6, -34, -10, -14, -20, -12), weapon=GUN(-58, 30, 36), **TAILP(-45, 40, -10, 50)), 0),
    ]
    return [f for f, _, _ in keys], [ground(p, lift) for _, p, lift in keys]

add_arm_ik()
ACTIONS = {}
ACTIONS["hero_idle"] = key_action("hero_idle", [1, 25], [idle_pose(0), idle_pose(.5)], 49)
ACTIONS["hero_walk"] = key_action("hero_walk", [1 + 2 * k for k in range(8)], run_poses(True), 17)
ACTIONS["hero_fire"] = key_action("hero_fire", [1, 3, 6, 10], fire_poses(), cyclic=False)
ACTIONS["hero_hit"] = key_action("hero_hit", [1, 3, 6, 10], hit_poses(), cyclic=False)
df, dp = death_poses()
ACTIONS["hero_death"] = key_action("hero_death", df, dp, cyclic=False)
for name, (a, b) in {"hero_idle": (1, 49), "hero_walk": (1, 17), "hero_fire": (1, 10), "hero_hit": (1, 10), "hero_death": (1, 31)}.items():
    bake(ACTIONS[name], a, b)
remove_arm_ik()
for ob in IK_OBJECTS: bpy.data.objects.remove(ob)
ACTIONS["hero_run_free"] = key_action("hero_run_free", [1 + 2 * k for k in range(8)], run_poses(False), 17)
rig.animation_data.action = None

# ---------------------------------------------------------------- report
def report(name, frames):
    rig.animation_data.action = ACTIONS[name]
    zs = []
    for f in frames:
        scene.frame_set(f); zs.append(lowest_z())
    print(f"{KIND} {name}: lowest z min {min(zs):+.3f} max {max(zs):+.3f}")
report("hero_walk", range(1, 17)); report("hero_death", range(1, 32, 3))
tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
print(f"{KIND} tris: {tris} surfaces: {len(body.data.materials)}")

# ---------------------------------------------------------------- export
os.makedirs(OUT_DIR, exist_ok=True)
rig.animation_data.action = None
for pb in rig.pose.bones: pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for ob in EXPORT: ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, use_selection=True, export_animations=True,
                          export_animation_mode='ACTIONS', export_yup=True, export_apply=False)

# ---------------------------------------------------------------- previews
def still(cam, path, yaw, pitch, dist=3.0, target=(0, 0, .5)):
    aim_camera(cam, yaw, pitch, dist, target)
    scene.render.filepath = os.path.join(PREVIEW, path)
    bpy.ops.render.render(write_still=True)

def video(cam, name, action, frames, orbit):
    rig.animation_data.action = action
    scene.frame_start, scene.frame_end = 1, frames
    cam.animation_data_clear()
    for f in range(1, frames + 1):
        aim_camera(cam, orbit[0] + (orbit[1] - orbit[0]) * (f - 1) / max(1, frames - 1), 14, target=(0, 0, .45))
        cam.keyframe_insert("location", frame=f); cam.keyframe_insert("rotation_euler", frame=f)
    s = scene.render.image_settings
    if hasattr(s, "media_type"): s.media_type = 'VIDEO'
    s.file_format = 'FFMPEG'
    scene.render.ffmpeg.format = 'MPEG4'; scene.render.ffmpeg.codec = 'H264'
    scene.render.ffmpeg.constant_rate_factor = 'HIGH'
    scene.render.filepath = os.path.join(PREVIEW, name)
    bpy.ops.render.render(animation=True)
    if hasattr(s, "media_type"): s.media_type = 'IMAGE'
    s.file_format = 'PNG'
    cam.animation_data_clear()

if V8 and "--viewer" in ARGS:
    os.makedirs(PREVIEW, exist_ok=True)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(OUT_DIR, f"weapon_{WEAPON}.glb"))
    gun = [o for o in set(bpy.data.objects) - before]
    for ob in gun:
        if ob.parent is None:
            mw = ob.matrix_world.copy(); ob.parent = socket; ob.matrix_parent_inverse = Matrix.Identity(4); ob.matrix_basis = mw
    rig.animation_data.action = None
    for pb in rig.pose.bones: pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in EXPORT + gun: ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(PREVIEW, "soldier_viewer.glb"), use_selection=True, export_animations=True,
                              export_animation_mode='ACTIONS', export_yup=True, export_apply=False)
    for ob in gun: bpy.data.objects.remove(ob)
    print("viewer", os.path.join(PREVIEW, "soldier_viewer.glb"))

if "--render" in ARGS or "--video" in ARGS:
    scene.render.engine = 'BLENDER_EEVEE'
    cam = preview_scene(scene)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(OUT_DIR, f"weapon_{WEAPON}.glb"))
    for ob in set(bpy.data.objects) - before:
        if ob.parent is None:
            mw = ob.matrix_world.copy(); ob.parent = socket; ob.matrix_parent_inverse = Matrix.Identity(4); ob.matrix_basis = mw
    os.makedirs(PREVIEW, exist_ok=True)
    wall = bpy.data.objects["preview_wall"]
    if "--render" in ARGS:
        rig.animation_data.action = ACTIONS["hero_idle"]; scene.frame_set(1)
        for name, yaw, pitch in (("front", 0, 8), ("three_quarter", 35, 16), ("side", 90, 8), ("back", 160, 10), ("top", 20, 60)):
            wall.hide_render = yaw > 120
            still(cam, f"rest_{name}.png", yaw, pitch)
        wall.hide_render = False
        still(cam, "rest_head.png", 30, 10, 1.4, (0, 0, .74))
        rig.animation_data.action = ACTIONS["hero_walk"]
        for f in (1, 5, 9, 13):
            scene.frame_set(f); still(cam, f"run_{f:02d}.png", 70, 8)
        rig.animation_data.action = ACTIONS["hero_death"]; scene.frame_set(31)
        still(cam, "death_31.png", 70, 20, 3.2, (0, -.1, .3))
    if "--video" in ARGS:
        video(cam, "run.mp4", ACTIONS["hero_walk"], 64, (30, 150))
        video(cam, "idle.mp4", ACTIONS["hero_idle"], 96, (30, 60))
        video(cam, "death.mp4", ACTIONS["hero_death"], 45, (60, 75))

bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
print("saved", OUT_GLB)
