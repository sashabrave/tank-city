"""Inventory foley (T-252): short gun-like clicks for taking, placing, loading and dropping items.

Pure Python, deterministic (fixed seeds), no recordings. Writes assets/audio/chip/inv_*.wav and their
entries in manifest.json; run Godot --import afterwards for the .import files.
  inv_weapon    — a gun: slide clack + a sharper latch click with a low body knock
  inv_ammo      — an ammo box: a light latch tick and a short rattle of cartridges
  inv_blueprint — a blueprint: clipboard clip snap and a soft paper swish
  inv_drop      — something put down hard: low thud + metal knock (thrown away, falling result cards)
  inv_destroy   — destroyed for good: a short crunch over a low thud
"""
import math, random, wave, struct, json
from pathlib import Path

root = Path(__file__).resolve().parents[2] / 'assets/audio/chip'
RATE = 22050


def modes(buf, start, freqs, tau, amp, rng):
	"""Damped sines (metal modes) starting at `start` seconds."""
	phase = [rng.uniform(0, math.tau) for _ in freqs]
	n0 = int(start * RATE)
	for i in range(n0, len(buf)):
		t = (i - n0) / RATE
		env = math.exp(-t / tau)
		if env < 1e-4:
			break
		buf[i] += amp * env * sum(math.sin(math.tau * f * t + p) / (k + 1) for k, (f, p) in enumerate(zip(freqs, phase)))


def burst(buf, start, length, amp, rng, bright=1.0):
	"""A noise transient; `bright` < 1 smooths it (one-pole low-pass) into a knock."""
	n0 = int(start * RATE)
	last = 0.0
	for i in range(n0, min(len(buf), n0 + int(length * RATE))):
		t = (i - n0) / RATE
		x = rng.uniform(-1, 1) * math.exp(-t / (length * .3))
		last = last + bright * (x - last)
		buf[i] += amp * last


def thump(buf, start, f0, f1, tau, amp):
	"""A low knock whose pitch falls from f0 to f1."""
	n0 = int(start * RATE)
	ph = 0.0
	for i in range(n0, len(buf)):
		t = (i - n0) / RATE
		env = math.exp(-t / tau)
		if env < 1e-4:
			break
		f = f1 + (f0 - f1) * math.exp(-t / .03)
		ph += math.tau * f / RATE
		buf[i] += amp * env * min(1.0, t / .002) * math.sin(ph)


def swish(buf, start, length, amp, rng):
	"""Soft paper: high-passed noise under a rise-and-fall envelope."""
	n0 = int(start * RATE)
	prev = 0.0
	for i in range(n0, min(len(buf), n0 + int(length * RATE))):
		t = (i - n0) / length / RATE
		x = rng.uniform(-1, 1)
		buf[i] += amp * (x - prev) * .5 * math.sin(math.pi * t) ** 2
		prev = x


def weapon(v, rng):
	buf = [0.0] * int(.32 * RATE)
	d = 1 + (v - 1) * .05
	burst(buf, 0, .006, .5, rng, .55)
	modes(buf, 0, [1850 * d, 2930 * d, 4310 * d], .028, .5, rng)
	thump(buf, 0, 210, 120, .035, .45)
	gap = .058 + v * .008
	burst(buf, gap, .004, .4, rng, .85)
	modes(buf, gap, [2620 * d, 3940 * d, 5230 * d], .018, .38, rng)
	return buf


def ammo(v, rng):
	buf = [0.0] * int(.26 * RATE)
	d = 1 + (v - 1) * .06
	burst(buf, 0, .004, .35, rng, .7)
	modes(buf, 0, [940 * d, 1630 * d], .022, .35, rng)
	t = .03
	for k in range(3 + v % 2):
		modes(buf, t, [3150 * d * rng.uniform(.95, 1.05), 4720 * d], .012, .22 * (.8 ** k), rng)
		burst(buf, t, .003, .15 * (.8 ** k), rng, .9)
		t += rng.uniform(.018, .03)
	return buf


def blueprint(v, rng):
	buf = [0.0] * int(.24 * RATE)
	d = 1 + (v - 1) * .05
	swish(buf, 0, .12, .22, rng)
	burst(buf, .045, .004, .3, rng, .6)
	modes(buf, .045, [1380 * d, 2270 * d], .016, .4, rng)
	return buf


def drop(v, rng):
	buf = [0.0] * int(.4 * RATE)
	d = 1 + (v - 1) * .05
	thump(buf, 0, 150 * d, 72 * d, .07, .7)
	burst(buf, 0, .02, .35, rng, .25)
	modes(buf, .004, [1480 * d, 2390 * d, 3610 * d], .03, .26, rng)
	return buf


def destroy(v, rng):
	buf = [0.0] * int(.45 * RATE)
	thump(buf, 0, 120, 55, .09, .6)
	t = 0.0
	for k in range(6):
		burst(buf, t, .025, .38 * (.85 ** k), rng, .45)
		modes(buf, t, [1200 * rng.uniform(.8, 1.2), 2100 * rng.uniform(.8, 1.2)], .02, .18 * (.85 ** k), rng)
		t += rng.uniform(.022, .04)
	return buf


def write(name, buf):
	peak = max(abs(x) for x in buf) or 1.0
	buf = [x / peak * .5 for x in buf]
	# Short fade at the end: no click when the tail is cut.
	fade = int(.01 * RATE)
	for i in range(fade):
		buf[-1 - i] *= i / fade
	with wave.open(str(root / name), 'wb') as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		w.writeframes(b''.join(struct.pack('<h', int(max(-.98, min(.98, x)) * 32767)) for x in buf))
	rms = math.sqrt(sum(x * x for x in buf) / len(buf))
	return {"seconds": len(buf) / RATE, "peak": .5, "rms": rms}


SETS = {"inv_weapon": (weapon, 3), "inv_ammo": (ammo, 3), "inv_blueprint": (blueprint, 2), "inv_drop": (drop, 3), "inv_destroy": (destroy, 2)}
manifest_path = root / 'manifest.json'
manifest = json.loads(manifest_path.read_text())
for event, (make, count) in SETS.items():
	files, stats = [], []
	for v in range(1, count + 1):
		rng = random.Random(f'{event}-{v}')
		name = f'{event}_{v:02}.wav'
		stats.append(write(name, make(v, rng)))
		files.append(name)
	manifest[event] = {"files": files, "loop": False, "stats": stats}
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
print('written', ', '.join(SETS))
