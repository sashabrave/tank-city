"""v6 vehicles in the cat-army style: tank, APC, buggy, ground drone, quad drone, boss tank.

Run: Blender -b --factory-startup --python tools/build_vehicles_v6.py -- [--render] [--only tank]
Two surfaces per model: V6_hull_paint (team paint via kit_model.set_paint: olive for us,
rank colours for enemies) and the shared v6 palette (beige panels, rubber, steel, lamps).
Node names follow kit_v4 so kit_model.gd keeps working: *_yaw, *_pitch, *recoil*,
*_wheel_*, *_rotor_*, *_beacon, boss_main_yaw. HeadlightMount* empties carry the beams.
Authored +Y forward, Z up, sizes close to kit_v4 (visuals.gd keeps the same scales).
"""
import bpy, math, os, sys
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v6_common import Kit, D, empty, preview_scene, still, rounded_rect

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/models/vehicles_v6")
PREVIEW = os.path.join(ROOT, "tmp/vehicles_v6")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = ARGS[ARGS.index("--only") + 1] if "--only" in ARGS else None
RX = lambda a: Matrix.Rotation(D(a), 3, 'X')
RY = lambda a: Matrix.Rotation(D(a), 3, 'Y')
RZ = lambda a: Matrix.Rotation(D(a), 3, 'Z')


class Model:
    def __init__(self, kind):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.scene = bpy.context.scene
        self.kind = kind
        self.base = Kit(self.scene, "V6_palette_fabric", emissive=True, soft=False)
        self.base.add_special("paint", self.base.material("V6_hull_paint", "7a8062", .6))
        self.root = empty(self.scene, kind.upper(), (0, 0, 0))
        self.tris = 0

    def kit(self):
        return Kit(self.scene, share=self.base, soft=False)

    def pivot(self, name, world, parent=None):
        ob = empty(self.scene, name, world)
        self.attach(ob, parent or self.root)
        return ob

    def attach(self, ob, parent):
        bpy.context.view_layer.update()
        mw = ob.matrix_world.copy()
        ob.parent = parent
        ob.matrix_world = mw

    def mesh(self, kit, name, parent=None, origin=None):
        self.tris += kit.tris()
        ob = kit.join(name)
        if origin is not None:  # wheels and rotors spin about their own origin
            ob.data.transform(Matrix.Translation(-Vector(origin)))
            ob.location = origin
        self.attach(ob, parent or self.root)
        return ob

    def wheel(self, name, c, r, w, parent=None, hub="gun_light"):
        k = self.kit()
        c = Vector(c)
        ax = Vector((w / 2, 0, 0))
        k.cylinder("tire", c - ax, c + ax, r, "rubber", sides=10, smooth=40)
        k.cylinder("tire_bevel_o", c + ax, c + ax * 1.2, r * .86, "rubber", sides=10, smooth=40)
        k.cylinder("tire_bevel_i", c - ax * 1.2, c - ax, r * .86, "rubber", sides=10, smooth=40)
        s = 1 if c.x > 0 else -1
        k.cylinder("hub", c + Vector((s * w * .6, 0, 0)), c + Vector((s * w * .72, 0, 0)), r * .5, hub, sides=8)
        return self.mesh(k, name, parent, origin=c)

    def lamp(self, c, size=(.05, .02, .035), mount=True, name="HeadlightMount"):
        self.base.rbox("lamp_housing", Vector(c) - Vector((0, .006, 0)), (size[0] * 1.3, size[1], size[2] * 1.3), "gun", bevel=.006)
        self.base.rbox("lamp", Vector(c) + Vector((0, size[1] * .4, 0)), size, "lamp", bevel=.006)
        if mount: self.pivot(f"{name}_{'L' if c[0] < 0 else 'R'}", Vector(c) + Vector((0, .02, 0)))

    def export(self):
        tris = self.tris + self.base.tris()
        if self.base.parts: self.mesh(self.base, f"{self.kind}_body")
        bpy.ops.object.select_all(action='SELECT')
        os.makedirs(OUT, exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, f"{self.kind}.glb"), use_selection=True, export_yup=True, export_animations=False)
        print(f"VEHICLE {self.kind}: {tris} tris")
        return tris


def track(k, x, length, h, z, width=.15, wheels=5, r=.05):
    """Static track: rounded rubber belt, road wheels and a sprocket on the outer face."""
    k.rbox("belt", (x, 0, z), (width, length, h), "rubber", bevel=h * .45)
    s = 1 if x > 0 else -1
    for i in range(wheels):
        y = -length / 2 + r * 1.3 + i * (length - r * 2.6) / (wheels - 1)
        k.cylinder("roadwheel", (x + s * width * .5, y, z - h * .08), (x + s * width * .58, y, z - h * .08), r, "gun_light", sides=8)
        k.cylinder("roadhub", (x + s * width * .58, y, z - h * .08), (x + s * width * .62, y, z - h * .08), r * .45, "hull_dark", sides=6)


# ---------------------------------------------------------------- tank
def tank():
    m = Model("tank"); b = m.base
    hull = [(-.41, .05), (.37, .05), (.43, .13), (.36, .215), (-.37, .215), (-.42, .13)]  # side profile (y, z)
    b.prism("hull", hull, -.27, .27, "paint", axis="x", smooth=30)
    b.rbox("deck", (0, -.02, .228), (.6, .64, .03), "hull_light", bevel=.012)
    b.rbox("glacis_band", (0, .36, .17), (.5, .03, .05), "hull_light", bevel=.01, rot=RX(-40))
    for s in (-1, 1):
        b.rbox("fender", (s * .35, 0, .2), (.17, .84, .025), "paint", bevel=.008)
        track(b, s * .35, .8, .17, .1)
        b.rbox("side_skirt", (s * .44, 0, .15), (.012, .66, .06), "hull_dark", bevel=.004)
        m.lamp((s * .24, .42, .165))
        b.rbox("tow", (s * .16, .43, .08), (.03, .03, .03), "gun", bevel=.006)
    b.rbox("rear_box", (0, -.4, .19), (.3, .05, .06), "hull_dark", bevel=.01)
    b.rbox("exhaust", (.18, -.35, .245), (.07, .06, .03), "gun", bevel=.008)
    yaw = m.pivot("tank_turret_yaw", (0, -.04, .245))
    t = m.kit()
    ring = [(x, y) for x, y in ((-.19, -.19), (.19, -.19), (.24, -.04), (.2, .13), (-.2, .13), (-.24, -.04))]
    t.prism("turret", ring, .245, .38, "paint", smooth=30)
    t.prism("turret_top", [(x * .86, y * .86 - .01) for x, y in ring], .38, .415, "paint", smooth=30)
    t.cylinder("hatch", (-.06, -.09, .415), (-.06, -.09, .435), .065, "hull_light", sides=10)
    t.rbox("hatch_handle", (-.06, -.09, .44), (.05, .008, .01), "gun", bevel=.002)
    t.rbox("periscope", (.09, .02, .43), (.05, .03, .03), "gun", bevel=.006)
    t.rbox("tag", (-.235, -.03, .31), (.012, .13, .07), "band", bevel=.004, rot=RZ(-18))
    t.rbox("tag_r", (.235, -.03, .31), (.012, .13, .07), "band", bevel=.004, rot=RZ(18))
    t.rbox("stowage", (0, -.2, .31), (.3, .05, .08), "hull_dark", bevel=.012)
    m.mesh(t, "tank_turret", yaw)
    pitch = m.pivot("tank_gun_pitch", (0, .12, .32), yaw)
    mt = m.kit(); mt.rbox("mantlet", (0, .15, .32), (.14, .07, .1), "gun_light", bevel=.015)
    m.mesh(mt, "tank_mantlet", pitch)
    recoil = m.pivot("tank_barrel_recoil", (0, .12, .32), pitch)
    br = m.kit()
    br.cylinder("barrel", (0, .17, .32), (0, .5, .32), .026, "paint", sides=8)
    br.rbox("muzzle", (0, .52, .32), (.07, .06, .07), "gun", bevel=.01)
    m.mesh(br, "tank_barrel", recoil)
    return m.export()


# ---------------------------------------------------------------- APC
def apc():
    m = Model("apc"); b = m.base
    side = [(-.37, .1), (.3, .1), (.37, .17), (.33, .27), (-.33, .27), (-.37, .2)]
    b.prism("hull", side, -.22, .22, "paint", axis="x", smooth=30)
    b.rbox("roof", (0, -.03, .28), (.4, .54, .025), "hull_light", bevel=.01)
    b.rbox("nose", (0, .33, .2), (.4, .04, .08), "hull_light", bevel=.012, rot=RX(-35))
    for s in (-1, 1):
        b.rbox("arch_f", (s * .215, .18, .19), (.06, .22, .05), "paint", bevel=.012)
        b.rbox("arch_r", (s * .215, -.2, .19), (.06, .22, .05), "paint", bevel=.012)
        b.rbox("step", (s * .23, -.01, .12), (.03, .12, .03), "hull_dark", bevel=.006)
        m.lamp((s * .15, .36, .2), (.045, .02, .03))
    b.rbox("rear_door", (0, -.37, .19), (.18, .012, .12), "hull_dark", bevel=.006)
    for i, (y, s) in enumerate(((.19, -1), (-.2, -1), (.19, 1), (-.2, 1))):
        m.wheel(f"apc_wheel_{'L' if s < 0 else 'R'}{1 + (i % 2)}", (s * .245, y, .1), .1, .075)
    yaw = m.pivot("apc_turret_yaw", (0, -.04, .29))
    t = m.kit()
    t.prism("turret", [(x * .75, y * .75) for x, y in rounded_rect(.26, .3, .05, 1)], .29, .37, "paint", smooth=30)
    t.cylinder("hatch", (-.03, -.08, .37), (-.03, -.08, .385), .045, "hull_light", sides=8)
    t.rbox("tag", (-.1, -.02, .33), (.012, .09, .045), "band", bevel=.003)
    m.mesh(t, "apc_turret", yaw)
    pitch = m.pivot("apc_gun_pitch", (0, .08, .34), yaw)
    mt = m.kit(); mt.rbox("mantlet", (0, .1, .34), (.07, .05, .06), "gun_light", bevel=.01)
    m.mesh(mt, "apc_mantlet", pitch)
    recoil = m.pivot("apc_barrel_recoil", (0, .08, .34), pitch)
    br = m.kit()
    br.cylinder("barrel", (0, .12, .34), (0, .36, .34), .014, "paint", sides=6)
    br.cylinder("brake", (0, .35, .34), (0, .38, .34), .02, "gun", sides=6)
    m.mesh(br, "apc_barrel", recoil)
    return m.export()


# ---------------------------------------------------------------- buggy
def buggy():
    m = Model("buggy"); b = m.base
    b.rbox("chassis", (0, 0, .12), (.28, .5, .06), "hull_dark", bevel=.015)
    b.rbox("hood", (0, .15, .17), (.3, .2, .06), "hull_light", bevel=.02)
    b.rbox("hood_stripe", (0, .15, .201), (.05, .2, .004), "band", bevel=.001)
    b.rbox("rear_bed", (0, -.16, .17), (.3, .16, .06), "paint", bevel=.018)
    for s in (-1, 1):
        b.rbox("seat", (s * .06, -.02, .19), (.09, .09, .08), "canvas_dark", bevel=.02)
        b.rbox("fender", (s * .19, .17, .16), (.08, .14, .03), "paint", bevel=.01)
        b.rbox("fender_r", (s * .19, -.17, .16), (.08, .14, .03), "paint", bevel=.01)
        m.lamp((s * .1, .255, .16), (.04, .015, .03))
        # roll cage
        b.cylinder("cage_post_f", (s * .13, .06, .19), (s * .12, .02, .33), .012, "gun", sides=6)
        b.cylinder("cage_post_r", (s * .13, -.12, .19), (s * .12, -.08, .33), .012, "gun", sides=6)
        b.cylinder("cage_side", (s * .12, .02, .33), (s * .12, -.08, .33), .012, "gun", sides=6)
    b.cylinder("cage_top_f", (-.12, .02, .33), (.12, .02, .33), .012, "gun", sides=6)
    b.cylinder("cage_top_r", (-.12, -.08, .33), (.12, -.08, .33), .012, "gun", sides=6)
    b.rbox("bumper", (0, .26, .11), (.3, .025, .04), "gun", bevel=.008)
    for i, (y, s) in enumerate(((.17, -1), (-.17, -1), (.17, 1), (-.17, 1))):
        m.wheel(f"buggy_wheel_{'L' if s < 0 else 'R'}{1 + (i % 2)}", (s * .19, y, .09), .09, .08)
    yaw = m.pivot("buggy_gun_yaw", (0, -.06, .34))
    t = m.kit(); t.cylinder("mount", (0, -.06, .33), (0, -.06, .37), .03, "gun", sides=8)
    t.rbox("shield", (0, -.01, .39), (.1, .012, .06), "paint", bevel=.006)
    m.mesh(t, "buggy_mount", yaw)
    pitch = m.pivot("buggy_gun_pitch", (0, -.04, .38), yaw)
    recoil = m.pivot("buggy_gun_recoil", (0, -.04, .38), pitch)
    g = m.kit()
    g.rbox("receiver", (0, -.05, .38), (.04, .1, .045), "gun", bevel=.008)
    g.cylinder("barrel", (0, 0, .385), (0, .15, .385), .009, "gun", sides=6)
    g.rbox("box", (.03, -.06, .37), (.025, .04, .04), "furniture", bevel=.006)
    m.mesh(g, "buggy_mg", recoil)
    return m.export()


# ---------------------------------------------------------------- ground drone
def drone():
    m = Model("drone"); b = m.base
    # Tarp-covered crawler: camo cover (paint for team colour) with straps, camera and lamps in front.
    b.ellipsoid("cover", (0, -.005, .075), (.08, .1, .055), "paint", seg=10, rings=6, smooth=60)
    b.rbox("chassis", (0, 0, .045), (.13, .18, .04), "hull_dark", bevel=.01)
    b.rbox("face", (0, .088, .06), (.1, .02, .045), "hull_dark", bevel=.008)
    b.cylinder("camera", (0, .096, .06), (0, .104, .06), .012, "glass", sides=8)
    for s in (-1, 1):
        b.rbox("eye", (s * .032, .099, .062), (.016, .006, .014), "lamp", bevel=.002)
        b.band("strap", Vector((0, s * .035, .07)), .083, .012, "canvas_dark", axis=(0, 1, 0), sides=10, scale_y=.72,
               skip=lambda p: p.z < -.01)
    for i, (y, s) in enumerate(((.055, -1), (-.055, -1), (.055, 1), (-.055, 1))):
        m.wheel(f"drone_wheel_{'L' if s < 0 else 'R'}{1 + (i % 2)}", (s * .075, y, .04), .04, .03)
    bc = m.kit(); bc.cylinder("beacon_base", (0, .01, .125), (0, .01, .132), .01, "gun", sides=6)
    bc.ellipsoid("beacon", (0, .01, .138), (.008, .008, .007), "flag", seg=6, rings=3)
    body = m.mesh(m.base, "drone_body")
    m.mesh(bc, "drone_beacon", body)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "drone.glb"), use_selection=True, export_yup=True, export_animations=False)
    print(f"VEHICLE drone: {m.tris} tris")
    return m.tris


# ---------------------------------------------------------------- quad drone
def flyer():
    m = Model("flyer"); b = m.base
    body = [(x, y) for x, y in rounded_rect(.13, .15, .035, 1)]
    b.prism("shell", body, .13, .19, "hull_light", smooth=30)
    b.prism("belly", [(x * .9, y * .9) for x, y in body], .11, .13, "paint", smooth=30)
    b.rbox("face", (0, .077, .16), (.09, .012, .04), "hull_dark", bevel=.006)
    b.cylinder("cam", (0, .082, .16), (0, .09, .16), .011, "glass", sides=8)
    for s in (-1, 1):
        b.rbox("eye", (s * .03, .084, .162), (.014, .006, .012), "lamp", bevel=.002)
    for sx in (-1, 1):
        for sy in (-1, 1):
            c = Vector((sx * .12, sy * .11, .17))
            b.cylinder("arm", (sx * .05, sy * .045, .16), c, .012, "paint", sides=6)
            b.cylinder("motor", c - Vector((0, 0, .018)), c + Vector((0, 0, .028)), .021, "hull_light", sides=8)
            b.cylinder("motor_cap", c + Vector((0, 0, .028)), c + Vector((0, 0, .038)), .013, "gun", sides=6)
            rotor = m.pivot(f"flyer_rotor_{sx}_{sy}", c + Vector((0, 0, .042)))
            p = m.kit()
            for a in (0, 180):
                p.rbox("blade", c + Vector((0, 0, .042)) + RZ(a + 20) @ Vector((.034, 0, 0)), (.07, .015, .004), "rubber", bevel=.002, rot=RZ(a + 20))
            m.mesh(p, f"flyer_prop_{sx}_{sy}", rotor, origin=c + Vector((0, 0, .042)))
    bc = m.kit(); bc.cylinder("beacon_base", (0, 0, .19), (0, 0, .198), .012, "gun", sides=6)
    bc.ellipsoid("beacon", (0, 0, .205), (.01, .01, .009), "flag", seg=6, rings=3)
    yaw = m.pivot("flyer_turret_yaw", (0, .01, .1))
    t = m.kit(); t.ellipsoid("turret", (0, .01, .095), (.025, .025, .02), "hull_dark", seg=8, rings=4)
    m.mesh(t, "flyer_turret", yaw)
    pitch = m.pivot("flyer_gun_pitch", (0, .02, .09), yaw)
    recoil = m.pivot("flyer_gun_recoil", (0, .02, .09), pitch)
    g = m.kit(); g.cylinder("gun", (0, .02, .088), (0, .075, .088), .007, "gun", sides=6)
    m.mesh(g, "flyer_gun", recoil)
    body_ob = m.mesh(m.base, "flyer_body")
    m.mesh(bc, "flyer_beacon", body_ob)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "flyer.glb"), use_selection=True, export_yup=True, export_animations=False)
    print(f"VEHICLE flyer: {m.tris} tris")
    return m.tris


# ---------------------------------------------------------------- boss tank
def boss():
    m = Model("boss"); b = m.base
    hull = [(-.7, .08), (.62, .08), (.72, .2), (.62, .34), (-.64, .34), (-.72, .2)]
    b.prism("hull", hull, -.45, .45, "paint", axis="x", smooth=30)
    b.rbox("deck", (0, -.04, .355), (.9, 1.1, .04), "hull_light", bevel=.015)
    b.rbox("glacis", (0, .6, .27), (.8, .05, .1), "hull_light", bevel=.015, rot=RX(-40))
    b.rbox("glacis_tag", (0, .64, .25), (.12, .02, .06), "band", bevel=.004, rot=RX(-40))
    for s in (-1, 1):
        b.rbox("fender", (s * .57, 0, .32), (.26, 1.42, .035), "paint", bevel=.01)
        track(b, s * .57, 1.38, .3, .16, width=.24, wheels=6, r=.08)
        b.rbox("skirt", (s * .7, 0, .23), (.015, 1.1, .1), "hull_dark", bevel=.005)
        m.lamp((s * .4, .7, .26), (.07, .025, .045))
        b.rbox("rear_box", (s * .25, -.68, .3), (.3, .06, .1), "hull_dark", bevel=.012)
    yaw = m.pivot("boss_main_yaw", (0, -.2, .375))
    t = m.kit()
    ring = [(-.3, -.33), (.3, -.33), (.37, -.1), (.3, .2), (-.3, .2), (-.37, -.1)]
    t.prism("turret", ring, .375, .6, "paint", smooth=30)
    t.prism("turret_top", [(x * .86, y * .86 - .02) for x, y in ring], .6, .65, "paint", smooth=30)
    t.cylinder("hatch", (-.1, -.2, .65), (-.1, -.2, .675), .09, "hull_light", sides=10)
    t.rbox("sensor", (.16, -.05, .69), (.08, .05, .05), "gun", bevel=.01)
    t.rbox("sensor_lamp", (.16, -.024, .69), (.05, .008, .02), "lamp", bevel=.003)
    for s in (-1, 1):
        t.rbox("tag", (s * .36, -.08, .48), (.015, .2, .1), "band", bevel=.005, rot=RZ(s * 18))
        # rocket cassettes on the turret flanks
        t.rbox("cassette", (s * .46, -.2, .56), (.18, .22, .17), "paint", bevel=.02)
        t.rbox("cassette_tag", (s * .46, -.2, .652), (.1, .08, .008), "band", bevel=.002)
        for i in range(2):
            for j in range(2):
                c = Vector((s * .46 + (i - .5) * .075, -.089, .56 + (j - .5) * .075))
                t.cylinder("tube", c, c + Vector((0, .012, 0)), .026, "black", sides=8)
    m.mesh(t, "boss_main_turret", yaw)
    pitch = m.pivot("boss_main_pitch", (0, .02, .5), yaw)
    mt = m.kit(); mt.rbox("mantlet", (0, .06, .5), (.32, .1, .16), "gun_light", bevel=.025)
    m.mesh(mt, "boss_main_mantlet", pitch)
    for s, tag in ((-1, "L"), (1, "R")):
        recoil = m.pivot(f"boss_main_recoil_{tag}", (s * .09, .02, .5), pitch)
        br = m.kit()
        br.cylinder("barrel", (s * .09, .1, .5), (s * .09, .66, .5), .038, "paint", sides=8)
        br.rbox("muzzle", (s * .09, .68, .5), (.1, .07, .1), "gun", bevel=.012)
        m.mesh(br, f"boss_main_barrel_{tag}", recoil)
        # auxiliary turrets on the front deck
        ay = m.pivot(f"boss_aux_{tag}_yaw", (s * .4, .3, .375))
        at = m.kit()
        at.prism("aux", [(s * .4 + x, .3 + y) for x, y in rounded_rect(.2, .2, .05, 1)], .375, .48, "paint", smooth=30)
        at.rbox("aux_tag", (s * .4, .26, .485), (.08, .05, .008), "band", bevel=.002)
        m.mesh(at, f"boss_aux_{tag}_turret", ay)
        ap = m.pivot(f"boss_aux_{tag}_pitch", (s * .4, .38, .44), ay)
        am = m.kit(); am.rbox("aux_mantlet", (s * .4, .4, .44), (.08, .05, .07), "gun_light", bevel=.01)
        m.mesh(am, f"boss_aux_{tag}_mantlet", ap)
        ar = m.pivot(f"boss_aux_{tag}_recoil", (s * .4, .38, .44), ap)
        ag = m.kit(); ag.cylinder("aux_gun", (s * .4, .42, .44), (s * .4, .66, .44), .016, "paint", sides=6)
        ag.cylinder("aux_brake", (s * .4, .65, .44), (s * .4, .68, .44), .022, "gun", sides=6)
        m.mesh(ag, f"boss_aux_{tag}_gun", ar)
    return m.export()


BUILDERS = {"tank": tank, "apc": apc, "buggy": buggy, "drone": drone, "flyer": flyer, "boss": boss}
os.makedirs(OUT, exist_ok=True)
for kind, build in BUILDERS.items():
    if ONLY and kind != ONLY: continue
    build()
    if "--render" in ARGS:
        scene = bpy.context.scene
        size = {"tank": 1.0, "apc": .9, "buggy": .7, "drone": .35, "flyer": .45, "boss": 1.7}[kind]
        cam = preview_scene(scene, lens=50, res=520)
        still(scene, cam, os.path.join(PREVIEW, f"{kind}.png"), 35, 28, size * 2.4, (0, 0, size * .18))
