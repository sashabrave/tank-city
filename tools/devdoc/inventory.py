# -*- coding: utf-8 -*-
import json,struct,os,re,subprocess,sys
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'..','..'))
os.chdir(ROOT)
code=''
for d in ['scripts','scenes','tools']:
    for dp,_,fs in os.walk(d):
        for f in fs:
            if f.endswith(('.gd','.tscn','.tres','.py')):
                try:code+=open(os.path.join(dp,f),encoding='utf-8',errors='ignore').read()+'\n'
                except:pass
def glb(path):
    b=open(path,'rb').read()
    ln,typ=struct.unpack_from('<II',b,12)
    j=json.loads(b[20:20+ln])
    tris=0
    for m in j.get('meshes',[]):
        for p in m['primitives']:
            if 'indices' in p:tris+=j['accessors'][p['indices']]['count']//3
            else:tris+=j['accessors'][p['attributes']['POSITION']]['count']//3
    anims=[a.get('name','anim%d'%i) for i,a in enumerate(j.get('animations',[]))]
    imgs=[i.get('uri') for i in j.get('images',[]) if i.get('uri')]
    return {'tris':tris,'meshes':len(j.get('meshes',[])),'materials':[m.get('name','') for m in j.get('materials',[])],'animations':anims,'external':imgs,'nodes':len(j.get('nodes',[])),'skins':len(j.get('skins',[]))}
out=[]
for dp,_,fs in os.walk('assets'):
    for f in sorted(fs):
        if not f.endswith('.glb'):continue
        p=os.path.join(dp,f);name=f[:-4];folder=os.path.relpath(dp,'assets/models') if dp.startswith('assets/models') else dp
        info=glb(p)
        # usage: full path, folder+name, or bare name within Visuals.model style lookups
        used=('res://'+p) in code or (folder+'/'+f) in code
        if not used:
            used=bool(re.search(r'["\']'+re.escape(name)+r'["\']',code)) and folder in ('.','environment_v7','cover_v1','vehicles_v6','infantry_v6','bonuses_v6','chests_v6','vegetation','concrete_v1','cozy')
        info.update({'path':p,'name':name,'folder':folder,'kb':os.path.getsize(p)//1024,'used':used})
        out.append(info)
# Status by family: what Visuals.model / kit_model load today, what is a fallback, what is an older generation.
CURRENT={'infantry_v6','vehicles_v6','environment_v7','bonuses_v6','chests_v6','concrete_v1','cover_v1','vegetation'}
LEGACY={'infantry_v5'}
for o in out:
    f=o['folder']
    if f in CURRENT:o['status'],o['status_text']=('current','Текущая модель')
    elif f in LEGACY:o['status'],o['status_text']=('legacy','Предыдущее поколение')
    elif f=='kit_v4':o['status'],o['status_text']=('fallback','Запасная геометрия (kit_v4)')
    elif o['used']:o['status'],o['status_text']=('current','Используется')
    else:o['status'],o['status_text']=('legacy','Старая / резервная версия')
json.dump(out,open(sys.argv[1],'w'),ensure_ascii=False,indent=1)
from collections import Counter
print(len(out),'models; used',sum(o['used'] for o in out))
print(Counter((o['folder'],o['status']) for o in out))
print('with animations',[(o['folder'],o['name'],len(o['animations'])) for o in out if o['animations']][:20])
print('external textures',sum(len(o['external']) for o in out),set(e for o in out for e in o['external']) and list(set(e for o in out for e in o['external']))[:6])
