# Gold ingot for alloy drops (T-105): a trapezoid bar with a soft bevel, one mesh, origin at the bottom centre.
# /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/art/build_ingot.py
import bpy, bmesh, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
bpy.ops.wm.read_factory_settings(use_empty=True)
me = bpy.data.meshes.new("Ingot"); ob = bpy.data.objects.new("Ingot", me); bpy.context.scene.collection.objects.link(ob)
bm = bmesh.new()
L, W, H = 1.0, .52, .26          # bottom length, width, height
l, w = .80, .34                    # top length, width
pts = [(-L/2,-W/2,0),(L/2,-W/2,0),(L/2,W/2,0),(-L/2,W/2,0),(-l/2,-w/2,H),(l/2,-w/2,H),(l/2,w/2,H),(-l/2,w/2,H)]
v = [bm.verts.new(p) for p in pts]
for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]: bm.faces.new([v[i] for i in f])
bm.to_mesh(me); bm.free()
bev = ob.modifiers.new("Bevel", "BEVEL"); bev.width = .045; bev.segments = 4; bev.profile = .6
bpy.context.view_layer.objects.active = ob; ob.select_set(True)
bpy.ops.object.modifier_apply(modifier="Bevel"); bpy.ops.object.shade_smooth(); 
try: bpy.ops.object.shade_auto_smooth(angle=0.7)
except Exception: pass
mat = bpy.data.materials.new("Gold"); mat.use_nodes = True
b = mat.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value = (1.0, .66, .12, 1); b.inputs["Metallic"].default_value = .9; b.inputs["Roughness"].default_value = .25
me.materials.append(mat)
ob.scale = (.32, .32, .32); bpy.ops.object.transform_apply(scale=True)
out = os.path.join(ROOT, "assets/models/pickups/ingot.glb")
bpy.ops.export_scene.gltf(filepath=out, use_selection=True, export_yup=True, export_animations=False)
print("INGOT", out, len(me.vertices))
