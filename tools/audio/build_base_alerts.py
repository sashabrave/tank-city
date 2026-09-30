"""Three original soft two-tone warning signals; no external recordings."""
import math, wave, struct, json
from pathlib import Path
root=Path(__file__).resolve().parents[2]/'assets/audio/chip'
rate=22050
files=[]
for variant,(low,high,period) in enumerate([(294,392,.85),(330,440,.95),(262,349,1.05)]):
 samples=[];phase=0
 for i in range(int(3.2*rate)):
  t=i/rate; blend=(1-math.cos(2*math.pi*t/period))*.5
  phase+=2*math.pi*(low+(high-low)*blend)/rate
  env=min(1,t/.25)*min(1,(3.2-t)/.55)
  v=env*(.28*math.sin(phase)+.045*math.sin(phase*2))*(.8+.2*blend)
  samples.append(struct.pack('<h',round(v*32767)))
 filename=f'base_alert_{variant+1:02}.wav';files.append(filename)
 with wave.open(str(root/filename),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(samples))
p=root/'manifest.json';data=json.loads(p.read_text());data['base_alert']={'files':files,'loop':False};p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
