"""Engineering military lights in the v6 low-poly style (four kinds).

Run: /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/build_lights_v1.py -- [--render]
  light_mast        tall lattice mast on a bolted concrete footing: ladder, junction box with conduit,
                    a crossbar of four caged floodlights with visors, red obstruction lamp on top (~2.7 tall)
  light_tripod      field tripod with a telescopic mast, one big floodlight on a yoke, generator at the foot (~1.55)
  light_wall        bulkhead lamp on a bracket with a mounting plate, wire cage, conduit and junction box
  light_block       armoured searchlight on a turntable for block tops: handles, cable reel
Lamps face -Y in Blender, which is -Z in Godot after the export flip (godot = (-x, z, y)).
Light anchors used by scripts/world_lighting.gd and base_surroundings.gd are listed in LIGHT_ANCHORS there.
Output: assets/models/environment_v7/<name>.glb
"""
import bpy, math, os, sys
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v6_common import Kit, D, cozy_soften, preview_scene, still

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV = os.path.join(ROOT, "assets/models/environment_v7")
PREVIEW = os.path.join(ROOT, "tmp/lights_v1")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    hard = Kit(scene, "V6_palette_fabric", emissive=True, soft=False)
    return scene, hard


def export(scene, kits, name):
    tris = sum(k.tris() for k in kits)
    parts = [ob for k in kits for ob, _ in k.parts]
    for ob in parts: ob.data.transform(Matrix.Rotation(math.pi, 4, 'Z'))
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts: ob.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object; ob.name = ob.data.name = name
    cozy_soften(ob, width=.008, angle=50)
    os.makedirs(ENV, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(ENV, name + ".glb"), use_selection=True, export_yup=True, export_animations=False)
    print(f"LIGHT {name}: {tris} tris")
    if "--render" in ARGS:
        os.makedirs(PREVIEW, exist_ok=True)
        cam = preview_scene(scene)
        still(scene, cam, os.path.join(PREVIEW, name + ".png"), yaw=200, pitch=18, dist=4.2, target=(0, 0, ob.dimensions.z * .5))
    return ob


def floodlight(k, name, center, width=.26, height=.18, depth=.16, tilt=-20, cage=False):
    """Box floodlight facing -Y: housing, glowing lens, visor, cooling fins, optional wire grille."""
    x, y, z = center
    rot = Matrix.Rotation(D(tilt), 3, 'X')
    k.rbox(name + "_body", (x, y, z), (width, depth, height), "gun_light", bevel=.012, rot=rot)
    k.rbox(name + "_lens", (x, y - depth * .52, z), (width * .82, .012, height * .74), "lamp", bevel=.004, rot=rot)
    k.rbox(name + "_visor", (x, y - depth * .62, z + height * .55), (width * 1.04, depth * .5, .014), "gun", bevel=.004, rot=rot)
    if cage:
        for i in range(3):
            k.rbox(f"{name}_bar{i}", (x - width * .3 + i * width * .3, y - depth * .64, z), (.008, .008, height * .8), "steel", bevel=0)


def light_mast():
    scene, k = fresh()
    # Bolted concrete footing.
    k.rbox("footing", (0, 0, .09), (.62, .62, .18), "concrete", bevel=.02)
    k.rbox("plate", (0, 0, .19), (.36, .36, .03), "gun", bevel=.006)
    # Lattice mast: four tapered legs with cross braces.
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.cylinder(f"leg{sx}{sy}", (sx * .13, sy * .13, .2), (sx * .06, sy * .06, 2.42), .02, "hull_dark", sides=6)
    # 0.8: simpler by about a third — four brace levels, no ladder, two big heads, no fins or cages.
    for i in range(4):
        z0 = .32 + i * .52; z1 = z0 + .52; w0 = .13 - .07 * (z0 - .2) / 2.22; w1 = .13 - .07 * (z1 - .2) / 2.22
        for a, b in (((-w0, -w0), (w1, -w1)), ((w0, w0), (-w1, w1)), ((-w0, w0), (-w1, -w1)), ((w0, -w0), (w1, w1))):
            k.cylinder(f"brace{i}{a}{b}", (a[0], a[1], z0), (b[0], b[1], z1), .009, "hull", sides=4)
    # Junction box with a conduit running down.
    k.rbox("junction", (.16, 0, .7), (.1, .16, .22), "hull", bevel=.01)

    # Crossbar with four caged floodlights.
    k.rbox("crossbar", (0, -.02, 2.46), (1.1, .07, .06), "gun", bevel=.008)
    k.rbox("crossbar_top", (0, -.02, 2.52), (.24, .1, .06), "hull_dark", bevel=.008)
    for i, x in enumerate((-.26, .26)):
        k.cylinder(f"yoke{i}", (x, -.05, 2.49), (x, -.05, 2.55), .014, "gun", sides=6)
        floodlight(k, f"head{i}", (x, -.12, 2.62), width=.34, height=.22, depth=.18, tilt=-24)
    # Obstruction lamp and a little lightning rod.
    k.cylinder("rod", (0, -.02, 2.55), (0, -.02, 2.86), .008, "steel", sides=4)
    k.ellipsoid("obstruction", (0, -.02, 2.76), (.035, .035, .04), "glow_red", seg=8, rings=4)
    export(scene, [k], "light_mast")


def light_tripod():
    scene, k = fresh()
    # Small generator at the foot.
    k.rbox("generator", (.22, .14, .12), (.28, .18, .22), "hull", bevel=.02)

    # Tripod legs, collar and telescopic mast.
    for a in (0, 120, 240):
        r = D(a); foot = Vector((math.sin(r) * .32, math.cos(r) * .32, 0))
        k.cylinder(f"leg{a}", foot, (0, 0, .52), .016, "gun", sides=6)
        k.rbox(f"foot{a}", (foot.x, foot.y, .012), (.06, .06, .024), "rubber", bevel=.006)
    k.cylinder("collar", (0, 0, .48), (0, 0, .58), .04, "hull_dark", sides=8)
    k.cylinder("mast_low", (0, 0, .5), (0, 0, 1.0), .028, "gun_light", sides=8)
    k.cylinder("mast_high", (0, 0, 1.0), (0, 0, 1.38), .02, "steel", sides=8)
    # Yoke and one big floodlight.
    k.rbox("yoke_base", (0, 0, 1.4), (.1, .08, .04), "gun", bevel=.006)
    for x in (-.2, .2):
        k.rbox(f"yoke{x}", (x, 0, 1.47), (.02, .04, .16), "gun", bevel=.004)
    floodlight(k, "head", (0, -.04, 1.5), width=.36, height=.24, depth=.2, tilt=-26)
    export(scene, [k], "light_tripod")


def light_wall():
    scene, k = fresh()
    # Mounting plate at y=0 with four bolts; bracket arm out to -Y.
    k.rbox("plate", (0, .01, 0), (.18, .02, .24), "gun", bevel=.006)
    for sx in (-1, 1):
        for sz in (-1, 1):
            k.cylinder(f"bolt{sx}{sz}", (sx * .06, 0, sz * .09), (sx * .06, -.015, sz * .09), .012, "steel", sides=6)
    k.rbox("arm", (0, -.12, .05), (.04, .22, .04), "hull_dark", bevel=.006)
    k.rbox("brace", (0, -.08, -.03), (.03, .03, .16), "hull_dark", bevel=.004, rot=Matrix.Rotation(D(40), 3, 'X'))
    # Bulkhead lamp: round housing, glowing dome, wire cage.
    k.cylinder("housing", (0, -.24, .1), (0, -.24, .02), .085, "gun_light", sides=10)
    k.ellipsoid("dome", (0, -.24, .0), (.07, .07, .05), "lamp", seg=10, rings=4)
    for a in range(0, 180, 45):
        r = D(a)
        k.cylinder(f"cage{a}", (math.cos(r) * .08, -.24 + math.sin(r) * .08, .0), (-math.cos(r) * .08, -.24 - math.sin(r) * .08, .0), .006, "steel", sides=4)
    k.band("cage_ring", Vector((0, -.24, -.01)), .082, .012, "steel", sides=10)
    # Conduit and a small junction box under it.
    k.rbox("box", (.13, .0, -.14), (.08, .04, .09), "hull", bevel=.006)
    k.tube("conduit", [Vector((.13, -.01, -.09)), Vector((.13, -.02, .05)), Vector((.03, -.1, .07))], [.009, .009, .009], "rubber")
    export(scene, [k], "light_wall")


def light_block():
    scene, k = fresh()
    # Turntable base for a block top, armoured searchlight with handles, cable reel.
    k.cylinder("base", (0, 0, 0), (0, 0, .05), .16, "hull_dark", sides=12)
    k.band("base_ring", Vector((0, 0, .055)), .15, .012, "hazard", sides=12)
    k.cylinder("turntable", (0, 0, .05), (0, 0, .09), .1, "gun", sides=10)
    for x in (-.12, .12):
        k.rbox(f"fork{x}", (x, 0, .16), (.02, .05, .16), "gun", bevel=.004)
    k.cylinder("drum", (0, .02, .22), (0, -.12, .22), .1, "gun_light", sides=12)
    k.cylinder("lens_rim", (0, -.12, .22), (0, -.135, .22), .1, "gun", sides=12)
    k.cylinder("lens", (0, -.134, .22), (0, -.14, .22), .085, "lamp", sides=12)
    for i in range(3):
        k.rbox(f"slat{i}", (0, -.145, .16 + i * .06), (.17, .008, .012), "steel", bevel=0)
    for x in (-.07, .07):
        k.rbox(f"handle{x}", (x, .05, .34), (.02, .02, .06), "steel", bevel=.004)
    k.rbox("handle_bar", (0, .05, .37), (.16, .02, .02), "steel", bevel=.004)
    k.cylinder("reel", (.2, .1, .06), (.2, .1, .12), .06, "hazard", sides=10)
    k.tube("reel_cable", [Vector((.16, .08, .09)), Vector((.08, .05, .1)), Vector((0, .02, .12))], [.008, .008, .008], "rubber")
    export(scene, [k], "light_block")


for build in (light_mast, light_tripod, light_wall, light_block):
    build()
