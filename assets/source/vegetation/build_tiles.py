"""Original low-poly miniature forest tiles. Run through Blender MCP; preserves existing scenes."""
import bpy, math, random, contextlib, io
from mathutils import Vector
from pathlib import Path
ROOT=Path('/Users/sashabrave/Desktop/tank-roguelite')
scene=bpy.data.scenes.new('R13 vegetation final 15')
bpy.context.window.scene=scene
materials=[]
for name,color in [('Bark',(.24,.20,.16,1)),('Needles',(.24,.38,.25,1)),('Tips',(.42,.54,.31,1)),('Palm',(.40,.54,.25,1)),('Charcoal',(.20,.19,.18,1)),('Ash',(.43,.40,.37,1)),('Snow',(.75,.82,.82,1)),('Stone',(.43,.46,.41,1)),('Dry grass',(.49,.43,.29,1))]:
 m=bpy.data.materials.new('R13 lush '+name);m.diffuse_color=color;m.use_nodes=True
 n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');n.inputs['Base Color'].default_value=color;n.inputs['Roughness'].default_value=.9
 materials.append(m)

def tile(family,variant):
 rng=random.Random(9100+variant*131)
 verts=[];faces=[];mats=[];wind=[]
 phase=0.0;period=0.0;flexibility=0.0
 def face(points,mat):
  start=len(verts);verts.extend(points);faces.append(tuple(range(start,len(verts))));mats.append(mat)
  wind.extend([(min(1,max(0,p[2])/2.1)**1.7*flexibility,phase,period,1) for p in points])
 def branch(a,b,r1,r2,mat,sides=6):
  a=Vector(a);b=Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((0,1,0))).normalized()
  if u.length<.1:u=Vector((1,0,0))
  v=axis.cross(u).normalized()
  ring1=[a+(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides))*r1 for i in range(sides)]
  ring2=[b+(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides))*r2 for i in range(sides)]
  for i in range(sides):j=(i+1)%sides;face([ring1[i],ring1[j],ring2[j],ring2[i]],mat)
  face(list(reversed(ring1)),mat);face(ring2,mat)
 def crown(x,y,z,r,h,mat,angle):
  n=9;low=[];mid=[]
  for i in range(n):
   a=angle+i*math.tau/n;rr=r*(.91+.09*rng.random())
   low.append((x+math.cos(a)*rr,y+math.sin(a)*rr,z+rng.uniform(-.025,.025)))
   mid.append((x+math.cos(a)*rr*.59,y+math.sin(a)*rr*.59,z+h*.56))
  for i in range(n):
   j=(i+1)%n;face([low[i],low[j],mid[j],mid[i]],mat+(1 if mat==1 and i%3==0 else 0));face([mid[i],mid[j],(x,y,z+h)],mat)
  face(list(reversed(low)),mat)
 def cushion(x,y,z,r,h,mat):
  n=8;rings=[]
  for level,scale in [(0,.65),(.3,1),(.72,.88),(1,.32)]:
   rings.append([(x+math.cos(i*math.tau/n)*r*scale,y+math.sin(i*math.tau/n)*r*scale,z+h*level) for i in range(n)])
  for k in range(3):
   for i in range(n):j=(i+1)%n;face([rings[k][i],rings[k][j],rings[k+1][j],rings[k+1][i]],mat)
  face(rings[-1],mat);face(list(reversed(rings[0])),mat)
 layouts=[ [(-.28,-.27),(.27,-.22),(-.25,.26),(.28,.28)],
           [(-.30,-.25),(.24,-.28),(-.10,.05),(.25,.30)],
           [(-.30,-.25),(.27,-.22),(-.27,.28),(.22,.26),(.0,.04)],
           [(-.30,-.26),(.28,-.14),(-.19,.30)],
           [(-.27,-.29),(.30,-.24),(-.31,.23),(.22,.28)] ]
 for i,(x,y) in enumerate(layouts[variant]):
  x+=rng.uniform(-.045,.045);y+=rng.uniform(-.045,.045)
  h=rng.uniform(1.45,2.0)*(0.74 if variant==2 and i==4 else 1)
  phase=rng.random();period=rng.random();flexibility=.28 if family=='charred' else 1.0
  if family=='palm':
   h*=.88;lean=rng.uniform(-.09,.09)
   branch((x,y,0),(x+lean*.3,y,h*.5),.053,.038,0)
   branch((x+lean*.3,y,h*.5),(x+lean,y,h),.038,.028,0)
   for j in range(11):
    a=j*math.tau/11+rng.uniform(-.13,.13);radius=.33 if j%2 else .39
    base=Vector((x+lean,y,h));direction=Vector((math.cos(a),math.sin(a),0));side=Vector((-math.sin(a),math.cos(a),0))
    mid=base+direction*radius*.55+Vector((0,0,.12));end=base+direction*radius+Vector((0,0,-.22))
    ridge=mid+Vector((0,0,.038))
    face([base,mid+side*.075,ridge],3);face([base,ridge,mid-side*.075],2)
    face([mid+side*.075,end,ridge],3);face([ridge,end,mid-side*.075],2)
   cushion(x+lean,y,h-.10,.08,.12,0)
  elif family=='charred':
   branch((x,y,0),(x+.025,y,h),.073,.015,4)
   for j in range(6):
    a=j*2.4+i;z=h*(.27+j*.095);end=(x+math.cos(a)*.25,y+math.sin(a)*.25,z+.24)
    branch((x,y,z),end,.033,.010,4)
    for side in [-1,1]:branch(end,(end[0]+math.cos(a+side*.6)*.12,end[1]+math.sin(a+side*.6)*.12,end[2]+.16),.010,.002,5)
  elif family=='broadleaf':
   branch((x,y,0),(x,y,h*.75),.065,.023,0)
   for j in range(4):
    a=j*1.7+i;xx=x+math.cos(a)*.13;yy=y+math.sin(a)*.13
    branch((x,y,h*.4),(xx,yy,h*.6),.027,.009,0)
    cushion(xx,yy,h*.44+j*.075,.24,.51,1 if j%2 else 2)
   cushion(x,y,h*.72,.23,.43,1)
  else:
   branch((x,y,0),(x,y,h),.054,.012,0)
   for j in range(5):
    z=.22+j*(h-.28)/5;r=.30-j*.046
    crown(x,y,z,r,(h-z)*.61,1,variant+i*.8)
    if family=='frost':crown(x,y,z+.105,r*.82,(h-z)*.51,6,variant+i*.8)
 # Uneven low edge dressing defines the whole tile without a square platform.
 for j in range(10):
  a=(j+.25+rng.uniform(-.18,.18))*math.tau/10
  x=math.cos(a)*.43;y=math.sin(a)*.43;phase=rng.random();period=rng.random();flexibility=.8
  if family=='charred':
   flexibility=0
   if j%3==0:branch((x-.075,y,.05),(x+.085,y+.035,.045),.041,.025,4)
   else:cushion(x,y,0,.06+rng.random()*.035,.05+rng.random()*.05,5 if j%2 else 7)
   if j%2:
    flexibility=.7
    for k in range(3):branch((x,y,.025),(x+rng.uniform(-.055,.055),y+rng.uniform(-.055,.055),rng.uniform(.12,.21)),.008,.001,8,4)
  elif j%3==0:
   flexibility=0;cushion(x,y,0,.065+rng.random()*.04,.07+rng.random()*.07,7)
   if family=='frost':cushion(x,y,.06,.07,.07,6)
  elif family=='palm':
   for k in range(5):
    b=k*math.tau/5;face([(x,y,.01),(x+math.cos(b-.2)*.06,y+math.sin(b-.2)*.06,.13),(x+math.cos(b)*.11,y+math.sin(b)*.11,.20)],3)
  else:
   cushion(x,y,.0,.105+rng.random()*.025,.17+rng.random()*.09,1 if j%2 else 2)
   if family=='frost':cushion(x,y,.12,.085,.08,6)
 name=f'{family}_{variant:02d}'
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces)
 for m in materials:mesh.materials.append(m)
 for p,idx in zip(mesh.polygons,mats):p.material_index=idx
 # Wind data is per-vertex, per-tree; exported COLOR_0 is consumed only by the wind shader.
 colors=mesh.color_attributes.new(name='WindData',type='FLOAT_COLOR',domain='POINT')
 for i,value in enumerate(wind):colors.data[i].color=value
 mesh.color_attributes.active_color=colors
 xs=[v.co.x for v in mesh.vertices];ys=[v.co.y for v in mesh.vertices];bottom=min(v.co.z for v in mesh.vertices)
 scale=.94/max(max(xs)-min(xs),max(ys)-min(ys));cx=(max(xs)+min(xs))*.5;cy=(max(ys)+min(ys))*.5
 for v in mesh.vertices:v.co.x=(v.co.x-cx)*scale;v.co.y=(v.co.y-cy)*scale;v.co.z-=bottom
 mesh.update();obj=bpy.data.objects.new(name,mesh);scene.collection.objects.link(obj);obj["tile_id"]=name
 return obj
families=['spruce','palm','charred','broadleaf','frost']
with contextlib.redirect_stdout(io.StringIO()):
 for row,family in enumerate(families):
  for variant in range(3):
   obj=tile(family,variant)
   bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
   bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/vegetation'/f"{obj['tile_id']}.glb"),use_selection=True,use_active_scene=True,export_all_vertex_colors=False,export_vertex_color='ACTIVE')
   obj.location=(variant*1.5,row*1.65,0)
bpy.data.libraries.write(str(ROOT/'assets/source/vegetation/vegetation_tiles.blend'),{scene})
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  region=area.spaces.active.region_3d;region.view_location=(1.5,3.2,.8);region.view_distance=10
  region.view_rotation=Vector((6,-9,9)).to_track_quat('Z','Y')
print('Created 15 lush tiles with per-tree wind data and low edge dressing.')
