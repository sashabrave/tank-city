import bpy, os
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath("assets/models/environment_v7/base.glb"))
rows=[]
for o in bpy.data.objects:
    if o.type!="MESH":continue
    pts=[o.matrix_world@Vector(c) for c in o.bound_box]
    rows.append((max(p.y for p in pts),min(p.y for p in pts),o.name,round(min(p.x for p in pts),2),round(max(p.x for p in pts),2),round(min(p.z for p in pts),2),round(max(p.z for p in pts),2),o.material_slots[0].material.name if o.material_slots else ""))
rows.sort(reverse=True)
for r in [r for r in rows if r[6]>0.9 and r[5]<1.0] + rows[30:0]:print("REAR %.3f %.3f %s x[%s,%s] z[%s,%s] %s"%r)
