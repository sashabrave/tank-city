import bpy, math
bpy.ops.wm.read_factory_settings(use_empty=True)
# Heart outline as a bezier curve (XY plane), extruded and bevelled, then stood up facing the camera (-Y).
cd=bpy.data.curves.new("heart","CURVE");cd.dimensions='2D';cd.fill_mode='BOTH'
sp=cd.splines.new('BEZIER');pts=[(0,-1.0),(1.0,0.15),(0.5,0.85),(0,0.45),(-0.5,0.85),(-1.0,0.15)]
sp.bezier_points.add(len(pts)-1)
for p,(x,y) in zip(sp.bezier_points,pts):
    p.co=(x,y,0);p.handle_left_type=p.handle_right_type='AUTO'
sp.bezier_points[0].handle_left_type=sp.bezier_points[0].handle_right_type='VECTOR'
sp.bezier_points[3].handle_left_type=sp.bezier_points[3].handle_right_type='VECTOR'
sp.use_cyclic_u=True
cd.extrude=0.22;cd.bevel_depth=0.12;cd.bevel_resolution=3;cd.resolution_u=10
ob=bpy.data.objects.new("bonus_heart",cd);bpy.context.collection.objects.link(ob)
bpy.context.view_layer.objects.active=ob;ob.select_set(True)
bpy.ops.object.convert(target='MESH')
ob.rotation_euler=(math.radians(90),0,0);bpy.ops.object.transform_apply(rotation=True,scale=True)
bpy.ops.object.shade_smooth()
m=bpy.data.materials.new("heart_red");m.use_nodes=True
b=m.node_tree.nodes["Principled BSDF"];b.inputs["Base Color"].default_value=(0.75,0.02,0.04,1);b.inputs["Roughness"].default_value=0.42
ob.data.materials.append(m)
# Small white highlight plaster-free: a soft shine sphere is left to the engine lighting.
bpy.ops.export_scene.gltf(filepath="/Users/sashabrave/Desktop/tank-roguelite-claude/assets/models/bonuses_v6/bonus_heart.glb",export_format='GLB',use_selection=True,export_apply=True)
print("HEART tris",sum(len(p.vertices)-2 for p in ob.data.polygons))
