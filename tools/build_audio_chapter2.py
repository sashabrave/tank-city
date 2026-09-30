"""Second original chip pack: authored contrasting rhythmic themes and progression cues."""
from pathlib import Path
import ast,json,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1];R=22050
exec(compile(ast.Module(body=[n for n in ast.parse((ROOT/'tools/build_chip_audio.py').read_text()).body if isinstance(n,ast.FunctionDef) and n.name in ['save','osc','note']],type_ignores=[]),'instruments','exec'))
rng=np.random.default_rng(260927);OUT=ROOT/'assets/audio/music';DEMO=ROOT/'audio_demo/chapter2';DEMO.mkdir(parents=True,exist_ok=True)
# id,title,context,bpm,beats/bar,pattern,minor
specs=[('camp_lantern','Фонарь','hub',62,4,0,False),('camp_waltz','Тёплый свет','hub',72,3,1,False),('route_compass','Компас','map',76,4,2,False),('route_clouds','Облака','map',68,3,3,False),('battle_patrol','Патруль','battle',84,4,4,False),('battle_mosaic','Мозаика','battle',90,4,5,False),('battle_current','Течение','battle',96,3,6,True),('battle_signal','Позывной','battle',86,4,7,True),('commander_clock','Механизм','miniboss',104,4,8,True),('commander_flank','Обход','miniboss',108,3,9,True),('boss_vector','Вектор','boss',112,4,10,True),('boss_redoubt','Редут','boss',100,4,11,True)]
# Each phrase uses a distinct onset/duration/scale-degree sequence, not pitch-shift copies.
motifs=[[(.5,1.3,4),(2.5,.8,2)],[(0,.65,0),(1,.6,2),(2,.75,4)],[(0,.35,0),(.75,.35,2),(1.5,.65,4),(3,.75,1)],[(.5,.6,4),(1.5,1.1,1)],[(0,.45,0),(1.5,.35,2),(2.25,.4,4),(3,.6,2)],[(.5,.3,4),(1.25,.45,3),(2,.35,1),(2.75,.7,2)],[(0,.45,0),(.5,.4,1),(1.5,.4,3),(2,.8,2)],[(0,.75,4),(1.5,.25,4),(2,.3,2),(2.5,.35,1),(3.25,.45,0)],[(0,.3,0),(.5,.3,4),(1.25,.3,1),(2,.3,4),(2.75,.3,2),(3.5,.3,4)],[(0,.4,0),(.5,.3,2),(1,.5,3),(2,.3,2),(2.5,.3,1)],[(0,.25,0),(.75,.3,1),(1.5,.3,4),(2,.25,3),(2.75,.3,1),(3.5,.3,2)],[(0,1.1,0),(1.5,.4,4),(2.5,.4,3),(3.25,.6,1)]]
report={};catalog={};reel=[]
def drum(buf,st,kind,amp):
 d=.22 if kind=='kick' else .10;t=np.arange(round(d*R))/R
 if kind=='kick':x=np.sin(2*np.pi*(46*t+2*(1-np.exp(-t*35))))*np.exp(-t*24)
 else:x=(rng.uniform(-1,1,len(t)))*np.exp(-t*(60 if kind=='hat' else 32))
 x*=np.minimum(1,t/.003);ix=(np.arange(len(t))+round(st*R))%len(buf)
 for c in range(2):np.add.at(buf[:,c],ix,x*amp)
for id,title,context,bpm,meter,pattern,minor in specs:
 beat=60/bpm;bars=24 if meter==3 else 16;n=round(bars*meter*beat*R);buf=np.zeros((n,2))
 scale=[0,2,3,5,7,8,10] if minor else [0,2,4,5,7,9,11]
 root=45 if minor else 48
 def pitch(degree):return root+scale[degree%7]+12*(degree//7)
 prog=([0,5,3,4] if pattern%3==0 else [0,3,5,4] if pattern%3==1 else [0,4,5,3])
 for bar in range(bars):
  degree=prog[(bar//2)%4];st=bar*meter*beat;section=.85 if bar<bars//2 else 1
  for k,off in enumerate([0,2,4,6]):note(buf,st,meter*beat+.8,pitch(degree+off),.017,'pad',(k-1.5)*.3)
  if context=='hub':bassbeats=[0]
  elif pattern in [5,7,11]:bassbeats=[0,1.5,2.75]
  elif meter==3:bassbeats=[0,1.5]
  else:bassbeats=[0,2]
  for b in bassbeats:note(buf,st+b*beat,.8*beat if context!='hub' else 1.8*beat,pitch(degree)-12,.036 if context in ['hub','map'] else .050,'bass')
  # Silence in alternate hub phrases and answered melody in second half.
  if context!='hub' or bar%2==0:
   for j,(b,d,off) in enumerate(motifs[pattern]):
    answer=(-1 if j%2 else 1) if bar%4==3 else 0
    note(buf,st+b*beat,d*beat+.16,pitch(degree+off+answer)+12,.022*section if context in ['hub','map'] else .029*section,'bell',(-.3 if j%2 else .3))
  if context not in ['hub','map']:
   for b in bassbeats:drum(buf,st+b*beat,'kick',.048 if context=='battle' else .07)
   for b in ([1,2] if meter==3 else [1,3]):drum(buf,st+b*beat,'snare',.012 if context=='battle' else .024)
   for b in np.arange(.5,meter,1):drum(buf,st+b*beat,'hat',.011)
 dry=buf.copy()
 for delay,g in [(.187,.12),(.373,.08),(.619,.045)]:buf+=np.roll(dry[:,::-1],round(delay*R),axis=0)*g
 target=.024 if context=='hub' else .026 if context=='map' else .030 if context=='battle' else .035
 buf*=min(target/np.sqrt(np.mean(buf*buf)),.6/max(abs(buf).max(),1e-6))
 buf[-128:]+=np.linspace(0,1,128)[:,None]*(buf[0]-buf[-1]);buf[-1]=buf[0]
 report[id]=save(OUT/(id+'.wav'),buf);report[id].update(bpm=bpm,meter=meter,seam=float(abs(buf[-1]-buf[0]).max()))
 catalog[id]={'title':title,'context':context}
 snippet=buf[:R*7].copy();ix=np.arange(len(snippet));snippet*=np.minimum(1,np.minimum(ix/(R*.2),(len(ix)-1-ix)/(R*.4)))[:,None];reel.extend([snippet,np.zeros((R//3,2))])
save(DEMO/'new_music_selection.wav',np.concatenate(reel));(OUT/'chapter2_catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2))
S=ROOT/'assets/audio/chip';manifest=json.loads((S/'manifest.json').read_text())
events={'countdown_tick':[72],'commander_arrive':[48,55,60],'route_select':[67,72],'route_enter':[60,67,76],'route_cancel':[72,67],'quest_ready':[72,76,79],'quest_claim':[60,64,67,84],'telegram_accept':[64,67,71],'base_level_up':[48,60,64,67,79],'weapon_tune':[55,62,67],'build_complete':[48,55,64],'trench_enter':[55,48],'trench_exit':[48,55],'trench_hide':[62,50],'armor_recover':[48,55,60,67],'low_health':[69,68],'enemy_surprise':[60,66,60]}
fxreel=[]
for id,notes in events.items():
 files=[]
 for v in range(2):
  d=len(notes)*.09+.28;x=np.zeros(round(d*R));
  for j,m in enumerate(notes):
   off=round(j*.09*R);t=np.arange(len(x)-off)/R;f=440*2**((m-69)/12)*(1+v*.009)
   y=(osc(t,f,'tri')+.12*osc(t,f*2,'pulse'))*np.exp(-t*14)*np.minimum(1,t/.004)
   if id.startswith('trench') or id in ['weapon_tune','build_complete']:y+=rng.uniform(-.12,.12,len(t))*np.exp(-t*45)
   x[off:]+=y*.35
  x[-256:]*=np.linspace(1,0,256);name=id+f'_{v+1:02}.wav';save(S/name,x);files.append(name)
  if v==0:fxreel.extend([x,np.zeros(R//3)])
 manifest[id]={'files':files,'loop':False}
(S/'manifest.json').write_text(json.dumps(manifest,indent=2));save(DEMO/'new_events_selection.wav',np.concatenate(fxreel))
(DEMO/'validation.json').write_text(json.dumps(report,indent=2));print('12 compositions, 17 event banks / 34 effects generated')
