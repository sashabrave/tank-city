"""Hub yard props in the v6 low-poly style: the shredder (recycler) and the training dummy.

Run: /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/build_yard_props.py -- [--render]
  recycler        military shredder: armoured chassis, hopper with twin toothed rollers, screen, lamp, chute
  training_dummy  sandbag dummy on a spring post: helmet, target plate, padded arms, tyre base
Output: assets/models/environment_v7/<name>.glb (hub props face the camera: flipped like build_props_v6).
"""
import bpy, math, os, sys
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v6_common import Kit, D, cozy_soften, preview_scene, still

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV = os.path.join(ROOT, "assets/models/environment_v7")
PREVIEW = os.path.join(ROOT, "tmp/yard_props")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    hard = Kit(scene, "V6_palette_fabric", emissive=True, soft=False)
    soft = Kit(scene, soft=True, share=hard)
    return scene, hard, soft


def export(scene, kits, name):
    tris = sum(k.tris() for k in kits)
    parts = [ob for k in kits for ob, _ in k.parts]
    for ob in parts: ob.data.transform(Matrix.Rotation(math.pi, 4, 'Z'))
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts: ob.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object; ob.name = ob.data.name = name
    cozy_soften(ob, width=.015, angle=50)  # round the raw right angles left by plain boxes
    os.makedirs(ENV, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(ENV, name + ".glb"), use_selection=True, export_yup=True, export_animations=False)
    print(f"PROP {name}: {tris} tris")
    return ob


def recycler():
    """Shredder, 0.62 x 0.5 footprint, ~0.95 tall. Front (+Y before the flip) carries the screen and chute."""
    scene, k, soft = fresh()
    for x in (-.24, .24):
        for y in (-.18, .18): k.rbox(f"leg{x}{y}", (x, y, .05), (.08, .08, .1), "gun", bevel=.01)
    k.rbox("chassis", (0, 0, .36), (.62, .5, .52), "hull", bevel=.04, seg=2)
    k.rbox("armor_l", (-.325, 0, .36), (.03, .42, .44), "hull_dark", bevel=.01)
    k.rbox("armor_r", (.325, 0, .36), (.03, .42, .44), "hull_dark", bevel=.01)
    for i in range(4): k.rbox(f"vent{i}", (.34, -.12 + i * .08, .44), (.012, .05, .16), "gun", bevel=.004)
    # Hopper: tapered funnel with a hazard lip and two toothed rollers inside.
    k.prism("hopper", [(-.3, -.24), (.3, -.24), (.3, .24), (-.3, .24)], .62, .64, "hull_light")
    k.cylinder("funnel", (0, 0, .64), (0, 0, .74), .22, "hull_dark", sides=8, radius_b=.3)
    k.band("lip", Vector((0, 0, .735)), .305, .035, "hazard", sides=8)
    for x in (-.07, .07):
        k.cylinder(f"roller{x}", (x, -.17, .76), (x, .17, .76), .06, "gun_light", sides=8)
        for i in range(5): k.rbox(f"tooth{x}{i}", (x, -.13 + i * .065, .82), (.035, .02, .03), "steel", bevel=.004)
    # Front: screen, status lamp, output chute with a small bin, cable and exhaust.
    k.rbox("screen_frame", (0, .255, .46), (.3, .02, .18), "gun", bevel=.01)
    k.rbox("screen", (0, .266, .46), (.25, .01, .13), "screen", bevel=.004)
    k.rbox("chute", (0, .27, .2), (.22, .08, .08), "gun_light", bevel=.01)
    k.rbox("bin", (0, .34, .08), (.28, .16, .16), "hull_dark", bevel=.015)
    k.cylinder("lamp_post", (.22, .2, .64), (.22, .2, .72), .012, "gun", sides=6)
    k.ellipsoid("lamp", (.22, .2, .75), (.03, .03, .035), "glow_red", seg=8, rings=4)
    k.cylinder("exhaust", (-.24, -.2, .62), (-.24, -.2, .9), .03, "gun", sides=8)
    k.cylinder("exhaust_cap", (-.24, -.2, .9), (-.24, -.2, .93), .045, "gun_light", sides=8)
    k.tube("cable", [Vector((-.3, .18, .3)), Vector((-.38, .22, .15)), Vector((-.36, .3, .02))], [.014, .014, .014], "rubber")
    for i in range(3): k.rbox(f"stencil{i}", (-.12 + i * .12, .252, .6), (.07, .006, .02), "hazard", bevel=.002)
    export(scene, [k, soft], "recycler")


def training_dummy():
    """Sandbag dummy ~1.25 tall: tyre base, spring, post, padded torso with a target plate, helmet, arms."""
    scene, k, soft = fresh()
    k.cylinder("tyre", (0, 0, 0), (0, 0, .12), .26, "rubber", sides=12)
    k.cylinder("tyre_hub", (0, 0, .11), (0, 0, .13), .14, "gun_light", sides=10)
    for i in range(4): k.band(f"spring{i}", Vector((0, 0, .17 + i * .05)), .07, .02, "steel", sides=8)
    k.cylinder("post", (0, 0, .13), (0, 0, .62), .035, "gun", sides=8)
    soft.rbox("torso", (0, 0, .78), (.4, .26, .42), "canvas", bevel=.08, seg=2)
    for z in (.64, .92): soft.band(f"strap{z}", Vector((0, 0, z)), .215, .03, "strap", sides=10, scale_y=.68)
    k.cylinder("plate_ring", (0, .135, .8), (0, .15, .8), .12, "desk", sides=16)
    k.cylinder("plate_mid", (0, .145, .8), (0, .158, .8), .08, "flag", sides=16)
    k.cylinder("plate_bull", (0, .152, .8), (0, .165, .8), .035, "desk", sides=12)
    soft.ellipsoid("head", (0, 0, 1.1), (.13, .12, .13), "canvas_dark", seg=10, rings=6)
    soft.ellipsoid("helmet", (0, -.005, 1.16), (.155, .15, .1), "camo_a", seg=10, rings=5)
    k.rbox("helmet_rim", (0, 0, 1.12), (.32, .3, .02), "camo_b", bevel=.01)
    k.cylinder("arm_bar", (-.38, 0, .9), (.38, 0, .9), .025, "gun", sides=6)
    for x in (-.36, .36): soft.rbox(f"pad{x}", (x, 0, .9), (.14, .14, .16), "canvas_dark", bevel=.05, seg=2)
    export(scene, [k, soft], "training_dummy")


for fn in (recycler, training_dummy):
    fn()
    if "--render" in ARGS:
        scene = bpy.context.scene
        cam = preview_scene(scene, lens=50, res=560)
        still(scene, cam, os.path.join(PREVIEW, f"{fn.__name__}.png"), 210, 22, 2.6, (0, 0, .55))
