import bpy, os, math, sys
from mathutils import Vector
src=sys.argv[sys.argv.index("--")+1]; tag=sys.argv[sys.argv.index("--")+2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(src))
sc=bpy.context.scene;sc.render.engine="CYCLES";sc.cycles.samples=48;sc.render.resolution_x=sc.render.resolution_y=700;sc.render.film_transparent=True;sc.view_settings.view_transform="Standard"
w=bpy.data.worlds.new("W");w.use_nodes=True;sc.world=w;w.node_tree.nodes["Background"].inputs[0].default_value=(0.8,0.82,0.86,1);w.node_tree.nodes["Background"].inputs[1].default_value=0.7
sun=bpy.data.objects.new("S",bpy.data.lights.new("S","SUN"));sc.collection.objects.link(sun);sun.data.energy=3;sun.rotation_euler=(math.radians(50),0,math.radians(200))
cam=bpy.data.objects.new("C",bpy.data.cameras.new("C"));sc.collection.objects.link(cam);sc.camera=cam
for name,az in (("rear",200),("rear_r",160)):
    a=math.radians(az);d=4.2
    cam.location=Vector((d*math.sin(a),-d*math.cos(a),2.4))
    cam.rotation_euler=(Vector((0,0,0.7))-cam.location).to_track_quat("-Z","Y").to_euler()
    sc.render.filepath=os.path.abspath(f"art_requests/hq_vehicle_v2/{tag}_{name}.png");bpy.ops.render.render(write_still=True)
