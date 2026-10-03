import bpy, bmesh, math, os, json
from mathutils import Vector
OUT=os.path.dirname(os.path.abspath(__file__))
scene=bpy.data.scenes.new('War Cats • Minimal pickups')
bpy.context.window.scene=scene
roots=[]
collection=None
root=None

def mat(name,color):
 m=bpy.data.materials.new('WC '+name); m.use_nodes=True
 rgb=tuple(((v/255+0.055)/1.055)**2.4 if v/255>0.04045 else v/255/12.92 for v in color)
 m.diffuse_color=(*rgb,1)
 n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 n.inputs['Base Color'].default_value=(*rgb,1); n.inputs['Roughness'].default_value=.72
 return m
cream=mat('Ivory',(231,226,193)); coral=mat('Coral',(221,102,87)); olive=mat('Olive',(142,154,93)); gold=mat('Gold',(242,190,66)); blue=mat('Blue',(113,146,169)); ice=mat('Ice',(170,213,233)); gray=mat('Concrete',(170,173,173)); mint=mat('Armor',(153,179,123)); purple=mat('Turret',(159,145,177)); dark=mat('Graphite',(76,86,101)); ground=mat('Backdrop',(132,134,135))
def group(key,x):
 global collection,root
 collection=bpy.data.collections.new('Bonus • '+key); scene.collection.children.link(collection)
 root=bpy.data.objects.new('bonus_'+key,None); collection.objects.link(root); root.location.x=x; root.rotation_euler.z=math.radians(-16); roots.append(root)
 return root

def mesh(name,verts,faces,material,bevel=.025):
 me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
 bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
 ob=bpy.data.objects.new(name,me); collection.objects.link(ob); ob.parent=root; ob.data.materials.append(material)
 if bevel:
  mod=ob.modifiers.new('Soft edges','BEVEL'); mod.width=bevel; mod.segments=2
  ob.modifiers.new('Face normals','WEIGHTED_NORMAL')
 return ob

def box(name,loc,size,material,bevel=.025):
 x,y,z=[v/2 for v in size]
 ob=mesh(name,[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],material,bevel); ob.location=loc; return ob

def extrude(name,points,depth,material,y=0,bevel=.025):
 n=len(points); verts=[(x,y+d,z) for d in [-depth/2,depth/2] for x,z in points]
 # Polygon signed area: negative-Y-facing front needs CCW in XZ.
 area=sum(points[i][0]*points[(i+1)%n][1]-points[(i+1)%n][0]*points[i][1] for i in range(n))
 if area<0: return extrude(name,list(reversed(points)),depth,material,y,bevel)
 faces=[tuple(range(n)),tuple(range(n,2*n))[::-1]]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return mesh(name,verts,faces,material,bevel)

def cross(name,z,y,material,s=.55):
 a=s/2; b=s/6
 p=[(-b,z-a),(b,z-a),(b,z-b),(a,z-b),(a,z+b),(b,z+b),(b,z+a),(-b,z+a),(-b,z+b),(-a,z+b),(-a,z-b),(-b,z-b)]
 return extrude(name,p,.075,material,y,.012)

def rod(name,a,b,r,material,n=8,r2=None):
 a,b=Vector(a),Vector(b); d=b-a; length=d.length; r2=r if r2 is None else r2
 verts=[(rr*math.cos(i*2*math.pi/n),rr*math.sin(i*2*math.pi/n),z) for rr,z in [(r,0),(r2,length)] for i in range(n)]
 faces=[tuple(range(n))[::-1],tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 ob=mesh(name,verts,faces,material,.008); ob.location=a; ob.rotation_euler=d.to_track_quat('Z','Y').to_euler(); return ob

group('pressure',-8.8)
extrude('Lightning',[(-.14,1.68),(.47,1.68),(.09,1.02),(.48,1.02),(-.38,0),(-.13,.71),(-.52,.71)],.29,gold)

group('freeze',-6.6)
# Six continuous forked arms; a single extruded outline, no intersecting cubes.
base=[(-.095,.17),(-.095,.42),(-.32,.56),(-.25,.69),(-.095,.59),(-.095,.86),(.095,.86),(.095,.59),(.25,.69),(.32,.56),(.095,.42),(.095,.17)]
p=[]
for j in range(6):
 t=-j*math.pi/3
 for x,z in base: p.append((x*math.cos(t)-z*math.sin(t),.86+x*math.sin(t)+z*math.cos(t)))
extrude('Snowflake',p,.23,ice,bevel=.012)

for key,x,col,handle in [('heart',-4.4,cream,olive),('repair',-2.2,blue,dark)]:
 group(key,x); box('Case',(0,0,.53),(1.14,.54,1.06),col,.05)
 box('Handle left',(-.25,0,1.15),(.13,.18,.28),handle,.018); box('Handle right',(.25,0,1.15),(.13,.18,.28),handle,.018); box('Handle top',(0,0,1.28),(.63,.18,.13),handle,.018)
 if key=='heart': cross('Medical cross',.53,-.308,coral,.64)
 else:
  wrench=[(-.30,.20),(-.20,.14),(.15,.65),(.31,.69),(.40,.83),(.38,.96),(.24,.79),(.09,.85),(.12,1.02),(-.03,.91),(-.08,.76),(-.02,.66)]
  extrude('Wrench',wrench,.075,cream,-.31,.014)

group('wall',0)
box('Lower left',(-.32,0,.245),(.61,.58,.49),gray,.035); box('Lower right',(.32,0,.245),(.61,.58,.49),gray,.035); box('Top',(0,0,.755),(.61,.58,.49),gray,.035)
group('vehicle_repair',2.2)
extrude('Shield',[(-.58,1.30),(0,1.62),(.58,1.30),(.53,.56),(.31,.22),(0,0),(-.31,.22),(-.53,.56)],.28,mint,bevel=.045)
cross('Armor cross',.86,-.18,cream,.62)
group('turret',4.4)
rod('Foot',(0,0,.05),(0,0,.25),.58,dark,n=8)
rod('Turntable',(0,0,.25),(0,0,.39),.40,purple,n=8)
rod('Turret head',(0,0,.40),(0,0,.91),.44,purple,n=8,r2=.32)
rod('Barrel',(0,-.16,.68),(0,-.98,.68),.125,dark,n=10)
rod('Muzzle inset',(0,-.985,.68),(0,-.991,.68),.079,mat('Bore',(35,41,48)),n=10)
# Angle barrel sideways to keep its silhouette clear from delivery camera.
root.rotation_euler.z=math.radians(-44)
group('vehicle',6.6)
box('Supply crate',(0,0,.31),(.83,.65,.62),olive,.035)
for x in [-.27,.27]: box('Strap',(x,0,.31),(.075,.675,.64),dark,.006)
for x,y in [(-1,-1),(-1,1),(1,-1),(1,1)]: rod('Parachute cord',(x*.29,y*.22,.59),(x*.55,y*.40,1.43),.019,cream,n=6)
# Low-poly umbrella with three broad rings.
verts=[(0,0,2.10)]; n=12
for r,z in [(.33,2.00),(.63,1.77),(.76,1.43)]:
 verts += [(r*math.cos(i*2*math.pi/n),r*math.sin(i*2*math.pi/n),z) for i in range(n)]
faces=[(0,1+i,1+(i+1)%n) for i in range(n)]
for k in range(2):
 a=1+k*n; b=a+n
 faces += [(a+i,b+i,b+(i+1)%n,a+(i+1)%n) for i in range(n)]
mesh('Canopy',verts,faces,gold,0)
group('star',8.8)
p=[((.84 if i%2==0 else .38)*math.cos(math.pi/2+i*math.pi/5),.76+(.84 if i%2==0 else .38)*math.sin(math.pi/2+i*math.pi/5)) for i in range(10)]
minz=min(z for x,z in p); p=[(x,z-minz) for x,z in p]
extrude('Star',p,.30,gold,bevel=.035)

collection=bpy.data.collections.new('Studio'); scene.collection.children.link(collection); root=None
box('Gray floor',(0,0,-.065),(200,200,.12),ground,0)
cdata=bpy.data.cameras.new('Lineup camera'); cam=bpy.data.objects.new('Lineup camera',cdata); collection.objects.link(cam)
cam.location=(0,-24,12); target=Vector((0,0,.8)); cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler(); cdata.type='ORTHO'; cdata.ortho_scale=21.4; scene.camera=cam
for name,loc,power,size in [('Key',(-7,-7,10),2400,8),('Fill',(8,-4,7),1700,9),('Rim',(0,5,8),2000,10)]:
 data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape=next(i.identifier for i in data.bl_rna.properties['shape'].enum_items if i.identifier=='DISK'); data.size=size
 ob=bpy.data.objects.new(name,data); collection.objects.link(ob); ob.location=loc; ob.rotation_euler=(Vector((0,0,.5))-ob.location).to_track_quat('-Z','Y').to_euler()
world=bpy.data.worlds.new('Soft gray studio'); world.use_nodes=True
node=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND'); node.inputs[0].default_value=(.3,.3,.3,1); node.inputs[1].default_value=.55; scene.world=world
scene.render.engine='BLENDER_EEVEE'; scene.render.resolution_x=2400; scene.render.resolution_y=800; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.filepath=os.path.join(OUT,'lineup.png')
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  area.spaces.active.region_3d.view_perspective='CAMERA'; area.spaces.active.region_3d.view_camera_zoom=18; area.spaces.active.overlay.show_overlays=False
  area.spaces.active.shading.type='MATERIAL'
scene['description']='Nine editable minimalist bonus concepts, separate from live game assets.'
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'warcats_minimal_pickups.blend'))
print('Created',len(roots),'bonus roots;',len(scene.objects),'objects')
