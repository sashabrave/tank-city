"""v6 props in the cat-army low-poly style (shared palette, one surface each).

Run: Blender -b --factory-startup --python tools/build_props_v6.py -- [--render] [--only name]
  concrete_statue  indestructible block: two bronze cat generals with banners (0.96 footprint)
  tarp_*           cargo under tarps for the arena surroundings
"""
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v6_common import Kit, D, preview_scene, still, rounded_rect

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREVIEW = os.path.join(ROOT, "tmp/props_v6")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = ARGS[ARGS.index("--only") + 1] if "--only" in ARGS else None
RZ = lambda a: Matrix.Rotation(D(a), 3, 'Z')
RX = lambda a: Matrix.Rotation(D(a), 3, 'X')
BUILT = []


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    hard = Kit(scene, "V6_palette_fabric", emissive=True, soft=False)
    soft = Kit(scene, soft=True, share=hard)
    return scene, hard, soft


def export(scene, kits, name, folder, flip=None):
    tris = sum(k.tris() for k in kits)
    parts = [ob for k in kits for ob, _ in k.parts]
    # Hub props face the camera (+Z in Godot = -Y here); visuals.gd only turns bench_* round itself.
    if flip is None: flip = name in ("printer", "command_center", "gate", "parking", "crate", "supply_stack", "hq_supplies", "recycler")
    if flip:
        for ob in parts: ob.data.transform(Matrix.Rotation(math.pi, 4, 'Z'))
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts: ob.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object; ob.name = ob.data.name = name
    if folder:
        os.makedirs(folder, exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(folder, name + ".glb"), use_selection=True, export_yup=True, export_animations=False)
    print(f"PROP {name}: {tris} tris")
    BUILT.append((name, scene, ob))
    return ob


def banner(k, pole_base, height, width, drop, cell="flag", phase=0.0):
    """Static waving banner on a pole: a rippled double-sided sheet with a light hoist stripe."""
    k.cylinder("pole", pole_base, Vector(pole_base) + Vector((0, 0, height)), .014, "gun", sides=6)
    k.ellipsoid("finial", Vector(pole_base) + Vector((0, 0, height + .02)), (.024, .024, .03), "gold", seg=6, rings=3)
    bm = bmesh.new(); cols, rows = 6, 3; grid = []
    top = Vector(pole_base) + Vector((0, 0, height - .03))
    for r in range(rows + 1):
        row = []
        for c in range(cols + 1):
            u, v = c / cols, r / rows
            y = -u * width
            x = math.sin(u * 5.0 + phase) * .035 * u
            z = -v * drop - u * u * .04
            row.append(bm.verts.new(top + Vector((x, y, z))))
        grid.append(row)
    for r in range(rows):
        for c in range(cols):
            bm.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))
    dup = bmesh.ops.duplicate(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:])
    bmesh.ops.reverse_faces(bm, faces=[g for g in dup["geom"] if isinstance(g, bmesh.types.BMFace)])
    for v in (g for g in dup["geom"] if isinstance(g, bmesh.types.BMVert)): v.co.x -= .003
    k.finish(bm, "banner", cell, None, smooth=60, face_cell=lambda p: "desk" if (top.y - p.center.y) < width * .15 else cell)


def cat_general(k, h, base, facing=0, pose="point"):
    """Bronze cat general: long coat, peaked cap, ears, one arm pointing or holding a sword."""
    b = Vector(base)
    R = RZ(facing)
    P = lambda v: b + R @ Vector(v)
    for s in (-1, 1):
        k.cylinder("boot", P((s * .045, 0, 0)), P((s * .045, .01, .12)), .04, "bronze", sides=6)
    k.cylinder("coat", P((0, 0, .09)), P((0, 0, .36)), .12, "bronze", radius_b=.085, sides=8, smooth=50)
    k.ellipsoid("chest", P((0, .01, .36)), (.1, .08, .08), "bronze", seg=8, rings=4)
    for s in (-1, 1):
        k.ellipsoid("epaulette", P((s * .09, 0, .41)), (.04, .035, .02), "gold", seg=6, rings=3)
    k.ellipsoid("head", P((0, .01, .5)), (.085, .08, .075), "bronze", seg=8, rings=5)
    k.ellipsoid("muzzle", P((0, .075, .48)), (.04, .025, .025), "bronze", seg=6, rings=3)
    for s in (-1, 1):  # ears through the cap
        base_e = P((s * .05, -.005, .56)); tip = P((s * .075, 0, .64))
        k.cylinder("ear", base_e, tip, .026, "bronze", radius_b=.004, sides=4, smooth=20)
    k.cylinder("cap", P((0, 0, .555)), P((0, 0, .6)), .075, "bronze", radius_b=.085, sides=8)
    k.rbox("visor", P((0, .07, .555)), (.1, .05, .012), "bronze", bevel=.004, rot=R @ RX(-12))
    k.rbox("cap_band", P((0, .082, .575)), (.06, .006, .012), "gold", bevel=.002)
    # arms: one points ahead (or rests on a sword), the other on the hip
    if pose == "point":
        k.tube("arm", [P((.09, 0, .42)), P((.13, .08, .47)), P((.15, .2, .5))], [.03, .026, .022], "bronze", sides=5)
        k.ellipsoid("paw", P((.15, .22, .5)), (.025, .025, .025), "bronze", seg=5, rings=3)
    else:
        k.tube("arm", [P((.09, 0, .42)), P((.11, .06, .32)), P((.06, .1, .26))], [.03, .026, .022], "bronze", sides=5)
        k.cylinder("sword", P((.06, .11, .0)), P((.06, .11, .28)), .008, "gold", sides=4)
    k.tube("arm_l", [P((-.09, 0, .42)), P((-.13, -.01, .33)), P((-.08, .03, .28))], [.03, .026, .022], "bronze", sides=5)
    k.tube("tail", [P((0, -.1, .14)), P((.05, -.18, .1)), P((.12, -.2, .14))], [.025, .022, .018], "bronze", sides=5)


def statue():
    scene, hard, soft = fresh()
    hard.rbox("plinth", (0, 0, .06), (.94, .94, .12), "stone", bevel=.02)
    hard.rbox("steps", (0, .02, .15), (.86, .86, .06), "stone", bevel=.015)
    hard.rbox("block", (0, 0, .31), (.72, .72, .28), "marble", bevel=.02)
    hard.rbox("cornice", (0, 0, .465), (.8, .8, .04), "stone", bevel=.012)
    hard.rbox("plaque", (0, .362, .31), (.3, .012, .11), "bronze", bevel=.004)
    hard.rbox("plaque_star", (0, .37, .31), (.05, .006, .05), "gold", bevel=.002, rot=RX(0) @ Matrix.Rotation(D(45), 3, 'Y'))
    for s in (-1, 1):
        hard.rbox("wreath", (s * .362, 0, .31), (.012, .16, .1), "bronze", bevel=.004)
    cat_general(soft, .6, (-.13, .06, .485), facing=12, pose="point")
    cat_general(soft, .6, (.13, -.02, .485), facing=-10, pose="sword")
    top = Vector((0, 0, .485))
    grow = Matrix.Translation(top) @ Matrix.Scale(1.3, 4) @ Matrix.Translation(-top)
    for ob, _ in soft.parts: ob.data.transform(grow)
    banner(hard, (-.34, -.3, .485), 1.25, .46, .3, "flag", .0)
    banner(hard, (.34, -.3, .485), 1.25, .46, .3, "band", 1.3)
    export(scene, [hard, soft], "concrete_statue", os.path.join(ROOT, "assets/models/concrete_v1"))


def tarp_pile(variant):
    """Cargo under a tarp: a draped height field over hidden crates, hem on the ground, straps."""
    scene, hard, soft = fresh()
    rng = random.Random(4100 + variant)
    w, d = ((1.3, .85), (1.7, .95), (.95, .9))[variant]
    boxes = []
    for _ in range(3 + variant % 2 * 2):
        bw, bd, bh = rng.uniform(.3, .55), rng.uniform(.3, .5), rng.uniform(.3, .62)
        cx, cy = rng.uniform(-w / 2 + bw / 2, w / 2 - bw / 2), rng.uniform(-d / 2 + bd / 2, d / 2 - bd / 2)
        boxes.append((cx, cy, bw, bd, bh))
    nx, ny = 11, 8
    H = [[.02] * (nx + 1) for _ in range(ny + 1)]
    for j in range(ny + 1):
        for i in range(nx + 1):
            x, y = -w / 2 + w * i / nx, -d / 2 + d * j / ny
            for cx, cy, bw, bd, bh in boxes:
                if abs(x - cx) <= bw / 2 + .04 and abs(y - cy) <= bd / 2 + .04: H[j][i] = max(H[j][i], bh + .03)
    for _ in range(2):  # drape: soften between crates, keep the hem on the ground
        H = [[(H[j][i] * 2 + sum(H[jj][ii] for jj, ii in ((j - 1, i), (j + 1, i), (j, i - 1), (j, i + 1)) if 0 <= jj <= ny and 0 <= ii <= nx) / 4 * 2) / 4
              if 0 < i < nx and 0 < j < ny else .015 for i in range(nx + 1)] for j in range(ny + 1)]
    bm = bmesh.new()
    V = [[bm.verts.new((-w / 2 + w * i / nx + rng.uniform(-.012, .012), -d / 2 + d * j / ny + rng.uniform(-.012, .012), H[j][i] + rng.uniform(0, .015)))
          for i in range(nx + 1)] for j in range(ny + 1)]
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((V[j][i], V[j][i + 1], V[j + 1][i + 1], V[j + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.z < 0: f.normal_flip()
    CO = [[v.co.copy() for v in row] for row in V]
    hard.finish(bm, "tarp", "tarp", None, smooth=35,
                face_cell=lambda p: "tarp_dark" if math.sin(p.center.x * 9 + p.center.y * 5) + math.sin(p.center.y * 11 - p.center.x * 3) > .7 else "tarp")
    for k in range(2 + variant % 2):  # tie-down straps across the pile
        x = -w / 3 + k * (2 * w / 3) / max(1, 1 + variant % 2)
        i = max(1, min(nx - 1, round((x + w / 2) / w * nx)))
        pts = [CO[j][i] + Vector((0, 0, .012)) for j in range(ny + 1)]
        for a0, b0 in zip(pts, pts[1:]): hard.cylinder("strap", a0, b0, .01, "strap", sides=4, caps=False)
    for cx, cy, bw, bd, bh in boxes[:1]:  # one crate corner peeks out
        hard.rbox("crate", (cx + bw * .35, cy - bd * .45, .09), (.18, .12, .18), "furniture", bevel=.012)
    export(scene, [hard, soft], f"tarp_{variant}", os.path.join(ROOT, "assets/models/environment_v7"))


def chest(tier):
    """Reward chests by rank: 0 ammo crate, 1 army footlocker, 2 armoured case, 3 commander's strongbox."""
    scene, hard, soft = fresh()
    if tier == 0:
        hard.rbox("box", (0, 0, .2), (.72, .46, .36), "wood", bevel=.02)
        for x in (-.36, .36): hard.rbox("end", (x, 0, .2), (.03, .48, .38), "furniture", bevel=.008)
        for y in (-.231, .231):
            for z in (.1, .3): hard.rbox("plank", (0, y, z), (.66, .012, .012), "canvas_dark", bevel=.002)
        hard.rbox("lid", (0, 0, .4), (.74, .48, .05), "furniture", bevel=.012)
        for x in (-.37, .37): hard.band("rope", Vector((x + (.02 if x > 0 else -.02), 0, .26)), .04, .012, "canvas", axis=(1, 0, 0), sides=6)
        hard.rbox("stencil", (0, .235, .22), (.2, .004, .07), "desk", bevel=.001)
    elif tier == 1:
        hard.rbox("body", (0, 0, .2), (.78, .5, .36), "hull", bevel=.035)
        hard.rbox("lid", (0, 0, .42), (.8, .52, .1), "hull", bevel=.04)
        for x in (-.22, .22):
            hard.band("strap", Vector((x, 0, .25)), .27, .05, "band", axis=(1, 0, 0), sides=8, scale_y=1.0)
        for x in (-.3, .3): hard.rbox("latch", (x, .262, .36), (.06, .02, .07), "steel", bevel=.006)
        for x in (-.4, .4): hard.rbox("handle", (x, 0, .28), (.03, .16, .03), "gun", bevel=.008)
        hard.rbox("plate", (0, .258, .2), (.18, .01, .09), "desk", bevel=.003)
    elif tier == 2:
        hard.rbox("body", (0, 0, .22), (.82, .54, .4), "gun_light", bevel=.04)
        hard.rbox("lid", (0, 0, .47), (.86, .58, .1), "gun", bevel=.035)
        hard.rbox("trim", (0, 0, .41), (.87, .59, .03), "gold", bevel=.008)
        for x in (-.4, .4):
            for y in (-.27, .27): hard.rbox("corner", (x, y, .22), (.07, .07, .42), "gold", bevel=.012)
        for k in range(5): hard.rbox("hazard", (-.24 + k * .12, .276, .12), (.06, .01, .08), "hazard" if k % 2 == 0 else "gun", bevel=.002, rot=Matrix.Rotation(D(25), 3, 'Y'))
        hard.rbox("lock", (0, .29, .36), (.12, .03, .1), "steel", bevel=.01)
        hard.rbox("lock_led", (0, .307, .385), (.03, .006, .02), "screen_amber", bevel=.002)
    else:
        hard.rbox("body", (0, 0, .26), (.96, .66, .48), "hull_dark", bevel=.05)
        hard.rbox("lid", (0, 0, .56), (1.0, .7, .13), "hull_dark", bevel=.05)
        hard.rbox("trim", (0, 0, .49), (1.01, .71, .035), "gold", bevel=.01)
        for x in (-.47, .47):
            for y in (-.32, .32): hard.rbox("corner", (x, y, .26), (.09, .09, .5), "gold", bevel=.015)
        hard.cylinder("emblem", (0, .33, .3), (0, .345, .3), .12, "gold", sides=10)
        soft.ellipsoid("paw", (0, .352, .28), (.045, .012, .04), "hull_dark", seg=6, rings=3)
        for dx, dz in ((-.055, .06), (0, .085), (.055, .06)):
            soft.ellipsoid("toe", (dx, .352, .3 + dz), (.018, .01, .018), "hull_dark", seg=5, rings=3)
        for x in (-.2, .2): hard.rbox("wheel_lock", (x, .345, .5), (.1, .02, .06), "steel", bevel=.008)
        for x in (-.5, .5): hard.rbox("handle", (x, 0, .34), (.035, .2, .035), "gold", bevel=.01)
    export(scene, [hard, soft], f"chest_{tier}", os.path.join(ROOT, "assets/models/chests_v6"))


ENV = os.path.join(ROOT, "assets/models/environment_v7")
GUN = lambda p: "gun"
STEEL = lambda p: "steel"


def desk(k, w, d, h=.42, top="desk", legs="hull_dark", y=0.0):
    k.rbox("desk_top", (0, y, h), (w, d, .04), top, bevel=.01)
    for x in (-w / 2 + .09, w / 2 - .09):
        k.rbox("cabinet", (x, y, h / 2), (.16, d * .9, h - .02), "hull", bevel=.012)
        k.rbox("drawer", (x, y + d * .45, h * .62), (.12, .012, .03), "band", bevel=.003)


def monitor(k, c, w, h, cell="screen", tilt=-8, lines=True):
    c = Vector(c)
    k.rbox("bezel", c, (w + .03, .03, h + .03), "gun", bevel=.008, rot=RX(tilt))
    k.rbox("screen", c + Vector((0, .018, 0)), (w, .006, h), cell, bevel=.002, rot=RX(tilt))
    if lines:  # a few dark bars read as charts / map lines
        for i in range(3):
            k.rbox("chart", c + Vector((-w * .3 + i * w * .3, .022, -h * .15 + i * h * .12)), (w * .22, .004, .008), "gun_light", bevel=.001, rot=RX(tilt))
    k.cylinder("stand", c - Vector((0, 0, h / 2 + .01)), c - Vector((0, 0, h / 2 + .07)), .012, "metal", sides=6, face_cell=GUN)


def bench_headquarters():
    scene, k, soft = fresh(); k.add_special("metal", metal_mat(k))
    desk(k, 1.12, .6)
    monitor(k, (0, -.12, .7), .42, .26)
    for s in (-1, 1): monitor(k, (s * .4, -.08, .64), .22, .16, cell="screen" if s < 0 else "screen_amber", lines=s < 0)
    for i in range(6): k.rbox("key", (-.25 + i * .1, .15, .445), (.07, .05, .012), "gun_light" if i != 3 else "screen_amber", bevel=.003)
    soft.cylinder("mug", (.42, .12, .44), (.42, .12, .5), .025, "band", sides=8)
    k.rbox("chair_seat", (0, .5, .3), (.3, .28, .05), "canvas_dark", bevel=.02)
    k.rbox("chair_back", (0, .63, .48), (.3, .04, .3), "canvas_dark", bevel=.02)
    k.cylinder("chair_post", (0, .5, .06), (0, .5, .28), .02, "metal", sides=6, face_cell=GUN)
    k.rbox("side_crate", (.66, -.02, .16), (.2, .3, .32), "hull", bevel=.02)
    export(scene, [k, soft], "bench_headquarters", ENV)


def bench_weapons():
    scene, k, soft = fresh(); k.add_special("metal", metal_mat(k))
    desk(k, 1.12, .6)
    k.rbox("vise", (-.1, 0, .5), (.14, .1, .1), "metal", bevel=.012, face_cell=STEEL)
    k.rbox("mg_body", (-.1, 0, .6), (.08, .36, .08), "gun", bevel=.012)
    k.cylinder("mg_barrel", (-.1, .16, .6), (-.1, .42, .6), .014, "metal", sides=6, face_cell=GUN)
    k.rbox("mg_box", (-.03, -.02, .57), (.06, .08, .06), "furniture", bevel=.01)
    monitor(k, (.36, -.12, .66), .26, .18, cell="screen", lines=True)
    for x in (-.4, -.3): k.rbox("ammo", (x, .12, .47), (.07, .1, .06), "furniture", bevel=.01)
    k.rbox("pegboard", (0, -.3, .78), (.9, .03, .5), "hull_dark", bevel=.01)
    for i, x in enumerate((-.35, -.18, .05, .22)):
        k.rbox("rifle_rack", (x, -.28, .8), (.04, .02, .36 - (i % 2) * .08), "gun", bevel=.005)
    export(scene, [k, soft], "bench_weapons", ENV)


def bench_bonuses():
    scene, k, soft = fresh(); k.add_special("metal", metal_mat(k))
    desk(k, 1.12, .6)
    k.rbox("pegboard", (0, -.3, .8), (1.0, .03, .56), "hull_dark", bevel=.01)
    k.rbox("lamp_strip", (0, -.27, 1.06), (.6, .03, .025), "lamp", bevel=.006)
    for x, h in ((-.36, .22), (-.24, .28), (-.1, .18), (.06, .24), (.2, .2)):
        k.rbox("tool", (x, -.28, .78), (.028, .015, h), "metal", bevel=.004, face_cell=STEEL)
        k.rbox("tool_head", (x, -.28, .78 + h / 2), (.07, .016, .03), "band" if x > 0 else "metal", bevel=.004, face_cell=None if x > 0 else STEEL)
    # small robot arm on the desk
    k.cylinder("arm_base", (-.4, .05, .44), (-.4, .05, .5), .06, "gun", sides=8)
    k.cylinder("arm_1", (-.4, .05, .5), (-.34, .08, .68), .022, "metal", sides=6, face_cell=STEEL)
    soft.ellipsoid("joint", (-.34, .08, .68), (.035, .035, .035), "band", seg=6, rings=4)
    k.cylinder("arm_2", (-.34, .08, .68), (-.2, .16, .6), .018, "metal", sides=6, face_cell=STEEL)
    k.rbox("gripper", (-.19, .17, .57), (.05, .03, .05), "gun", bevel=.008)
    k.rbox("part", (.15, .1, .47), (.14, .1, .06), "furniture", bevel=.01)
    export(scene, [k, soft], "bench_bonuses", ENV)


def bench_character():
    scene, k, soft = fresh(); k.add_special("metal", metal_mat(k)); k.add_special("helmet", k.material("V6_helmet_white", "dcd6c6", .6))
    k.rbox("plinth", (0, 0, .05), (1.0, .7, .1), "hull_dark", bevel=.02)
    k.cylinder("stand", (-.15, 0, .1), (-.15, 0, .6), .02, "metal", sides=6, face_cell=GUN)
    soft.rbox("torso", (-.15, 0, .72), (.3, .2, .28), "camo_a", bevel=.06)
    soft.rbox("vest", (-.15, .01, .74), (.32, .23, .2), "vest", bevel=.04)
    soft.ellipsoid("helmet", (-.15, 0, .98), (.16, .16, .14), "helmet", seg=12, rings=7)
    for s in (-1, 1):
        k.cylinder("ear", (-.15 + s * .09, 0, 1.05), (-.15 + s * .12, 0, 1.15), .03, "helmet", radius_b=.004, sides=4, smooth=20)
    monitor(k, (.3, -.05, .62), .24, .2, cell="screen", lines=True)
    k.rbox("console", (.3, .05, .3), (.34, .3, .4), "hull", bevel=.02)
    k.rbox("cross", (.3, .205, .34), (.08, .006, .025), "glow_red", bevel=.002)
    k.rbox("cross_v", (.3, .205, .34), (.025, .006, .08), "glow_red", bevel=.002)
    export(scene, [k, soft], "bench_character", ENV)


def bench_mechanic():
    scene, k, soft = fresh(); k.add_special("metal", metal_mat(k))
    k.rbox("stand", (-.15, 0, .2), (.4, .3, .4), "hull_dark", bevel=.02)
    k.rbox("engine", (-.15, 0, .52), (.36, .28, .24), "metal", bevel=.03, face_cell=GUN)
    for i in range(3): k.cylinder("cyl", (-.28 + i * .13, 0, .64), (-.28 + i * .13, 0, .7), .04, "metal", sides=6, face_cell=STEEL)
    k.rbox("cart", (.35, .05, .3), (.3, .3, .5), "band", bevel=.03)
    for z in (.2, .35): k.rbox("cart_drawer", (.35, .205, z), (.24, .01, .01), "gun", bevel=.002)
    export(scene, [k, soft], "bench_mechanic", ENV)


def printer():
    scene, k, soft = fresh(); k.add_special("metal", metal_mat(k))
    k.cylinder("base", (0, 0, 0), (0, 0, .12), .58, "concrete_dark", sides=12)
    k.cylinder("pad", (0, 0, .12), (0, 0, .16), .44, "gun_light", sides=12)
    k.rbox("step", (0, .56, .06), (.5, .2, .12), "concrete_dark", bevel=.01)
    for i in range(4):
        a = D(45 + 90 * i)
        c = Vector((math.cos(a) * .45, math.sin(a) * .45, 0))
        k.rbox("post", c + Vector((0, 0, .85)), (.09, .09, 1.4), "hull_light", bevel=.02)
        k.rbox("post_lamp", c * 1.03 + Vector((0, 0, 1.1)), (.05, .05, .2), "screen", bevel=.01)
    k.cylinder("crown", (0, 0, 1.5), (0, 0, 1.64), .6, "hull_light", sides=12)
    k.cylinder("crown_ring", (0, 0, 1.46), (0, 0, 1.5), .52, "screen", sides=12)
    k.cylinder("crown_lamp", (0, 0, 1.64), (0, 0, 1.7), .12, "screen_amber", sides=8)
    for s in (-1, 1):
        k.cylinder("pipe", (s * .6, -.2, .1), (s * .6, -.2, 1.45), .035, "metal", sides=6, face_cell=STEEL)
    k.rbox("terminal", (.72, .25, .5), (.18, .14, .7), "hull", bevel=.02)
    monitor(k, (.72, .33, .78), .13, .1, cell="screen", lines=False)
    ob = export(scene, [k, soft], "printer", None)
    # ScanRing: separate node that printer_intro.gd moves up and down.
    scene2 = bpy.context.scene
    r = Kit(scene2, share=k, soft=False)
    r.band("ring", Vector((0, 0, 0)), .5, .05, "screen", sides=16)
    ring = r.join("ScanRing"); ring.location = (0, 0, .3)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=os.path.join(ENV, "printer.glb"), use_selection=True, export_yup=True, export_animations=False)


def command_center():
    """Main hub screen: a tall portrait monolith. The screen is its own node (CommandScreen) with
    0..1 UVs; hub.gd drives it with shaders/world/command_screen.gdshader (idle pages / turquoise alert)."""
    scene, k, soft = fresh(); k.add_special("metal", metal_mat(k))
    k.rbox("plinth", (0, 0, .07), (1.5, .8, .14), "concrete_dark", bevel=.03)
    k.rbox("frame", (0, -.05, 1.3), (1.3, .26, 2.3), "hull_dark", bevel=.05)
    k.rbox("bezel_top", (0, .09, 2.38), (1.24, .04, .1), "gun", bevel=.01)
    for s_ in (-1, 1):
        k.rbox("side_rib", (s_ * .66, .03, 1.3), (.06, .2, 2.2), "metal", bevel=.01, face_cell=STEEL)
        k.rbox("side_lamp", (s_ * .69, .08, 2.1), (.03, .05, .2), "screen", bevel=.006)
    k.rbox("console", (0, .38, .42), (1.0, .34, .12), "hull", bevel=.03)
    k.rbox("console_top", (0, .42, .5), (1.02, .3, .04), "desk", bevel=.01, rot=RX(10))
    for i in range(6): k.rbox("key", (-.38 + i * .15, .46, .525), (.1, .07, .014), "gun_light" if i % 2 else "screen_amber", bevel=.003, rot=RX(10))
    for s_ in (-1, 1): k.rbox("console_leg", (s_ * .4, .38, .2), (.08, .2, .36), "hull_dark", bevel=.01)
    k.cylinder("mast", (.5, -.15, 2.45), (.5, -.15, 3.1), .025, "metal", sides=6, face_cell=GUN)
    k.ellipsoid("mast_lamp", (.5, -.15, 3.13), (.03, .03, .03), "glow_red", seg=6, rings=3)
    soft.ellipsoid("dish", (-.35, -.12, 2.62), (.2, .06, .2), "hull_light", seg=10, rings=4)
    for i in range(4):
        soft.ellipsoid("sandbag", (-.55 + i * .3, -.32, .22), (.15, .09, .07), "canvas", seg=6, rings=3)
    export(scene, [k, soft], "command_center", None, flip=True)
    # Screen quad with its own UVs (front face, flipped like the rest).
    me = bpy.data.meshes.new("CommandScreen")
    w, h, y, z0 = 1.08, 2.0, .082, .32
    me.from_pydata([(-w / 2, y, z0), (w / 2, y, z0), (w / 2, y, z0 + h), (-w / 2, y, z0 + h)], [], [(0, 1, 2, 3)])
    uv = me.uv_layers.new(name="UVMap").data
    for li, c in enumerate(((0, 0), (1, 0), (1, 1), (0, 1))): uv[li].uv = c
    me.transform(Matrix.Rotation(math.pi, 4, 'Z'))
    me.materials.append(k.material("V6_command_screen", "0b1210", .4))
    ob = bpy.data.objects.new("CommandScreen", me); bpy.context.scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=os.path.join(ENV, "command_center.glb"), use_selection=True, export_yup=True, export_animations=False)


def gate():
    scene, k, soft = fresh(); k.add_special("metal", metal_mat(k))
    for s in (-1, 1):
        k.rbox("pillar", (s * .68, 0, .75), (.34, .4, 1.5), "concrete", bevel=.03)
        k.rbox("pillar_lamp", (s * .68, .205, 1.15), (.1, .02, .14), "screen_amber", bevel=.01)
        for i in range(3): k.rbox("stripe", (s * .68, .205, .2 + i * .16), (.3, .012, .06), "hazard" if i % 2 == 0 else "gun", bevel=.003)
    k.rbox("lintel", (0, 0, 1.6), (1.72, .44, .24), "concrete", bevel=.03)
    k.rbox("lintel_band", (0, .225, 1.6), (1.2, .012, .06), "hazard", bevel=.003)
    k.rbox("shutter", (0, -.12, 1.42), (1.0, .06, .16), "metal", bevel=.01, face_cell=STEEL)
    export(scene, [k, soft], "gate", ENV)


def parking():
    scene, k, soft = fresh()
    k.rbox("pad", (0, 0, .01), (1.3, 1.6, .02), "concrete_dark", bevel=.004)
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.rbox("corner_a", (sx * .58, sy * .7, .024), (.14, .03, .006), "hazard", bevel=.001)
            k.rbox("corner_b", (sx * .64, sy * .64, .024), (.03, .14, .006), "hazard", bevel=.001)
    for sx in (-1, 1): k.rbox("wheel_stop", (sx * .3, -.72, .04), (.3, .08, .06), "concrete", bevel=.015)
    export(scene, [k, soft], "parking", ENV)


def crate():
    scene, k, soft = fresh(); k.add_special("metal", metal_mat(k))
    for c, sz, cell in (((-.12, 0, .16), (.42, .34, .32), "hull"), ((.2, .05, .12), (.26, .26, .24), "furniture")):
        k.rbox("crate", c, sz, cell, bevel=.02)
        k.rbox("crate_band", c, (sz[0] + .01, sz[1] * .2, sz[2] + .01), "hull_dark", bevel=.004)
        k.rbox("stencil", (c[0], c[1] + sz[1] / 2 + .003, c[2]), (sz[0] * .4, .004, .05), "desk", bevel=.001)
    export(scene, [k, soft], "crate", ENV)


def supply_stack():
    scene, k, soft = fresh(); k.add_special("metal", metal_mat(k))
    k.rbox("pallet", (0, 0, .04), (.8, .6, .08), "wood", bevel=.01)
    k.rbox("crate_a", (-.18, 0, .25), (.38, .5, .34), "hull", bevel=.025)
    k.rbox("crate_b", (-.18, 0, .52), (.32, .4, .2), "furniture", bevel=.02)
    for i, (x, y) in enumerate(((.2, -.12), (.2, .14))):
        k.cylinder("barrel", (x, y, .08), (x, y, .5), .12, "band" if i else "hull_dark", sides=10)
        k.band("barrel_rib", Vector((x, y, .3)), .122, .02, "metal", sides=10)
    export(scene, [k, soft], "supply_stack", ENV)


def hq_supplies():
    scene, k, soft = fresh()
    k.rbox("pallet", (0, 0, .04), (.9, .9, .08), "wood", bevel=.01)
    k.rbox("med_box", (-.12, -.1, .3), (.5, .4, .42), "desk", bevel=.03)
    k.rbox("cross_h", (-.12, .105, .32), (.16, .006, .05), "glow_red", bevel=.002)
    k.rbox("cross_v", (-.12, .105, .32), (.05, .006, .16), "glow_red", bevel=.002)
    k.rbox("case", (.25, .15, .18), (.3, .3, .2), "hull", bevel=.02)
    k.rbox("case_strap", (.25, .15, .18), (.31, .06, .21), "band", bevel=.004)
    export(scene, [k, soft], "hq_supplies", ENV)


def recycler():
    """Small abstract bin: tapered body, lid with a slot, one recycle band."""
    scene, k, soft = fresh(); k.add_special("metal", metal_mat(k))
    k.cylinder("body", (0, 0, 0), (0, 0, .5), .24, "hull", sides=8, radius_b=.27)
    k.cylinder("lid", (0, 0, .5), (0, 0, .56), .29, "hull_light", sides=8)
    k.rbox("slot", (0, 0, .565), (.24, .06, .01), "gun", bevel=.003)
    k.band("stripe", Vector((0, 0, .3)), .262, .07, "screen", sides=8)
    k.cylinder("foot", (0, 0, 0), (0, 0, .03), .3, "hazard", sides=8)
    export(scene, [k, soft], "recycler", ENV)


def metal_mat(k):
    m = k.material("V6_metal", "8a9196", .38, metallic=.85)
    tex = next(n for n in k.pal.node_tree.nodes if n.type == 'TEX_IMAGE')
    t = m.node_tree.nodes.new("ShaderNodeTexImage"); t.image = tex.image; t.interpolation = 'Closest'
    m.node_tree.links.new(t.outputs["Color"], m.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    return m


PROPS = {"bench_headquarters": bench_headquarters, "bench_weapons": bench_weapons, "bench_bonuses": bench_bonuses,
         "bench_character": bench_character, "bench_mechanic": bench_mechanic, "printer": printer,
         "command_center": command_center, "gate": gate, "parking": parking, "crate": crate,
         "supply_stack": supply_stack, "hq_supplies": hq_supplies, "recycler": recycler,
         "chest_0": lambda: chest(0), "chest_1": lambda: chest(1), "chest_2": lambda: chest(2), "chest_3": lambda: chest(3),
         "concrete_statue": statue, "tarp_0": lambda: tarp_pile(0), "tarp_1": lambda: tarp_pile(1), "tarp_2": lambda: tarp_pile(2)}
for name, fn in PROPS.items():
    if ONLY and name != ONLY: continue
    fn()
    if "--render" in ARGS:
        scene = bpy.context.scene
        cam = preview_scene(scene, lens=50, res=560)
        still(scene, cam, os.path.join(PREVIEW, f"{name}.png"), 30, 22, 3.4, (0, 0, .6))
