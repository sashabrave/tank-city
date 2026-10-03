import bpy, sys, os, math
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath("assets/models/environment_v7/base.glb"))
mats={}
for o in bpy.data.objects:
    if o.type=="MESH":
        for s in o.material_slots:
            if s.material:mats.setdefault(s.material.name,[]).append(o.name)
for k,v in sorted(mats.items()):print("MAT",k,len(v),v[:4])
print("OBJ",len([o for o in bpy.data.objects if o.type=="MESH"]))
pts=[o.matrix_world@Vector(c) for o in bpy.data.objects if o.type=="MESH" for c in o.bound_box]
print("BOUNDS",min(p.x for p in pts),max(p.x for p in pts),min(p.y for p in pts),max(p.y for p in pts),min(p.z for p in pts),max(p.z for p in pts))
sc=bpy.context.scene;sc.render.engine="BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "CYCLES"
sc.render.resolution_x=sc.render.resolution_y=700;sc.render.film_transparent=True;sc.view_settings.view_transform="Standard"
w=bpy.data.worlds.new("W");w.use_nodes=True;sc.world=w;w.node_tree.nodes["Background"].inputs[1].default_value=1.0
sun=bpy.data.objects.new("S",bpy.data.lights.new("S","SUN"));sc.collection.objects.link(sun);sun.data.energy=3;sun.rotation_euler=(math.radians(50),0,math.radians(30))
cam=bpy.data.objects.new("C",bpy.data.cameras.new("C"));sc.collection.objects.link(cam);sc.camera=cam
for name,az in (("front",30),("rear",210)):
    a=math.radians(az);d=5.5
    cam.location=Vector((d*math.sin(a),-d*math.cos(a),3.0))
    cam.rotation_euler=(Vector((0,0,0.7))-cam.location).to_track_quat("-Z","Y").to_euler()
    sc.render.filepath=os.path.abspath(f"art_requests/hq_vehicle_v2/old_{name}.png");bpy.ops.render.render(write_still=True)
