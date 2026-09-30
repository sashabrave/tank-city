"""Four original short minor-key chip signals; deterministic source assets."""
import math, random, wave, struct, json
from pathlib import Path
root=Path(__file__).resolve().parents[2]/'assets/audio/chip'
rate=22050
files=[]
for variant in range(4):
 rng=random.Random(140+variant); notes=[[64,60,57,52],[67,63,60,55],[62,58,55,50],[65,61,58,53]][variant]
 samples=[]
 for i in range(int(2.2*rate)):
  t=i/rate; value=0
  for j,note in enumerate(notes):
   age=t-j*.19
   if age<0:continue
   f=440*2**((note-69)/12);env=min(1,age/.006)*math.exp(-age*3)
   value+=env*(math.sin(2*math.pi*f*age)*.12+math.sin(2*math.pi*f*2*age)*.025)
  value+=rng.uniform(-1,1)*.14*math.exp(-t*65)
  value+=math.sin(2*math.pi*82.4*t)*.1*math.exp(-t*2.2)
  samples.append(struct.pack('<h',int(max(-.95,min(.95,value))*32767)))
 filename=f'defeat_signal_{variant+1:02}.wav';files.append(filename)
 with wave.open(str(root/filename),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(samples))
p=root/'manifest.json';data=json.loads(p.read_text());data['defeat']['files']=files;p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
