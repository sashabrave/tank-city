import math, random, wave, struct, json
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'assets/audio/chip'
manifest=json.loads((root/'manifest.json').read_text())
for kind in ['collect_alloy','collect_document']:
 files=[];stats=[]
 for variant in range(3):
  rng=random.Random(890+variant);rate=22050;n=int(rate*(.19 if kind=='collect_alloy' else .26));values=[];last=0
  for i in range(n):
   t=i/rate;noise=rng.uniform(-1,1);high=noise-last;last=noise
   if kind=='collect_alloy':
    f=1100+variant*70;v=(math.sin(2*math.pi*f*t)*.6+math.sin(2*math.pi*f*2.73*t)*.24)*math.exp(-t*29)+high*.06*math.exp(-t*150)
   else:
    v=high*.16*math.exp(-t*16)*(0.5+0.5*math.sin(t*75))+math.sin(2*math.pi*(640+variant*35)*t)*.15*math.exp(-t*24)
   v*=min(1,i/60)*min(1,(n-i)/100);values.append(v*.65)
  filename=f'{kind}_{variant+1:02}.wav';files.append(filename)
  with wave.open(str(root/filename),'wb') as out:out.setparams((1,2,rate,0,'NONE','not compressed'));out.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,v))*32767)) for v in values))
  stats.append({'seconds':n/rate,'peak':max(map(abs,values)),'rms':math.sqrt(sum(v*v for v in values)/n)})
 manifest[kind]={'files':files,'loop':False,'stats':stats}
(root/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
