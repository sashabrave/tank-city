"""Run inside Blender through MCP. Keeps pre-existing scenes intact."""
import bpy, math, os
from mathutils import Vector
ROOT = '/Users/sashabrave/Desktop/tank-roguelite'
scene = bpy.data.scenes.new('R13_AssetWorkshop')
bpy.context.window.scene = scene
for old in list(bpy.data.scenes):
    if old != scene and old.name.startswith('R13_AssetWorkshop'):
        obs=list(old.objects)
        bpy.data.scenes.remove(old)
        for ob in obs:
            if ob.users==0: bpy.data.objects.remove(ob)
materials = {}
for name, color in {'stone':(.53,.56,.52,1), 'ivory':(.80,.82,.75,1), 'orange':(.96,.43,.065,1), 'dark':(.12,.16,.16,1), 'steel':(.31,.37,.36,1), 'red':(.70,.19,.12,1)}.items():
    m = bpy.data.materials.new('R13_'+name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    slots = {s.name:s for s in bsdf.inputs}
    slots['Base Color'].default_value = color
    slots['Roughness'].default_value = .82
    m.diffuse_color = color
    materials[name] = m

parts=[]
def cube(name, loc, size, mat, bevel=.045):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob=bpy.context.object; ob.name=name; ob.dimensions=size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(materials[mat])
    if bevel:
        mod=ob.modifiers.new('Soft manufactured edges','BEVEL'); mod.width=bevel; mod.segments=2
    parts.append(ob)
    return ob

def sphere(name, loc, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1, location=loc)
    ob=bpy.context.object; ob.name=name; ob.scale=scale; ob.data.materials.append(materials[mat]); parts.append(ob)
    for p in ob.data.polygons: p.use_smooth=True
    return ob

def cylinder(name, loc, radius, depth, mat, axis=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=depth, location=loc)
    ob=bpy.context.object; ob.name=name; ob.data.materials.append(materials[mat]); parts.append(ob)
    if axis: ob.rotation_euler=axis
    mod=ob.modifiers.new('Rim bevel','BEVEL'); mod.width=.025; mod.segments=2
    return ob

def export(name):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts: ob.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/models/'+name+'.glb', use_selection=True, use_active_scene=True, export_apply=True)
    # Show every editable model in a neatly spaced workshop after export.
    index=len(exports); offset=Vector(((index%4)*2.8,(index//4)*3.2,0))
    for ob in parts: ob.location += offset
    exports.append(name); parts.clear()
exports=[]
# Soldier: forward is +Y in Blender / -Z in Godot.
for x in [-.16,.16]:
    cube('Soldier boot',(x,0,.10),(.23,.35,.20),'dark')
    cube('Soldier leg',(x,-.015,.29),(.18,.22,.25),'steel')
cube('Soldier body',(0,0,.55),(.47,.30,.43),'ivory',.09)
cube('Orange chest plate',(0,.17,.57),(.32,.065,.23),'orange',.025)
sphere('Helmet',(0,0,.99),(.31,.28,.29),'ivory')
cube('Visor',(0,.249,.99),(.46,.07,.14),'orange',.045)
cube('Backpack',(0,-.22,.55),(.29,.16,.32),'dark')
for x in [-.32,.32]: sphere('Glove',(x,.16,.53),(.10,.11,.12),'dark')
cube('Rifle',(0.25,.36,.57),(.12,.48,.13),'dark',.025)
export('soldier')
for vehicle in ['apc','tank','boss']:
    tank=vehicle!='apc'; boss=vehicle=='boss'; wide=1.12 if boss else .83
    for x in [-wide*.47,wide*.47]:
        cube('Track housing',(x,0,.24),(.23,1.02,.33),'dark',.075)
        for y in [-.35,0,.35]:
            cylinder('Road wheel',(x+(.025 if x>0 else -.025),y,.24),.12,.25,'steel',(0,math.pi/2,0))
    cube('Armored hull',(0,0,.40),(wide,.89,.34),'steel',.075)
    cube('Orange armor',(0,.07,.56),(wide*.8,.61,.19),'orange',.065)
    cube('Turret',(0,-.06,.73),(.63 if tank else .38,.50,.30),'orange',.065)
    cylinder('Gun barrel',(0,.43,.76),.085 if tank else .055,.75 if tank else .52,'dark',(math.pi/2,0,0))
    cylinder('Muzzle rim',(0,.79 if tank else .66,.76),.102 if tank else .07,.07,'steel',(math.pi/2,0,0))
    for x in [-wide*.31,wide*.31]: cube('Headlight',(x,.48,.44),(.105,.06,.08),'ivory',.01)
    if boss:
        cube('Command armor',(0,-.12,.93),(.36,.36,.10),'red')
        for x in [-.53,.53]: cube('Side armor',(x,0,.50),(.14,.82,.22),'red')
    export(vehicle)
cube('Foundation',(0,0,.10),(1.55,1.25,.20),'dark')
cube('Bunker',(0,0,.42),(1.34,1.0,.57),'stone',.08)
cube('Roof',(0,0,.78),(1.52,1.2,.18),'ivory')
cube('Blast door',(0,.51,.40),(.48,.06,.46),'dark')
cube('Door stripe',(0,.56,.44),(.33,.04,.09),'orange',.008)
cylinder('Antenna',(.48,-.22,1.15),.025,.67,'dark')
sphere('Beacon',(.48,-.22,1.5),(.075,.075,.075),'orange')
export('base')
cube('Tile',(0,0,-.10),(.976,.976,.20),'stone',.024)
export('tile')
for typ in ['wall','crate']:
    cube(typ,(0,0,.42),(.93,.93,.84),'stone' if typ=='wall' else 'orange',.04)
    if typ=='crate':
        for x in [-.36,.36]: cube('Crate brace',(x,.476,.42),(.09,.045,.75),'ivory',.008)
        cube('Crate cross',(0,.48,.42),(.8,.045,.085),'ivory',.008).rotation_euler.y=.65
    else:
        for z in [.28,.57]: cube('Masonry seam',(0,.47,z),(.88,.009,.025),'dark',0)
    export(typ)
cylinder('Turret foot',(0,0,.10),.33,.17,'dark')
cylinder('Turret stem',(0,0,.30),.12,.34,'steel')
cube('Turret head',(0,0,.56),(.41,.36,.32),'orange')
cylinder('Turret gun',(0,.30,.56),.06,.50,'dark',(math.pi/2,0,0))
export('turret')
cube('Bench',(0,0,.45),(1.7,.75,.17),'ivory')
for x in [-.67,.67]: cube('Bench leg',(x,0,.23),(.15,.61,.46),'dark')
cube('Machine',(0,-.12,.80),(.56,.48,.62),'orange')
cube('Machine screen',(0,.14,.91),(.33,.055,.18),'dark')
export('workbench')
for x in [-1.05,1.05]: cube('Gate pillar',(x,0,1.05),(.35,.65,2.1),'stone')
cube('Gate lintel',(0,0,2.14),(2.46,.68,.30),'ivory')
cube('Gate marking',(0,.36,2.12),(1.1,.035,.10),'orange')
export('gate')
# Brick is recognizable masonry, concrete remains an uninterrupted slab.
for row in range(3):
 for col in range(2):
  cube('Destructible brick',(col*.46-.23,0,row*.22+.11),(.435,.91,.20),'orange',.015)
export('brick')
# Mesh net: open weave reveals silhouettes underneath.
for x,y in [(-.46,-.46),(.46,-.46),(-.46,.46),(.46,.46)]:
 cube('Net support',(x,y,.57),(.035,.035,1.14),'steel',.008)
for step in range(6):
 v=-.46+step*.184
 cube('Camouflage mesh',(v,0,1.15),(.038,.96,.025),'stone',.006)
 cube('Camouflage mesh',(0,v,1.16),(.96,.038,.025),'steel',.006)
for x,y in [(-.27,-.26),(.1,.13),(.3,-.15),(-.1,.31)]:
 cube('Cloth camouflage patch',(x,y,1.18),(.22,.24,.023),'stone',.012)
export('net')

# Low-profile bomb courier, with four small wheels and a visible payload.
for x in [-.26,.26]:
    for y in [-.19,.19]:
        cylinder('Drone wheel',(x,y,.12),.12,.11,'dark',(0,math.pi/2,0))
cube('Drone chassis',(0,0,.20),(.47,.53,.16),'steel',.055)
cube('Bomb payload',(0,-.08,.35),(.35,.34,.22),'orange',.045)
cube('Robot sensor',(0,.22,.29),(.32,.09,.13),'dark',.025)
sphere('Sensor eye',(0,.27,.31),(.06,.035,.045),'red')
export('drone')
# Grenadier: a round grenade in the raised hand and a compact backpack.
for x in [-.16,.16]:
 cube('Grenadier boot',(x,0,.10),(.23,.35,.20),'dark')
 cube('Grenadier leg',(x,0,.29),(.18,.22,.25),'steel')
cube('Grenadier jacket',(0,0,.57),(.47,.34,.46),'steel',.09)
sphere('Grenadier helmet',(0,0,1.0),(.31,.28,.28),'ivory')
cube('Grenadier visor',(0,.25,1.0),(.43,.06,.12),'orange')
cube('Grenade pack',(0,-.23,.6),(.35,.18,.36),'orange')
sphere('Raised hand',(.32,.1,.82),(.1,.1,.13),'dark')
sphere('Held grenade',(.32,.12,1.02),(.13,.13,.16),'orange')
export('grenadier')
for x in [-.4,.4]:
 for y in [-.32,.32]:cylinder('Buggy tire',(x,y,.21),.21,.17,'dark',(0,math.pi/2,0))
cube('Buggy chassis',(0,0,.27),(.67,.9,.18),'steel')
cube('Buggy hood',(0,.3,.42),(.62,.35,.20),'orange')
cube('Seat',(0,-.1,.48),(.37,.3,.24),'dark')
for x in [-.28,.28]:cube('Roll cage',(x,-.25,.66),(.055,.055,.7),'steel',.01)
cube('Cage bar',(0,-.25,1.0),(.61,.06,.06),'steel',.01)
cube('Machine gun mount',(0,0,.9),(.28,.27,.2),'orange')
cylinder('Machine gun',(0,.37,.95),.042,.65,'dark',(math.pi/2,0,0))
export('buggy')
cylinder('Mortar base',(0,0,.12),.4,.23,'dark')
cube('Mortar armor',(0,0,.36),(.6,.55,.34),'orange')
cylinder('Mortar barrel',(0,.12,.73),.13,.65,'steel',(math.pi/5,0,0))
export('mortar')
# Workshop camera, not exported into model files.
bpy.ops.object.camera_add(location=(12,-14,14))
cam=bpy.context.object; cam.name='R13_WorkshopCamera'; cam.rotation_euler=(Vector((4,3,0))-cam.location).to_track_quat('-Z','Y').to_euler(); scene.camera=cam
cam.data.type=next(e.identifier for e in cam.data.bl_rna.properties['type'].enum_items if e.identifier=='ORTHO'); cam.data.ortho_scale=16
bpy.ops.object.light_add(type=next(e.identifier for e in bpy.types.Light.bl_rna.properties['type'].enum_items if e.identifier=='AREA'), location=(1,-4,10))
bpy.context.object.data.energy=1800; bpy.context.object.data.shape=next(e.identifier for e in bpy.context.object.data.bl_rna.properties['shape'].enum_items if e.identifier=='DISK'); bpy.context.object.data.size=8
scene.world=bpy.data.worlds.new('R13_World'); scene.world.color=(.65,.65,.65)
scene.render.resolution_x=1000; scene.render.resolution_y=800; scene.render.resolution_percentage=100
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/assets/source/r13_models.blend')
print('R13 exported:',exports)
