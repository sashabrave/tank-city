"""Keep the kit_v4 vehicle models, re-dress them with v6 materials.

Run: Blender -b --factory-startup --python tools/rematerial_kit_v4.py
Every face of assets/models/kit_v4/<kind>.glb used one tile of the 4x4 KIT4 atlas.
Here each tile maps to: the team paint surface (V6_hull_paint, was the ivory tile),
the shared v6 palette (colours, lamps and red signals glow), or V6_metal
(steel and blued gunmetal: metallic, brushed by cozy_material). Geometry, node names
and hierarchy are untouched, so kit_model.gd articulation keeps working.
Writes assets/models/vehicles_v6/<kind>.glb.
"""
import bpy, os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v6_common import Kit

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets/models/kit_v4")
OUT = os.path.join(ROOT, "assets/models/vehicles_v6")
PAINT, PAL, METAL = 0, 1, 2
# (column, row) in image space -> (surface, palette cell)
TILES = {
    (0, 0): (PAL, "hull"), (1, 0): (PAL, "hull_light"), (2, 0): (PAL, "rubber"), (3, 0): (METAL, "gun"),
    (0, 1): (PAL, "glow_red"), (1, 1): (PAL, "hull_dark"), (2, 1): (PAL, "hull"), (3, 1): (PAL, "hull_light"),
    (0, 2): (PAL, "rubber"), (1, 2): (METAL, "steel"), (2, 2): (PAL, "lamp"), (3, 2): (METAL, "gun"),
    (0, 3): (PAL, "hull"), (1, 3): (PAL, "hull_dark"), (2, 3): (PAINT, "hull"), (3, 3): (PAL, "band"),
}

from mathutils import Vector


def antenna(g, a, b, pennant=False):
    g.cylinder("antenna_base", a, Vector(a) + Vector((0, 0, .02)), .014, "metal", sides=6, face_cell=lambda p: "gun")
    g.cylinder("antenna", a, b, .005, "metal", sides=4, face_cell=lambda p: "gun", caps=False)
    if pennant:
        b = Vector(b)
        g.prism("pennant", [(0, 0), (-.07, -.02), (0, -.045)], b.x - .002, b.x + .002, "band", axis="x", smooth=10)
        g.parts[-1][0].location = (0, b.y, b.z - .005)


def jerrycan(g, c, rot=0.0):
    g.rbox("jerrycan", c, (.06, .035, .085), "hull", bevel=.008)
    g.rbox("jerrycan_cap", Vector(c) + Vector((.018, 0, .05)), (.016, .016, .016), "metal", bevel=.003, face_cell=lambda p: "gun")


# A little extra detail per vehicle; each group joins the named mesh (keeps articulation).
def details(kind, k):
    g = lambda: Kit(bpy.context.scene, share=k, soft=False)
    out = {}
    if kind == "tank":
        t = g(); antenna(t, (-.2, -.33, .585), (-.23, -.37, .95)); out["tank_turret"] = t
        b = g()
        for x in (-.12, .12): jerrycan(b, (x, -.41, .44))
        b.rbox("toolbox", (-.37, .08, .282), (.1, .18, .05), "hull_dark", bevel=.01)
        for x in (-.2, .2): b.rbox("tow", (x, .385, .2), (.04, .03, .03), "metal", bevel=.006, face_cell=lambda p: "steel")
        out["tank_body"] = b
    elif kind == "apc":
        b = g(); antenna(b, (-.2, -.34, .334), (-.22, -.38, .7))
        b.cylinder("spare", (0, -.415, .24), (0, -.465, .24), .08, "rubber", sides=10)
        b.cylinder("spare_hub", (0, -.463, .24), (0, -.47, .24), .04, "metal", sides=8, face_cell=lambda p: "steel")
        for x in (-.272, .272): b.rbox("side_box", (x, -.08, .26), (.03, .16, .07), "hull_dark", bevel=.008)
        out["apc_body"] = b
    elif kind == "buggy":
        b = g(); jerrycan(b, (.12, -.27, .19)); antenna(b, (-.16, -.24, .33), (-.17, -.26, .62), pennant=True)
        out["buggy_body"] = b
    elif kind == "drone":
        b = g(); antenna(b, (-.05, -.07, .16), (-.055, -.08, .27))
        b.ellipsoid("tip", (-.055, -.08, .275), (.008, .008, .008), "band", seg=5, rings=3)
        out["drone_body"] = b
    elif kind == "flyer":
        b = g(); antenna(b, (0, -.1, .322), (0, -.12, .42)); out["flyer_body"] = b
    elif kind == "boss":
        t = g()
        for x in (-.3, .3): antenna(t, (x, -.62, 1.0), (x * 1.07, -.66, 1.45))
        out["boss_main_turret"] = t
        b = g()
        for x in (-.2, 0, .2): b.rbox("track_link", (x, .61, .5), (.12, .04, .06), "rubber", bevel=.008)
        for x in (-.35, .35): jerrycan(b, (x, -.735, .45))
        out["boss_hull"] = b
    return out


def join_into(target, kit):
    if not kit.parts: return
    bpy.ops.object.select_all(action='DESELECT')
    for ob, _ in kit.parts: ob.select_set(True)
    target.select_set(True); bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()


os.makedirs(OUT, exist_ok=True)
for kind in ("tank", "apc", "buggy", "drone", "flyer", "boss"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    k = Kit(scene, "V6_palette_fabric", emissive=True, soft=False)
    paint = k.material("V6_hull_paint", "7a8062", .55)
    metal = k.material("V6_metal", "8a9196", .38, metallic=.85)
    # Metal shares the palette texture so steel and gunmetal keep their own tones.
    tex = next(n for n in k.pal.node_tree.nodes if n.type == 'TEX_IMAGE')
    mt = metal.node_tree.nodes.new("ShaderNodeTexImage"); mt.image = tex.image; mt.interpolation = 'Closest'
    metal.node_tree.links.new(mt.outputs["Color"], metal.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, f"{kind}.glb"))
    counts = [0, 0, 0]
    for ob in [o for o in bpy.data.objects if o.type == 'MESH']:
        me = ob.data
        uv = me.uv_layers.active.data if me.uv_layers.active else None
        me.materials.clear()
        for m in (paint, k.pal, metal): me.materials.append(m)
        for p in me.polygons:
            if uv is None:
                surface, cell = PAL, "hull"
            else:
                u = sum(uv[li].uv.x for li in p.loop_indices) / p.loop_total
                v = sum(uv[li].uv.y for li in p.loop_indices) / p.loop_total
                tile = (min(3, max(0, math.floor(u * 4))), min(3, max(0, math.floor((1 - v) * 4))))
                surface, cell = TILES.get(tile, (PAL, "hull"))
            p.material_index = surface
            counts[surface] += 1
            if uv is not None:
                c = Kit.cell_uv(cell)
                for li in p.loop_indices: uv[li].uv = c
        # (materials.clear() would reset face indices; unused slots are simply not exported)
    k.add_special("metal", metal)
    for name, kit in details(kind, k).items():
        join_into(bpy.data.objects[name], kit)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, f"{kind}.glb"), use_selection=True, export_yup=True, export_animations=False)
    print(f"REMATERIAL {kind}: paint {counts[0]} palette {counts[1]} metal {counts[2]} faces")
