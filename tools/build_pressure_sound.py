"""Short, inharmonic metal-on-metal success cue; deterministic PCM, no dependencies."""
import math
from pathlib import Path
import random
import struct
import wave

rate = 44100
length = 0.24
rng = random.Random(718)
modes = [(940, .47, .046), (1637, .30, .062), (2780, .19, .035), (4210, .065, .018)]
samples = []
previous_noise = 0.0
for i in range(round(rate * length)):
    t = i / rate
    attack = 1 - math.exp(-t / .00065)
    ring = sum(gain * math.sin(2 * math.pi * hz * t + .5 * math.exp(-t / .004))
               * math.exp(-t / decay) for hz, gain, decay in modes)
    noise = rng.uniform(-1, 1)
    transient = .12 * (noise + previous_noise) * math.exp(-t / .003)
    previous_noise = noise
    body = .13 * math.sin(2 * math.pi * 410 * t) * math.exp(-t / .010)
    fade = min(1.0, max(0.0, (length - t) / .025))
    samples.append((ring + transient + body) * attack * fade)
peak = max(abs(x) for x in samples)
path = Path(__file__).resolve().parents[1] / 'assets/audio/v2/07_pressure.wav'
with wave.open(str(path), 'wb') as output:
    output.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
    output.writeframes(b''.join(struct.pack('<h', round(x / peak * .85 * 32767)) for x in samples))
print(f'{path.name}: {length}s, peak -1.4 dBFS, mono 44.1 kHz')
