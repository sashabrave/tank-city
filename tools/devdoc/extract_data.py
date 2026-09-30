# -*- coding: utf-8 -*-
import json,os,re,sys
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'..','..'))
os.chdir(ROOT)
def tres(path):
    out={}
    for line in open(path,encoding='utf-8'):
        m=re.match(r'^([a-z_]+) = (.+)$',line.strip())
        if not m:continue
        k,v=m.groups()
        if v.startswith('"'):v=v.strip('"')
        elif v in('true','false'):v=v=='true'
        else:
            try:v=float(v) if '.' in v else int(v)
            except:pass
        out[k]=v
    return out
def folder(p):
    return [dict(tres(os.path.join(p,f)),file=f) for f in sorted(os.listdir(p)) if f.endswith('.tres')]
data={}
data['enemies']=folder('assets/balance/enemies')
data['weapons']=folder('assets/balance/weapons')
data['abilities']=folder('assets/balance/abilities')
data['stats']=folder('assets/balance/stats')
cards=folder('assets/balance/upgrades')
data['cards']=[{k:c.get(k) for k in ['id','title','category','family','min_tier','flag','weight','max_stacks','preview','detail','file']} for c in cards]
# biomes from catalog source
src=open('scripts/biome_catalog.gd',encoding='utf-8').read()
data['biomes']=[]
for line in src.split('\n'):
    line=line.strip()
    if line.startswith('{') and '"name"' in line:
        b=dict(re.findall(r'"([a-z_]+)":"([^"]*)"',line))
        k=re.search(r'"kinds":\[(.*?)\]',line)
        b['kinds']=re.findall(r'"([a-z]+)"',k.group(1)) if k else []
        data['biomes'].append(b)
th=json.load(open('assets/audio/music/themes.json',encoding='utf-8'))
data['music']=[{'id':k,'title':v.get('title',k) if isinstance(v,dict) else k,'mood':v.get('mood','') if isinstance(v,dict) else ''} for k,v in th.items()]
cc=open('scripts/classes/class_catalog.gd',encoding='utf-8').read()
g=open('scripts/game.gd',encoding='utf-8').read()
names=dict(re.findall(r'"([a-z]+)":\{"name":"([^"]+)"',g))
data['classes']=[{'id':i,'name':names.get(i,i),'role':r,'family':f} for i,r,f in re.findall(r'"([a-z]+)":\{"role":"([^"]+)","family":"([a-z]+)"',cc)]
data['concepts']=[list(x) for x in re.findall(r'\["([^"]+)","([^"]+)","([^"]+)","([^"]+)"\]',cc)]
bc=open('scripts/boss_catalog.gd',encoding='utf-8').read()
data['bosses']=[{'id':i,'name':n} for i,n in re.findall(r'"([a-z]+)":\{"name":"([^"]+)"',bc)]
json.dump(data,open(sys.argv[1],'w',encoding='utf-8'),ensure_ascii=False,indent=1)
print({k:len(v) for k,v in data.items()})
