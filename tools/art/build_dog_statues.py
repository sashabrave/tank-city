import bpy, math, sys
from mathutils import Vector
OUT="/Users/sashabrave/Desktop/tank-roguelite-claude/assets/models/concrete_v1/statue_dog_%d.glb"
def mat(name,rgb,metal,rough):
    m=bpy.data.materials.new(name);m.use_nodes=True;b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*rgb,1);b.inputs["Metallic"].default_value=metal;b.inputs["Roughness"].default_value=rough;return m
def add(kind,loc,scale,m,rot=(0,0,0),**kw):
    if kind=="sphere":bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,location=loc)
    elif kind=="cyl":bpy.ops.mesh.primitive_cylinder_add(vertices=16,location=loc,**kw)
    else:bpy.ops.mesh.primitive_cube_add(location=loc)
    o=bpy.context.active_object;o.scale=scale;o.rotation_euler=[math.radians(a) for a in rot]
    o.data.materials.append(m)
    if kind=="cube":
        bv=o.modifiers.new("b","BEVEL");bv.width=0.04;bv.segments=3
    bpy.ops.object.shade_smooth();return o
for variant in range(3):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    stone=mat("stone",(0.52,0.5,0.46),0.0,0.85);bronze=mat("bronze",(0.30,0.40,0.33),0.75,0.38);gold=mat("gold",(0.85,0.62,0.25),0.9,0.3)
    # Pedestal: one cell, stepped.
    add("cube",(0,0,0.28),(0.46,0.46,0.28),stone);add("cube",(0,0,0.6),(0.4,0.4,0.05),stone)
    add("cube",(0,-0.405,0.3),(0.2,0.01,0.07),gold)  # name plate
    z0=0.65
    # Chubby sitting dog: big belly, round head, droopy ears, officer cap.
    add("sphere",(0,0.03,z0+0.34),(0.30,0.27,0.36),bronze)            # body
    for x in (-0.17,0.17):add("sphere",(x,-0.12,z0+0.07),(0.1,0.13,0.08),bronze)  # front paws
    for x in (-0.22,0.22):add("sphere",(x,0.1,z0+0.1),(0.11,0.16,0.11),bronze)    # hind legs
    add("sphere",(0,-0.02,z0+0.86),(0.25,0.23,0.23),bronze)          # head
    add("sphere",(0,-0.21,z0+0.8),(0.12,0.11,0.09),bronze)           # snout
    add("sphere",(0,-0.31,z0+0.83),(0.045,0.035,0.035),bronze)       # nose
    for x in (-1,1):add("sphere",(x*0.23,0.0,z0+0.78),(0.06,0.11,0.17),bronze,rot=(0,x*-20,0))  # ears
    add("cyl",(0,0.0,z0+1.07),(0.22,0.22,0.06),bronze,depth=1)         # cap crown
    add("cube",(0,-0.18,z0+1.03),(0.16,0.09,0.015),bronze,rot=(-12,0,0)) # visor
    add("sphere",(0,-0.2,z0+1.08),(0.04,0.015,0.04),gold)            # cap badge
    for x in (-1,1):add("cube",(x*0.27,0.02,z0+0.6),(0.09,0.08,0.02),gold,rot=(0,x*25,0))  # epaulettes
    for i in range(3):add("cyl",(-0.08+i*0.08,-0.255,z0+0.45),(0.03,0.03,0.008),gold,rot=(80,0,0),depth=1)  # medals
    add("sphere",(0.0,0.3,z0+0.15),(0.06,0.14,0.06),bronze,rot=(40,0,0)) # tail
    if variant==0:  # sabre raised to the right
        add("cube",(0.36,-0.08,z0+0.75),(0.025,0.02,0.32),bronze,rot=(0,-35,0));add("cube",(0.26,-0.08,z0+0.47),(0.07,0.03,0.02),gold,rot=(0,-35,0))
    elif variant==1:  # binoculars on the chest
        for x in (-0.06,0.06):add("cyl",(x,-0.29,z0+0.6),(0.045,0.045,0.06),bronze,rot=(90,0,0),depth=1)
    else:  # flag on a pole
        add("cyl",(0.33,0.05,z0+0.75),(0.02,0.02,0.75),bronze,depth=1);add("cube",(0.5,0.05,z0+1.3),(0.16,0.01,0.11),bronze)
    bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=bpy.context.selected_objects[0]
    for o in bpy.context.selected_objects:
        bpy.context.view_layer.objects.active=o
        for m in o.modifiers:bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.object.join();o=bpy.context.active_object;o.name="statue_dog_%d"%variant
    bpy.ops.export_scene.gltf(filepath=OUT%variant,export_format='GLB',use_selection=True)
    print("DOG",variant,"tris",sum(len(p.vertices)-2 for p in o.data.polygons),"height",max(v.co.z for v in o.data.vertices))
