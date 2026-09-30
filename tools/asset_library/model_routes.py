"""Recognize this project's Visuals.model routing; never infer version from folder names."""
import re

def classify(root, paths):
    source=root/'scripts/visuals.gd'
    if not source.exists():return {}
    text=source.read_text()
    entry=text.split('static func model(',1)[-1].split('static func kit_model(',1)[0]
    kit=text.split('static func kit_model(',1)[-1].split('static func model_scale(',1)[0]
    routing=re.search(r'kind in \[(.*?)\].*?return kit_model',entry)
    family=re.search(r'var family="([^"]+)" if kind in \[(.*?)\].*?else "([^"]+)"',kit)
    environment=re.search(r'var environment_path="res://([^"\n]+)"',entry)
    if not (routing and family and environment):return {}
    names=lambda s:re.findall(r'"([^"]+)"',s)
    routed=set(names(routing[1]));infantry=set(names(family[2]));env=environment[1]
    known=set(paths);result={}
    for path in paths:
        if not path.startswith('assets/models/') or not path.endswith('.glb'):continue
        name=path.rsplit('/',1)[-1][:-4]
        if name in routed or name.startswith('weapon_'):
            target='assets/models/'+(family[1] if name in infantry or name.startswith('weapon_') else family[3])+'/'+name+'.glb'
        else:
            mapped='bench_mechanic' if name=='workbench' else name
            target=env+mapped+'.glb'
            if target not in known:target='assets/models/'+name+'.glb'
        if path==target:
            result[path]=('current','Текущая модель игры',target)
        elif '/bonuses_v6/' in path:
            result[path]=('current','Текущий набор бонусов',path)
        elif target in known:
            result[path]=('legacy','Старая / резервная версия',target)
        else:
            result[path]=('unknown','Использование не подтверждено','')
    return result
