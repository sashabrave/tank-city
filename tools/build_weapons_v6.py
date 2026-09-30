"""v6 weapons sized for chibi cat paws (reference: gunmetal body, olive furniture, orange tag).

Run: Blender -b --factory-startup --python tools/build_weapons_v6.py -- [--render]
Each weapon: Grip at the origin (fist centre), SupportGrip under the fore end,
Muzzle at the barrel tip, +Y forward. ~100-250 triangles, one palette surface.
Writes assets/models/infantry_v6/weapon_<id>.glb and weapons.json (hold points).
"""
import bpy, math, os, sys, json
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v6_common import Kit, D, empty, preview_scene, still, write_palette_json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/models/infantry_v6")
PREVIEW = os.path.join(ROOT, "tmp/infantry_v6")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RX = lambda a: Matrix.Rotation(D(a), 3, 'X')
SCALE = 1.25  # chunky toy proportions: guns read at top-down distance and fill the paws


def handle(k, y=-.004, tilt=14, mat="furniture"):
    k.rbox("handle", (0, y, -.002), (.034, .04, .078), mat, bevel=.01, rot=RX(tilt))
    k.rbox("guard", (0, y + .035, .012), (.012, .03, .006), "gun", bevel=.002)


def tag(k, y, z, side=.024):
    k.rbox("tag", (side, y, z), (.004, .032, .016), "band", bevel=.002)


def pistol(k):
    k.rbox("slide", (0, .045, .046), (.034, .125, .034), "gun", bevel=.008)
    k.rbox("frame", (0, .035, .022), (.03, .1, .02), "gun_light", bevel=.006)
    handle(k, 0, 12)
    k.rbox("sight", (0, .1, .066), (.008, .01, .008), "gun", bevel=.002)
    tag(k, .03, .046, .019)
    return (0, -.004, -.04), (0, .11, .046)


def smg(k):
    k.rbox("receiver", (0, .03, .05), (.044, .16, .058), "gun", bevel=.01)
    k.cylinder("barrel", (0, .1, .055), (0, .2, .055), .011, "gun", sides=6)
    k.cylinder("brake", (0, .19, .055), (0, .225, .055), .016, "gun_light", sides=6)
    k.rbox("mag", (0, .075, -.012), (.026, .034, .1), "gun", bevel=.006, rot=RX(-8))
    handle(k)
    k.rbox("stock_arm", (0, -.1, .045), (.012, .12, .014), "gun", bevel=.003)
    k.rbox("stock_pad", (0, -.16, .03), (.03, .016, .06), "furniture", bevel=.006)
    k.rbox("sight", (0, .02, .088), (.014, .03, .018), "gun", bevel=.004)
    tag(k, .03, .05)
    return (0, .125, .028), (0, .225, .055)


def rifle(k):
    k.rbox("receiver", (0, .03, .052), (.044, .2, .06), "gun", bevel=.01)
    k.rbox("handguard", (0, .18, .054), (.048, .12, .048), "gun", bevel=.012)
    k.cylinder("barrel", (0, .24, .056), (0, .33, .056), .011, "gun", sides=6)
    k.cylinder("brake", (0, .32, .056), (0, .36, .056), .017, "gun_light", sides=6)
    k.rbox("front_sight", (0, .22, .09), (.01, .016, .03), "gun", bevel=.003)
    k.rbox("rear_sight", (0, -.02, .09), (.018, .04, .024), "gun", bevel=.004)
    k.rbox("mag", (0, .075, -.012), (.03, .045, .095), "gun", bevel=.008, rot=RX(-16))
    handle(k)
    k.rbox("stock", (0, -.14, .036), (.04, .16, .07), "furniture", bevel=.014, rot=RX(4))
    tag(k, .04, .052)
    return (0, .175, .026), (0, .362, .056)


def shotgun(k):
    k.rbox("receiver", (0, .02, .05), (.046, .13, .06), "gun", bevel=.01)
    k.cylinder("barrel", (0, .07, .064), (0, .36, .064), .016, "gun", sides=8)
    k.cylinder("tube", (0, .07, .036), (0, .3, .036), .012, "gun", sides=6)
    k.rbox("pump", (0, .19, .036), (.042, .085, .038), "furniture", bevel=.012)
    handle(k)
    k.rbox("stock", (0, -.13, .034), (.044, .16, .074), "furniture", bevel=.014, rot=RX(5))
    tag(k, .02, .05)
    return (0, .19, .012), (0, .362, .064)


def sniper(k):
    k.rbox("receiver", (0, .03, .05), (.042, .2, .05), "gun", bevel=.009)
    k.rbox("forestock", (0, .17, .04), (.046, .15, .04), "furniture", bevel=.012)
    k.cylinder("barrel", (0, .2, .056), (0, .5, .056), .01, "gun", sides=6)
    k.cylinder("brake", (0, .5, .056), (0, .535, .056), .015, "gun_light", sides=6)
    k.rbox("stock", (0, -.16, .034), (.044, .18, .076), "furniture", bevel=.014, rot=RX(4))
    k.cylinder("scope", (0, -.03, .106), (0, .1, .106), .019, "gun", sides=8)
    k.cylinder("scope_bell", (0, .1, .106), (0, .14, .106), .019, "gun", radius_b=.027, sides=8)
    k.cylinder("scope_lens", (0, .139, .106), (0, .142, .106), .022, "band", sides=8)
    for y in (0, .08): k.rbox("mount", (0, y, .082), (.016, .016, .03), "gun", bevel=.003)
    k.rbox("mag", (0, .06, .012), (.028, .04, .04), "gun", bevel=.006)
    handle(k)
    tag(k, .03, .05)
    return (0, .17, .012), (0, .538, .056)


def rpg(k):
    z = .072
    k.cylinder("tube", (0, -.26, z), (0, .2, z), .03, "gun", sides=8)
    k.cylinder("sleeve", (0, -.14, z), (0, .04, z), .033, "furniture", sides=8)
    k.cylinder("flare", (0, -.26, z), (0, -.33, z), .03, "black", radius_b=.056, sides=8, caps=False)
    k.ellipsoid("warhead", (0, .27, z), (.046, .085, .046), "furniture", seg=8, rings=5, smooth=45)
    k.cylinder("nose", (0, .34, z), (0, .4, z), .026, "furniture", radius_b=.006, sides=8)
    k.cylinder("band_ring", (0, .2, z), (0, .215, z), .034, "band", sides=8)
    k.rbox("sight", (-.038, .02, .1), (.014, .03, .04), "gun", bevel=.004)
    handle(k, 0, 10)
    k.rbox("front_grip", (0, .12, .01), (.03, .03, .07), "furniture", bevel=.01, rot=RX(10))
    tag(k, -.06, z, .034)
    return (0, .12, -.01), (0, .4, z)


def mg(k):
    k.rbox("receiver", (0, .03, .056), (.05, .22, .07), "gun", bevel=.012)
    k.cylinder("shroud", (0, .14, .062), (0, .3, .062), .022, "gun_light", sides=8)
    k.cylinder("barrel", (0, .3, .062), (0, .42, .062), .013, "gun", sides=6)
    k.cylinder("brake", (0, .41, .062), (0, .44, .062), .018, "gun", sides=6)
    k.rbox("carry", (0, .06, .106), (.014, .09, .016), "gun", bevel=.004)
    k.rbox("box", (.05, .06, .02), (.05, .07, .075), "furniture", bevel=.012)
    for s in (-1, 1):
        k.rbox("bipod", (s * .014, .33, .02), (.008, .008, .07), "gun", bevel=.002, rot=Matrix.Rotation(D(s * 12), 3, 'Y'))
    handle(k)
    k.rbox("stock", (0, -.15, .04), (.046, .15, .08), "furniture", bevel=.014, rot=RX(4))
    tag(k, .03, .056, .027)
    return (0, .17, .03), (0, .442, .062)


def grenade_launcher(k):
    k.rbox("receiver", (0, .03, .05), (.05, .12, .066), "gun", bevel=.012)
    k.cylinder("barrel", (0, .07, .058), (0, .25, .058), .033, "gun", sides=8)
    k.cylinder("bore_ring", (0, .24, .058), (0, .272, .058), .037, "gun_light", sides=8)
    k.cylinder("bore", (0, .271, .058), (0, .273, .058), .024, "black", sides=8)
    k.rbox("front_grip", (0, .15, .002), (.03, .03, .07), "furniture", bevel=.01, rot=RX(10))
    k.rbox("sight", (0, .1, .1), (.012, .03, .026), "gun", bevel=.004)
    handle(k)
    k.rbox("stock", (0, -.13, .036), (.046, .15, .074), "furniture", bevel=.014, rot=RX(4))
    tag(k, .03, .05, .027)
    return (0, .15, -.01), (0, .273, .058)


WEAPONS = {"pistol": pistol, "smg": smg, "rifle": rifle, "shotgun": shotgun, "sniper": sniper,
           "rpg": rpg, "mg": mg, "grenade_launcher": grenade_launcher}

os.makedirs(OUT, exist_ok=True)
write_palette_json(os.path.join(OUT, "palette.json"))
points = {}
report = []
for wid, build in WEAPONS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    k = Kit(scene, "V6_weapon_palette", emissive=False, soft=False)
    support, muzzle = build(k)
    support, muzzle = tuple(c * SCALE for c in support), tuple(c * SCALE for c in muzzle)
    tris = k.tris()
    mesh = k.join(f"weapon_{wid}")
    mesh.scale = (SCALE,) * 3
    bpy.ops.object.select_all(action='DESELECT'); mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh; bpy.ops.object.transform_apply(scale=True)
    root = empty(scene, f"Weapon_{wid}", (0, 0, 0))
    mesh.parent = root
    empty(scene, "Grip", (0, 0, 0), root); empty(scene, "SupportGrip", support, root); empty(scene, "Muzzle", muzzle, root)
    points[wid] = {"support": list(support), "muzzle": list(muzzle), "tris": tris}
    report.append(f"{wid}: {tris} tris")
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, f"weapon_{wid}.glb"), use_selection=True, export_yup=True, export_animations=False)
    if "--render" in ARGS:
        cam = preview_scene(scene, lens=60, res=480)
        root.rotation_euler = (0, 0, D(-90)); root.location = (0, 0, .15)
        still(scene, cam, os.path.join(PREVIEW, f"weapon_{wid}.png"), 20, 16, .8, (.1, 0, .18))
with open(os.path.join(OUT, "weapons.json"), "w") as f:
    json.dump(points, f, indent=1)
print("WEAPONS", "; ".join(report))
