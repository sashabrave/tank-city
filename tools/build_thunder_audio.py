# -*- coding: utf-8 -*-
"""Thunder for battle storms (T-074): a short crack and a long rolling rumble, two variants.
uv run --with numpy python tools/build_thunder_audio.py"""
import json, os, wave
import numpy as np
SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio", "chip")
def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR); y = np.empty_like(x); acc = 0.0
    for i, v in enumerate(x): acc = (1 - a) * v + a * acc; y[i] = acc
    return y
def thunder(seed, length):
    rng = np.random.default_rng(seed); n = int(SR * length); t = np.arange(n) / SR
    white = rng.standard_normal(n)
    crack = lowpass(white, 2600) * np.exp(-t / .09) * (t < .6)
    rumble = lowpass(lowpass(white, 180), 120)
    rumble /= np.abs(rumble).max() + 1e-9
    # Rolling: a few slow swells that die out.
    rolls = sum(np.exp(-((t - c) / w) ** 2) * g for c, w, g in [(.25, .35, 1.0), (.9 + rng.random() * .4, .5, .7), (1.9 + rng.random() * .6, .7, .45)])
    env = np.minimum(1, t / .04) * np.exp(-t / (length * .45)) * (.55 + .45 * rolls)
    out = crack * .5 + rumble * env
    fade = np.ones(n); k = int(SR * .6); fade[-k:] = np.linspace(1, 0, k) ** 2
    out *= fade; out /= np.abs(out).max(); return (out * .85 * 32767).astype(np.int16)
files = []
for i, (seed, length) in enumerate([(31, 3.6), (77, 4.4)], 1):
    name = "weather_thunder_%02d.wav" % i; files.append(name)
    with wave.open(os.path.join(ROOT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(thunder(seed, length).tobytes())
path = os.path.join(ROOT, "manifest.json"); m = json.load(open(path, encoding="utf-8"))
m["weather_thunder"] = {"files": files, "loop": False}
json.dump(m, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=2); print("ok", files)
