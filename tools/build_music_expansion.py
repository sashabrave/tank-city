"""Original compositions extending the project's existing soft chip instruments."""
from pathlib import Path
import ast,json,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1];R=22050
# Reuse the exact approved synthesizer, without rebuilding sound effects.
tree=ast.parse((ROOT/'tools/build_chip_audio.py').read_text())
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['save','osc','note']],type_ignores=[]),'approved_chip_instruments','exec'))
OUT=ROOT/'assets/audio/music';DEMO=ROOT/'audio_demo/music_expansion';DEMO.mkdir(exist_ok=True)
rng=np.random.default_rng(26092677);report={};reel=[]
def percussion(buf,st,beat,kind,amp):
 d=.18 if kind=='kick' else .075;t=np.arange(round(d*R))/R
 if kind=='kick':s=np.sin(2*np.pi*(48*t+2.8*(1-np.exp(-25*t))))*np.exp(-22*t)
 else:
  noise=rng.uniform(-1,1,len(t));s=(noise-np.roll(noise,1))*.4*np.exp(-65*t)
 s*=np.minimum(1,t/.002);ix=(np.arange(len(t))+round(st*R))%len(buf)
 for ch in range(2):np.add.at(buf[:,ch],ix,s*amp)
def master(name,buf,loop,bpm):
 dry=buf.copy()
 for delay,gain in [(.187,.12),(.373,.08),(.619,.045)]:
  if loop:buf+=np.roll(dry[:,::-1],round(delay*R),axis=0)*gain
  else:
   n=round(delay*R);buf[n:]+=dry[:-n,::-1]*gain
 rms=np.sqrt(np.mean(buf*buf));target=.036 if name.startswith(("miniboss","boss_tense")) else .028 if loop else .055
 buf*=min(target/max(rms,1e-6),.65/max(np.max(np.abs(buf)),1e-6))
 if loop:
  # Short boundary correction, no silence or hard reset at loop point.
  n=64;buf[-n:]+=np.linspace(0,1,n)[:,None]*(buf[0]-buf[-1]);buf[-1]=buf[0]
 else:buf*=np.minimum(1,np.minimum(np.arange(len(buf))/(R*.006),(len(buf)-1-np.arange(len(buf)))/(R*.25)))[:,None]
 info=save(OUT/(name+'.wav'),buf);info.update(loop=loop,bpm=bpm,seam=float(np.max(np.abs(buf[0]-buf[-1]))));report[name]=info
 snippet=buf[:min(len(buf),R*8)].copy();n=len(snippet);snippet*=np.minimum(1,np.minimum(np.arange(n)/(R*.1),(n-1-np.arange(n))/(R*.2)))[:,None];reel.extend([snippet,np.zeros((R//3,2))])
minor=[[45,52,57,60,64],[41,48,53,57,60],[43,50,55,59,62],[40,47,52,56,59]]
major=[[48,55,59,62,64],[45,52,55,59,60],[41,48,52,55,57],[43,50,55,59,62]]
for family,count,bpm in [('miniboss',2,106),('boss_tense',2,114),('map_expedition',4,78),('hub_expedition',2,66)]:
 for variant in range(count):
  tense=family in ['miniboss','boss_tense'];boss=family=='boss_tense';hub=family=='hub_expedition';tempo=bpm+2*variant;beat=60/tempo;buf=np.zeros((round(64*beat*R),2))
  progression=([0,1,0,3,0,2,1,3] if variant%2==0 else [0,2,1,3,0,1,2,3]);chords=minor if tense or variant%2 else major
  for bar in range(16):
   chord=chords[progression[bar%8]];st=bar*4*beat;section=1 if bar>=8 else .78
   for k,m in enumerate(chord):note(buf,st,4*beat+.65,m,.015 if tense else .020,'pad',(k-2)*.25)
   for b in ([0,1.5,2,3.5] if tense else [0,2] if not hub else [0]):note(buf,st+b*beat,.65*beat if tense else 1.8*beat,chord[0]-12,.06 if tense else .033,'bass')
   pattern=[0,2,1,3,2,4,1,3] if variant%2==0 else [0,1,3,2,4,2,3,1]
   for j,b in enumerate(np.arange(0,4,.5) if tense else [1,2.5] if not hub else [2.5]):
    m=chord[pattern[(j+bar%2)%8]]+12
    note(buf,st+b*beat,.38 if tense else 1.0,m,.024*section if tense else .019,'bell',(-.35 if j%2 else .35))
   if tense or (not hub and bar%2==0):
    for b in ([0,2] if not boss else [0,1.5,2,3.5]):percussion(buf,st+b*beat,beat,'kick',.085 if tense else .035)
    for b in ([.5,1.5,2.5,3.5] if tense else [1,3]):percussion(buf,st+b*beat,beat,'hat',.028 if tense else .012)
   if bar%4==3:
    for j,m in enumerate([chord[2]+12,chord[1]+12,chord[0]+12]):note(buf,st+(2.5+j*.5)*beat,.6,m,.032,'bell',.2-j*.2)
  master(f'{family}_{variant+1}',buf,True,tempo)
for variant in range(5):
 beat=60/108;buf=np.zeros((round(3.7*R),2));motifs=[[72,76,79,84],[72,79,76,84],[76,72,79,84],[72,76,81,79,84],[79,76,72,79,84]]
 for j,m in enumerate(motifs[variant]):note(buf,.12+j*beat*.45,.7 if j<len(motifs[variant])-1 else 1.5,m,.09,'bell',(-.2 if j%2 else .2))
 for m in [48,55,60,64]:note(buf,.1,2.6,m,.022,'pad')
 note(buf,.12,.75,36,.08,'bass');master(f'expedition_greeting_{variant+1}',buf,False,108)
save(DEMO/'preview.wav',np.concatenate(reel));(DEMO/'manifest.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
