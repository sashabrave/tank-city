"""Deterministic original soft mechanical UI clicks and three chip music loops."""
import math, random, wave, struct, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; R=22050
rng=random.Random(2719)
def save(path, samples):
 with wave.open(str(path),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(R);w.writeframes(struct.pack('<%dh'%len(samples),*[round(max(-.95,min(.95,v))*32767) for v in samples]))
 return dict(seconds=len(samples)/R,peak=max(abs(v) for v in samples))
folder=ROOT/'assets/audio/chip'; manifest=json.loads((folder/'manifest.json').read_text())
for kind,freq,duration in [('ui_hover',145,.045),('ui_confirm',205,.075),('ui_back',120,.065),('ui_denied',95,.095)]:
 files=[];stats=[]
 for variant in range(3):
  samples=[];low=0
  for i in range(round(R*duration)):
   t=i/R;low=.91*low+.09*rng.uniform(-1,1)
   env=min(1,t/.002)*math.exp(-t/(duration*.19))*max(0,1-t/duration)
   samples.append((math.sin(2*math.pi*(freq+variant*9)*t)*.38+low*.5)*env)
  name=f'{kind}_{variant+1:02}.wav';files.append(name);stats.append(save(folder/name,samples))
 manifest[kind]=dict(files=files,loop=False,stats=stats)
(folder/'manifest.json').write_text(json.dumps(manifest,indent=2))
folder=ROOT/'assets/audio/music';catalog=json.loads((folder/'chapter2_catalog.json').read_text())
for name,title,group,bpm,root in [('hub_evening_dial','Вечерний эфир','hub',72,48),('route_soft_beacon','Маяк на маршруте','map',84,50),('battle_muted_pulse','Тихий импульс','battle',108,45)]:
 beat=60/bpm;n=round(32*beat*R);samples=[0.0]*n
 def note(start,length,midi,amp):
  freq=440*2**((midi-69)/12)
  for j in range(round(length*R)):
   t=j/R;env=min(1,t/.018)*max(0,1-t/length)**2
   tone=math.sin(2*math.pi*freq*t)+.18*math.sin(4*math.pi*freq*t)
   samples[(round(start*R)+j)%n]+=tone*env*amp
 for bar,offset in enumerate([0,-3,5,-5,0,5,-3,-5]):
  base=root+offset
  for m in [base,base+7,base+12]:note(bar*4*beat,4*beat,m,.025)
  for k,step in enumerate([12,19,16,14]):note((bar*4+k+.5)*beat,.65*beat,base+step,.036)
  for k in ([0,2] if group!='hub' else [0]):note((bar*4+k)*beat,beat*.55,base-12,.06)
  if group=='battle':
   for k in range(4):note((bar*4+k)*beat,.10,30,.065)
 for i in range(64):samples[-64+i]+=(samples[0]-samples[-1])*i/63
 save(folder/(name+'.wav'),samples);catalog[name]=dict(title=title,context=group)
(folder/'chapter2_catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2))
print('Generated 12 UI clicks and 3 original music loops')
