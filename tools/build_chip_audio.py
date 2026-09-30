"""Original deterministic chip audio. No external recordings or generation service."""
from pathlib import Path
import json, wave, hashlib
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/audio/chip'; OUT.mkdir(parents=True,exist_ok=True)
DEMO=ROOT/'audio_demo/chip'; DEMO.mkdir(parents=True,exist_ok=True)
R=22050
rng=np.random.default_rng(260926)
manifest=json.loads((OUT/"manifest.json").read_text()) if (OUT/"manifest.json").exists() else {}
def save(path,x):
    x=np.asarray(x); pcm=np.round(np.clip(x,-.98,.98)*32767).astype('<i2')
    with wave.open(str(path),'wb') as w:
        w.setnchannels(1 if x.ndim==1 else 2);w.setsampwidth(2);w.setframerate(R);w.writeframes(pcm.tobytes())
    return dict(seconds=len(x)/R,peak=float(np.max(np.abs(x))),rms=float(np.sqrt(np.mean(x*x))))
def osc(t,f,shape='tri'):
    p=np.cumsum(np.broadcast_to(f,t.shape))/R
    if shape=='pulse':return .72*np.where(p%1<.25,1.,-.333)
    if shape=='sin':return np.sin(2*np.pi*p)
    return 2*np.abs(2*(p%1)-1)-1
def noise(n,hold=3):return np.repeat(rng.uniform(-1,1,(n+hold-1)//hold),hold)[:n]
def envelope(t,d):return np.minimum(1,t/.003)*np.minimum(1,(d-t)/.025)
loop_ids={'engine_buggy','engine_tank','engine_apc','rotor_drone','tracks','turret_servo','ground_drone_motor','helicopter_rotor','rocket_flight','gas_loop','boss_laser_loop','generator_loop'}
fire={'pistol':(520,.18),'smg':(720,.12),'shotgun':(185,.35),'rifle':(410,.22),'sniper':(260,.45),'rpg':(130,.6),'vehicle_mg':(350,.18),'tank':(90,.72),'mortar':(140,.55),'grenade_launcher':(200,.32),'boss':(65,.85)}
def effect(id,v):
    k=1+(.035*(v-1)); d=.38
    if id.startswith('fire_'):
        f,d=fire[id[5:]];t=np.arange(round(d*R))/R
        x=(.50*osc(t,f*k*np.exp(-t*12)+45,'pulse')+.6*noise(len(t),2))*np.exp(-t/(d*.19))
        x+=.28*osc(t,60+f*.12*np.exp(-t*30),'sin')*np.exp(-t/(d*.4))
    elif id.startswith('explosion') or id in ['vehicle_destroy','boss_radial','debris']:
        d=1.2 if id in ['explosion_heavy','vehicle_destroy','boss_radial'] else .65;t=np.arange(round(d*R))/R
        x=(noise(len(t),8)*.55+noise(len(t),2)*.2)*np.exp(-t*5/d)+.5*osc(t,38+110*np.exp(-t*18),'tri')*np.exp(-t*7)
    elif id in loop_ids or id.startswith(('ambience_','weather_')):
        d=4.;t=np.arange(round(d*R))/R
        idx=int(hashlib.sha256(id.encode()).hexdigest()[:4],16)
        if id.startswith(('ambience','weather')) or id=='gas_loop':
            # Periodic low-level noise bed, plus sparse rounded digital chirps.
            x=np.zeros(len(t));
            for j in range(1,48):x+=np.sin(2*np.pi*(j*7+.25*(idx%29))*t+j)*.02/np.sqrt(j)
            x*=.7+.3*np.sin(2*np.pi*.25*t)
            if id in ['ambience_forest','ambience_marsh']:x+=.04*np.sin(2*np.pi*(700+idx%400)*t)*np.maximum(0,np.sin(2*np.pi*.5*t))**24
        else:
            f={'engine_tank':40,'engine_buggy':65,'engine_apc':48,'rotor_drone':160,'helicopter_rotor':35,'tracks':90,'turret_servo':240}.get(id,100)
            x=(.5*osc(t,f,'tri')+.14*osc(t,f*2,'pulse'))*(.7+.3*np.sin(2*np.pi*(8 if 'rotor' in id else 12)*t))
        # Equal-power wrap blend short seam, no gap.
        n=441;x[-n:]=x[-n:]*(1-np.arange(n)/n)+x[:n]*(np.arange(n)/n)
        x[-1]=x[0]
        return x*.48,True
    elif id.startswith(('hit_','step_')) or id in ['infantry_down','player_hurt','base_hit','gear_foley','grenade_land','weapon_mechanism','delivery_land']:
        d=.12 if id.startswith('step') else .25;t=np.arange(round(d*R))/R
        f=130 if id in ['hit_body','step_soft'] else 700 if id in ['hit_metal','weapon_mechanism'] else 260
        x=(.5*noise(len(t),4)+.35*osc(t,f*k*np.exp(-t*14),'tri'))*np.exp(-t*24)
        if id=='step_wet':x+=.22*osc(t,500*np.exp(-t*25),'sin')*np.exp(-t*18)
    elif id in ['ricochet','laser_fire','pressure','grenade_throw','engine_start','engine_stop','cloak']:
        d=.45;t=np.arange(round(d*R))/R
        up=id in ['engine_start','cloak'];f=(120+1700*(t/d)**2) if up else 1800*np.exp(-t*10)+90
        x=(.5*osc(t,f*k,'pulse')+.1*noise(len(t),2))*np.exp(-t*7)
    else:
        d=1.6 if id=='boss_laser_charge' else .7;t=np.arange(round(d*R))/R;x=np.zeros(len(t))
        base={'danger_warning':57,'wreck_warning':64,'defeat':48,'shield_break':54,'heal':76,'repair':64,'rare_reveal':79,'pickup':79,'ui_confirm':72}.get(id,67)
        notes=[0,-3,-7] if id in ['defeat','shield_break'] else [0,4,7]
        for i,interval in enumerate(notes):
            st=i*.11;u=t-st;mask=u>=0;f=440*2**((base+interval-69)/12)
            x[mask]+=.38*osc(u[mask],f*k,'tri')*np.exp(-u[mask]*10)
        if id=='boss_laser_charge':x+=.3*osc(t,100+800*(t/d)**2,'pulse')*(t/d)
    x*=envelope(t,d);x=np.convolve(x,[.2,.6,.2],mode='same')
    x*=.68/max(.68,np.max(np.abs(x)))
    return x,False
inventory=json.loads((ROOT/'docs/audio/sound_inventory.json').read_text())['sounds']
for item in inventory:
    id=item['id'];files=[];meta=[]
    for v in range(item['files']):
        x,loop=effect(id,v);name=f'{id}_{v+1:02}.wav';meta.append(save(OUT/name,x));files.append(name)
    manifest[id]={'files':files,'loop':loop,'stats':meta}
# Preserve explicit piercing sound, which is a current event beyond the audit banks.
x,_=effect('pressure',0);save(OUT/'pressure_01.wav',x);manifest['pressure']={'files':['pressure_01.wav'],'loop':False}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
# New compositions use the approved soft triangle/bell/pad palette, C major / A minor.
def note(buf,st,d,m,amp,kind='bell',pan=0):
    t=np.arange(round(d*R))/R;f=440*2**((m-69)/12)
    if kind=='pad':s=(np.sin(2*np.pi*f*t)+.14*np.sin(4*np.pi*f*t)) * np.minimum(1,t/.48)*np.minimum(1,(d-t)/.8)
    elif kind=='bass':s=osc(t,f,'tri')*np.minimum(1,t/.03)*np.minimum(1,(d-t)/.25)*np.exp(-t/d)
    else:s=(np.sin(2*np.pi*f*t)+.19*np.sin(6*np.pi*f*t)+.055*np.sin(10*np.pi*f*t))*np.minimum(1,t/.009)*np.minimum(1,(d-t)/.12)*np.exp(-4*t/d)
    ix=(np.arange(len(t))+round(st*R))%len(buf)
    np.add.at(buf[:,0],ix,s*amp*np.sqrt((1-pan)/2));np.add.at(buf[:,1],ix,s*amp*np.sqrt((1+pan)/2))
chords=[[48,55,59,62,64],[45,52,55,59,60],[41,48,52,55,57],[43,50,57,59,64]]
melodies=[[76,74,71,67,69,72,71,67],[72,76,79,76,74,71,69,67],[67,71,74,72,69,67,64,67]]
M=ROOT/'assets/audio/music';musicmeta={};previews=[]
for ctx,bpm in [('hub',64),('battle',72),('boss',78)]:
    for variant in range(2):
        beat=60/(bpm+variant*2);buf=np.zeros((round(64*beat*R),2));progress=[0,1,2,3] if variant==0 else [2,0,3,1]
        if ctx=='boss':progress=[1,2,3,1] if variant==0 else [1,3,2,1]
        for bar in range(16):
            tones=chords[progress[(bar//2)%4]];st=bar*4*beat
            for k,m in enumerate(tones):note(buf,st,4*beat+.65,m,.021,'pad',(k-2)*.25)
            for b in ([0,2] if ctx=='boss' else [0]):note(buf,st+b*beat,1.7*beat,tones[0]-12,.042 if ctx!='hub' else .025,'bass')
            if ctx!='hub' or bar%2==0:
                motif=melodies[(variant+(ctx=='boss'))%3]
                for j,b in enumerate([1.5,2.5] if ctx!='hub' else [2.5]):
                    note(buf,st+b*beat,1.2,motif[(bar+j)%8],.021 if ctx!='hub' else .012,'bell',(-.3 if j==0 else .3))
        dry=buf.copy()
        for delay,g in [(.187,.12),(.373,.08),(.619,.045)]:buf+=np.roll(dry[:,::-1],round(delay*R),axis=0)*g
        name=f'{ctx}_variation_{variant+1}.wav';musicmeta[name]=save(M/name,buf)
        n=R*8;snippet=buf[:n].copy();snippet*=np.minimum(1,np.minimum(np.arange(n)/(.3*R),(n-np.arange(n))/(.6*R)))[:,None];previews.extend([snippet,np.zeros((R//2,2))])
save(DEMO/'music_selection.wav',np.concatenate(previews))
# Family reels with exact sample markers; shipped files are already cut at their source boundaries.
for group,ids in [('weapons',[k for k in manifest if k.startswith('fire_')]),('events',['hit_metal','ricochet','explosion_small','explosion_heavy','shield_hit','heal','pickup','rare_reveal','defeat']),('machines',['engine_buggy','engine_apc','engine_tank','rotor_drone','helicopter_rotor'])]:
    segments=[];marks=[];offset=0
    for id in ids:
        with wave.open(str(OUT/manifest[id]['files'][0]),'rb') as w:x=np.frombuffer(w.readframes(w.getnframes()),'<i2').astype(float)/32767
        marks.append({'id':id,'start_sample':offset,'end_sample':offset+len(x)});segments.extend([x,np.zeros(round(.45*R))]);offset+=len(x)+round(.45*R)
    save(DEMO/(group+'_selection.wav'),np.concatenate(segments));(DEMO/(group+'_cuts.json')).write_text(json.dumps(marks,indent=2))
(DEMO/'music_manifest.json').write_text(json.dumps(musicmeta,indent=2))
print('Created',len(manifest),'banks,',sum(len(v['files']) for v in manifest.values()),'SFX files and',len(musicmeta),'music loops')
