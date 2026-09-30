"""Extract approved GLB hierarchies; drop exhibition props and incompatible demo clips."""
import json,struct,copy,pathlib
root=pathlib.Path(__file__).resolve().parents[1]
b=(root/'art_demo/cozy_full_roster.glb').read_bytes();n=struct.unpack_from('<I',b,12)[0];src=json.loads(b[20:20+n]);binary=b[28+n:]
names={o.get('name'):i for i,o in enumerate(src['nodes'])}
assets={k:k.upper()+'_ROOT' for k in ['soldier','grenadier','shield','sniper','buggy','apc','tank','boss','drone','flyer','mortar','turret']}
assets.update({'bonus_'+k:'BONUS_'+k.upper() for k in ['heart','repair','wall','vehicle_repair','turret','vehicle','star']})
assets.update({'weapon_'+k:v for k,v in {'pistol':'WEAPON_PISTOL.001','smg':'WEAPON_SMG.001','shotgun':'WEAPON_SHOTGUN','rifle':'WEAPON_RIFLE','sniper':'WEAPON_SNIPER.001','rpg':'WEAPON_RPG','mg':'WEAPON_MG'}.items()})
for asset,name in assets.items():
 selected=[]
 def visit(i):
  if 'plinth' in src['nodes'][i].get('name','').lower():return
  selected.append(i)
  for c in src['nodes'][i].get('children',[]):visit(c)
 visit(names[name]);mapping={old:i for i,old in enumerate(selected)}
 nodes=[copy.deepcopy(src['nodes'][i]) for i in selected]
 for node in nodes:
  node.pop('extras',None)
  if 'children' in node:node['children']=[mapping[c] for c in node['children'] if c in mapping]
  if 'yaw' in node.get('name','').lower():node.pop('rotation',None)
 nodes[0]['translation']=[0,0,0]
 if asset.startswith('weapon_'):nodes[0].pop('rotation',None)
 mids=sorted({o['mesh'] for o in nodes if 'mesh' in o});mm={o:i for i,o in enumerate(mids)};meshes=[copy.deepcopy(src['meshes'][i]) for i in mids]
 for node in nodes:
  if 'mesh' in node:node['mesh']=mm[node['mesh']]
 aids=set();mats=set()
 for mesh in meshes:
  for p in mesh['primitives']:
   aids.update(p['attributes'].values())
   if 'indices' in p:aids.add(p['indices'])
   if 'material' in p:mats.add(p['material'])
 aids=sorted(aids);am={o:i for i,o in enumerate(aids)};mats=sorted(mats);matmap={o:i for i,o in enumerate(mats)}
 for mesh in meshes:
  for p in mesh['primitives']:
   p['attributes']={k:am[v] for k,v in p['attributes'].items()}
   if 'indices' in p:p['indices']=am[p['indices']]
   if 'material' in p:p['material']=matmap[p['material']]
 accessors=[copy.deepcopy(src['accessors'][i]) for i in aids];views=sorted({a['bufferView'] for a in accessors});vm={o:i for i,o in enumerate(views)};outbin=bytearray();outviews=[]
 for i in views:
  v=copy.deepcopy(src['bufferViews'][i]);offset=v.get('byteOffset',0);chunk=binary[offset:offset+v['byteLength']]
  while len(outbin)%4:outbin.append(0)
  v['byteOffset']=len(outbin);v['buffer']=0;outbin.extend(chunk);outviews.append(v)
 for a in accessors:a['bufferView']=vm[a['bufferView']]
 d={'asset':{'version':'2.0','generator':'Tank City isolated cozy export'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':nodes,'meshes':meshes,'materials':[src['materials'][i] for i in mats],'accessors':accessors,'bufferViews':outviews,'buffers':[{'byteLength':len(outbin)}]}
 j=json.dumps(d,separators=(',',':')).encode();j+=b' '*((-len(j))%4);outbin+=b'\0'*((-len(outbin))%4)
 out=struct.pack('<III',0x46546c67,2,28+len(j)+len(outbin))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(outbin),0x004e4942)+outbin
 (root/'assets/models/cozy'/f'{asset}.glb').write_bytes(out)
 print(asset,len(out))
