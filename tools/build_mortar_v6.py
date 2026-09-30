"""Mortar emplacement in the v6 cozy style: sandbag nest, turntable, stubby tube on a bipod, warning lamp.

Run: /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/build_mortar_v6.py
Output: assets/models/vehicles_v6/mortar.glb, driven by scripts/mortar_model.gd.
Node tree (Godot names):  mortar_body (static nest) · mortar_yaw → mortar_table, mortar_lamp, mortar_elev → mortar_tube
The tube is authored level along +Y (Godot -Z); mortar_model.gd raises mortar_elev (rotation.x > 0 lifts the muzzle).
Painted parts use the V6_hull_paint material, so team paint (friendly / enemy rank / capture) works as on vehicles.
"""
import bpy, math, os, sys
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v6_common import Kit, D, cozy_soften

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/models/vehicles_v6")
REST = D(55)  # elevation the bipod is fitted for

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
base = Kit(scene, "V6_palette_fabric", emissive=True, soft=False)
base.add_special("paint", base.material("V6_hull_paint", "7a8062", .55))


def group(name, build, pivot=(0, 0, 0), parent=None, soften=True):
    """Build parts with a fresh kit sharing the palette, join them, move the origin to the pivot."""
    k = Kit(scene, soft=False, share=base)
    soft = Kit(scene, soft=True, share=base)
    build(k, soft)
    parts = [ob for kit in (k, soft) for ob, _ in kit.parts]
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts: ob.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object; ob.name = ob.data.name = name
    if soften: cozy_soften(ob, width=.012, angle=50, min_edge=.05)
    ob.data.transform(Matrix.Translation(-Vector(pivot)))
    ob.location = pivot
    if parent: ob.parent = parent; ob.location = Vector(pivot) - parent.matrix_world.translation
    return ob


def pivot(name, at, parent=None):
    e = bpy.data.objects.new(name, None); scene.collection.objects.link(e)
    e.location = at
    if parent: e.parent = parent; e.location = Vector(at) - parent.matrix_world.translation
    bpy.context.view_layer.update()
    return e


def nest(k, soft):
    k.cylinder("plate", (0, 0, 0), (0, 0, .05), .3, "concrete_dark", sides=12)
    # Puffy sandbags round the back three quarters; the front (+Y) stays open for the tube.
    for i in range(9):
        a = D(62 + i * 29.5)
        c = Vector((math.sin(a) * .34, math.cos(a) * .34, .07))
        bag = soft.ellipsoid(f"bag{i}", c, (.1, .068, .07), "canvas" if i % 2 else "canvas_dark", seg=8, rings=5)
        bag.data.transform(Matrix.Translation(c) @ Matrix.Rotation(-a, 4, 'Z') @ Matrix.Translation(-c))
    for i in range(4):
        a = D(125 + i * 37)
        c = Vector((math.sin(a) * .325, math.cos(a) * .325, .16))
        bag = soft.ellipsoid(f"top{i}", c, (.092, .062, .06), "canvas_dark" if i % 2 else "canvas", seg=8, rings=5)
        bag.data.transform(Matrix.Translation(c) @ Matrix.Rotation(-a, 4, 'Z') @ Matrix.Translation(-c))
    # Ready rounds: a small crate with three orange-nosed shells.
    k.rbox("crate", (-.2, -.1, .09), (.15, .12, .08), "wood", bevel=.012)
    for i in range(3):
        x = -.24 + i * .04
        k.cylinder(f"shell{i}", (x, -.1, .13), (x, -.1, .21), .016, "hull_dark", sides=6)
        soft.ellipsoid(f"nose{i}", (x, -.1, .215), (.016, .016, .022), "band", seg=6, rings=3)


def table(k, soft):
    k.cylinder("table", (0, 0, .05), (0, 0, .11), .2, "paint", sides=12)
    k.band("stripe", Vector((0, 0, .1)), .203, .018, "hazard", sides=12)
    k.cylinder("hub", (0, 0, .11), (0, 0, .15), .07, "gun_light", sides=8)
    # Traverse handwheel on the right cheek.
    k.cylinder("axle", (.13, .02, .15), (.2, .02, .15), .012, "gun", sides=6)
    k.band("wheel", Vector((.205, .02, .15)), .045, .014, "gun", axis=(1, 0, 0), sides=8)
    k.cylinder("post", (-.13, -.1, .11), (-.13, -.1, .27), .011, "gun", sides=6)


def lamp(k, soft):
    soft.ellipsoid("lamp", (-.13, -.1, .29), (.032, .032, .03), "glow_red", seg=8, rings=4)
    k.cylinder("cap", (-.13, -.1, .31), (-.13, -.1, .325), .026, "gun", sides=8)


ELEV_AT = (0, -.02, .16)


def tube(k, soft):
    x, y, z = ELEV_AT
    k.cylinder("tube", (x, y - .06, z), (x, y + .33, z), .07, "paint", sides=10, radius_b=.064)
    soft.ellipsoid("breech", (x, y - .08, z), (.074, .05, .074), "gun_light", seg=8, rings=4)
    k.band("muzzle", Vector((x, y + .32, z)), .071, .035, "gun", axis=(0, 1, 0), sides=10)
    k.band("stripe", Vector((x, y + .22, z)), .068, .022, "band", axis=(0, 1, 0), sides=10)
    k.band("collar", Vector((x, y + .14, z)), .076, .03, "gun_light", axis=(0, 1, 0), sides=10)
    # Bipod fitted at the rest elevation: legs reach world-down from the collar.
    s, c = math.sin(REST), math.cos(REST)
    for side in (-1, 1):
        top = Vector((x + side * .04, y + .14, z - .04))
        foot = top + Vector((side * .08, -s * .12, -c * .12))
        k.cylinder(f"leg{side}", top, foot, .011, "gun", sides=6)
        k.rbox(f"foot{side}", foot, (.04, .03, .015), "gun", bevel=.004)


group("mortar_body", nest)
yaw = pivot("mortar_yaw", (0, 0, 0))
group("mortar_table", table, (0, 0, 0), yaw)
group("mortar_lamp", lamp, (-.13, -.1, .29), yaw, soften=False)
elev = pivot("mortar_elev", ELEV_AT, yaw)
group("mortar_tube", tube, ELEV_AT, elev)

bpy.ops.object.select_all(action='SELECT')
os.makedirs(OUT, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "mortar.glb"), use_selection=True, export_yup=True, export_animations=False)
print("MORTAR tris", sum(len(p.vertices) - 2 for ob in bpy.data.objects if ob.type == 'MESH' for p in ob.data.polygons))
