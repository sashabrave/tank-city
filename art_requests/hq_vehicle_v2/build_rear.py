# HQ vehicle rear detail (author, 3 Oct): rear door with steel hinges, spare wheel on a swing arm, ladder,
# jerrycans in steel cages, steel bumper with tow hook, mud flaps, exhaust, two tall red taillight pillars.
# Imports the game model, adds parts with its own materials (library names: «HQ steel», «HQ rubber»,
# «HQ sage armour»), exports back. Blender: front -Y, rear +Y (cabin rear face y 0.575, hull 0.70).
import bpy, bmesh, os, sys, math
from mathutils import Vector
SRC = "assets/models/environment_v7/base.glb"
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else SRC
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(SRC))
M = bpy.data.materials
root = next(o for o in bpy.data.objects if o.parent is None)
print("ROOT", root.name, tuple(root.matrix_world.to_scale()), tuple(root.rotation_euler))
def mat(name): return M[name]
red = M.new("HQ taillight red"); red.use_nodes = True
b = red.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value = (1.0, 0.06, 0.04, 1)
b.inputs["Emission Color"].default_value = (1.0, 0.05, 0.03, 1); b.inputs["Emission Strength"].default_value = 4.0
def bev(ob, w=0.008):
    m = ob.modifiers.new("Bevel", "BEVEL"); m.width = w; m.segments = 1; m.limit_method = "ANGLE"
def add(name, size, loc, material, rot=(0, 0, 0), w=0.008):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0); bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    ob.location = loc; ob.rotation_euler = rot; me.materials.append(material); bev(ob, w)
    ob.parent = root; ob.matrix_parent_inverse = root.matrix_world.inverted(); return ob
def cyl(name, r, h, loc, material, axis="Y", seg=12, w=0.006):
    bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=h)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    ob.location = loc; ob.rotation_euler = (math.radians(90), 0, 0) if axis == "Y" else (0, math.radians(90), 0) if axis == "X" else (0, 0, 0)
    me.materials.append(material); bev(ob, w); ob.parent = root; ob.matrix_parent_inverse = root.matrix_world.inverted(); return ob
steel, rubber, sage, enamel = mat("HQ steel"), mat("HQ rubber"), mat("HQ sage armour"), mat("Warm enamel")
Y = 0.575   # cabin rear face
# rear hatch with steel hinges and handle
add("Rear hatch", (0.42, 0.03, 0.4), (-0.08, Y + 0.015, 0.8), sage)
for z in (0.68, 0.92): add("Rear hatch hinge", (0.05, 0.04, 0.07), (-0.31, Y + 0.035, z), steel)
add("Rear hatch handle", (0.03, 0.035, 0.12), (0.1, Y + 0.04, 0.8), steel)
# spare wheel on a swing arm
cyl("Spare tyre", 0.15, 0.08, (0.2, Y + 0.09, 0.84), rubber, seg=14)
cyl("Spare rim", 0.08, 0.09, (0.2, Y + 0.095, 0.84), enamel, seg=10)
add("Spare arm", (0.3, 0.03, 0.04), (0.13, Y + 0.05, 0.84), steel, rot=(0, math.radians(-20), 0))
# ladder on the left of the hatch
for x in (-0.4, -0.33):
    add("Ladder rail", (0.018, 0.02, 0.5), (x, Y + 0.03, 0.82), steel, w=0.004)
for i in range(5):
    add("Ladder rung", (0.07, 0.016, 0.014), (-0.365, Y + 0.03, 0.62 + i * 0.1), steel, w=0.003)
# jerrycans in steel cages on the generator pods
for s in (-1, 1):
    x = s * 0.5
    add("Jerrycan", (0.16, 0.07, 0.22), (x, 0.705, 0.85), sage)
    add("Jerrycan cap", (0.04, 0.03, 0.04), (x - s * 0.04, 0.705, 0.98), steel)
    for z in (0.76, 0.94): add("Jerrycan cage", (0.19, 0.025, 0.018), (x, 0.745, z), steel, w=0.003)
    for dx in (-0.09, 0.09): add("Jerrycan cage", (0.018, 0.025, 0.26), (x + dx, 0.745, 0.85), steel, w=0.003)
# steel bumper, tow hook, reflectors, mud flaps, exhaust
add("Rear bumper", (1.15, 0.08, 0.1), (0, 0.745, 0.32), steel, w=0.012)
cyl("Tow hook", 0.035, 0.08, (0, 0.8, 0.29), steel, seg=8)
for s in (-1, 1):
    add("Rear reflector", (0.09, 0.02, 0.04), (s * 0.4, 0.79, 0.34), mat("Signal amber"))
    add("Mud flap", (0.18, 0.02, 0.2), (s * 0.55, 0.77, 0.15), rubber)
cyl("Rear exhaust", 0.03, 0.12, (0.3, 0.8, 0.26), steel, seg=8)
# two tall red taillight pillars at the cabin corners, bumper to roof line
for s in (-1, 1):
    # on the outer rear corners of the generator pods (rear face y 0.672), bumper to above the pod: always visible
    add("Taillight pillar", (0.05, 0.03, 0.78), (s * 0.69, 0.69, 0.74), red, w=0.006)
    add("Taillight pillar frame", (0.075, 0.025, 0.82), (s * 0.69, 0.675, 0.74), steel, w=0.004)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT), export_format="GLB", export_yup=True, export_apply=True)
print("REAR exported", OUT, len([o for o in bpy.data.objects if o.type == "MESH"]), "meshes")
