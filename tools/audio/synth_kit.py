"""Small deterministic synthesizer kit: instruments, drums, loop-safe effects.

Everything is generated from code (NumPy + SciPy), no recordings or services.
All placement helpers wrap around the buffer end, so every track loops seamlessly.
"""
import wave
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

R = 32000


def midi(m):
	return 440.0 * 2 ** ((m - 69) / 12)


def save(path, x, rate=R):
	x = np.asarray(x)
	pcm = np.round(np.clip(x, -.98, .98) * 32767).astype('<i2')
	with wave.open(str(path), 'wb') as w:
		w.setnchannels(1 if x.ndim == 1 else 2)
		w.setsampwidth(2)
		w.setframerate(rate)
		w.writeframes(pcm.tobytes())
	return dict(seconds=round(len(x) / rate, 3), peak=round(float(np.max(np.abs(x))), 4), rms=round(float(np.sqrt(np.mean(x * x))), 4))


def filt(x, kind, freq, order=2):
	freq = np.atleast_1d(freq) if kind == 'band' else freq
	nyq = R / 2
	wn = np.clip(np.asarray(freq, float) / nyq, 1e-4, .999)
	sos = butter(order, wn, btype={'low': 'lowpass', 'high': 'highpass', 'band': 'bandpass'}[kind], output='sos')
	return sosfilt(sos, x, axis=0)


def adsr(n, a=.005, d=.1, s=.6, r=.1, dur=None):
	t = np.arange(n) / R
	dur = n / R if dur is None else dur
	env = np.where(t < a, t / max(a, 1e-6), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-6)))
	rel = np.clip((dur - t) / max(r, 1e-6), 0, 1)
	return env * rel


class Track:
	def __init__(self, bpm, beats, swing=0.0, seed=0):
		self.bpm = bpm
		self.beat = 60 / bpm
		self.swing = swing
		self.n = round(beats * self.beat * R)
		self.rng = np.random.default_rng(seed)
		self.buses = {}

	def bus(self, name):
		if name not in self.buses:
			self.buses[name] = np.zeros((self.n, 2))
		return self.buses[name]

	def time(self, beat_pos):
		"""Beat position to seconds with 16th swing (odd 16ths pushed late)."""
		sixteenth = beat_pos * 4
		idx = np.floor(sixteenth + 1e-6)
		frac = sixteenth - idx
		if abs(frac) < 1e-6 and int(idx) % 2 == 1:
			beat_pos = beat_pos + self.swing * .25
		return beat_pos * self.beat

	def place(self, bus, beat_pos, sig, gain=1.0, pan=0.0, humanize=0.0):
		st = self.time(beat_pos) + (self.rng.normal(0, humanize) if humanize else 0)
		i0 = round(st * R)
		buf = self.bus(bus)
		ix = (np.arange(len(sig)) + i0) % self.n
		if sig.ndim == 1:
			np.add.at(buf[:, 0], ix, sig * gain * np.sqrt((1 - pan) / 2))
			np.add.at(buf[:, 1], ix, sig * gain * np.sqrt((1 + pan) / 2))
		else:
			np.add.at(buf[:, 0], ix, sig[:, 0] * gain)
			np.add.at(buf[:, 1], ix, sig[:, 1] * gain)

	def secs(self, beats):
		return beats * self.beat


# ---------------------------------------------------------------- instruments

def _t(d):
	return np.arange(max(1, round(d * R))) / R


def epiano(m, d, vel=1.0, bright=1.0):
	"""FM electric piano: bell-like attack that mellows out, slight tremolo."""
	d = d + .35
	t = _t(d)
	f = midi(m)
	index = (1.6 * bright * vel) * np.exp(-t * 3.2) + .25
	mod = np.sin(2 * np.pi * f * t) * index
	tone = np.sin(2 * np.pi * f * t + mod)
	tine = .18 * np.sin(2 * np.pi * f * 14.0 * t) * np.exp(-t * 28) * bright
	x = (tone + tine) * np.exp(-t * (1.3 + f / 900)) * (1 + .08 * np.sin(2 * np.pi * 4.6 * t))
	return x * adsr(len(t), .002, 9, 1, .3, d) * vel


def pluck(m, d, vel=1.0, damp=.5, rng=None):
	"""Karplus-Strong string, vectorised per period."""
	rng = rng or np.random.default_rng(int(m * 97))
	f = midi(m)
	p = max(2, int(round(R / f)))
	n = max(p * 2, round((d + .4) * R))
	buf = filt(rng.uniform(-1, 1, p), 'low', 2500 + 5000 * (1 - damp))
	out = np.empty(n)
	loss = .996 - .012 * damp
	for i in range(0, n, p):
		seg = buf[:min(p, n - i)]
		out[i:i + len(seg)] = seg
		buf = loss * .5 * (buf + np.roll(buf, 1))
	return out * adsr(n, .001, 9, 1, .15, n / R) * vel


def marimba(m, d, vel=1.0):
	t = _t(d + .5)
	f = midi(m)
	x = np.sin(2 * np.pi * f * t) * np.exp(-t * 5) + .35 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t * 22)
	x += .12 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t * 60)
	return x * adsr(len(t), .001, 9, 1, .05) * vel


def vibes(m, d, vel=1.0):
	t = _t(d + .8)
	f = midi(m)
	x = np.sin(2 * np.pi * f * t) + .25 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 6)
	x *= np.exp(-t * 1.6) * (1 + .3 * np.sin(2 * np.pi * 5.5 * t))
	return x * adsr(len(t), .002, 9, 1, .2) * vel


def kalimba(m, d, vel=1.0):
	t = _t(d + .4)
	f = midi(m)
	x = np.sin(2 * np.pi * f * t) * np.exp(-t * 4) + .4 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 30)
	return x * adsr(len(t), .001, 9, 1, .1) * vel


def sub(m, d, vel=1.0, drive=1.5, glide_from=None):
	t = _t(d)
	f = midi(m)
	if glide_from is not None:
		f = midi(m) + (midi(glide_from) - midi(m)) * np.exp(-t * 40)
	ph = np.cumsum(np.broadcast_to(f, t.shape)) / R
	x = np.sin(2 * np.pi * ph) + .18 * np.sin(4 * np.pi * ph)
	x = np.tanh(x * drive) / np.tanh(drive)
	return x * adsr(len(t), .006, .4, .75, .06, d) * vel


def fm_bass(m, d, vel=1.0, bite=2.0):
	t = _t(d)
	f = midi(m)
	idx = bite * np.exp(-t * 9) + .3
	x = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * t))
	return x * adsr(len(t), .003, .25, .5, .05, d) * vel


def saw(f, t, detune=0.0):
	ph = (f * (1 + detune)) * t
	return 2 * (ph % 1) - 1


def pad(ms, d, vel=1.0, cutoff=1400, attack=.8, detune=.006):
	t = _t(d + attack)
	x = np.zeros(len(t))
	for m in ms:
		f = midi(m)
		for k in (-1, 0, 1):
			x += saw(f, t + k * .0013, detune * k)
	x = filt(x / (3 * len(ms)), 'low', cutoff, 2)
	return x * adsr(len(t), attack, 9, 1, attack, d + attack) * vel


def square_lead(m, d, vel=1.0, vib=.004, cutoff=2600):
	t = _t(d + .05)
	f = midi(m) * (1 + vib * np.sin(2 * np.pi * 5.2 * t) * np.clip(t * 3, 0, 1))
	ph = np.cumsum(f) / R
	x = np.where(ph % 1 < .5, 1.0, -1.0)
	x = filt(x, 'low', cutoff, 2)
	return x * adsr(len(t), .01, .2, .7, .06, d + .05) * vel


def organ(ms, d, vel=1.0):
	t = _t(d)
	x = np.zeros(len(t))
	for m in ms:
		f = midi(m)
		x += np.sin(2 * np.pi * f * t) + .5 * np.sin(4 * np.pi * f * t) + .25 * np.sin(6 * np.pi * f * t)
	return x / len(ms) * adsr(len(t), .004, .08, .8, .03, d) * vel


def clav(m, d, vel=1.0):
	"""Funky clavinet-like pluck: bright pulse through a fast-closing filter."""
	t = _t(d + .05)
	f = midi(m)
	ph = f * t
	x = np.where(ph % 1 < .3, 1.0, -.43) + .3 * np.sin(2 * np.pi * 2 * ph)
	bright = filt(x, 'low', 4200)
	dark = filt(x, 'low', 700)
	e = np.exp(-t * 18)
	x = bright * e + dark * (1 - e)
	return x * adsr(len(t), .001, .15, .45, .03, d + .05) * vel


def piano(m, d, vel=1.0):
	t = _t(d + .6)
	f = midi(m)
	x = sum(a * np.sin(2 * np.pi * f * h * (1 + .0004 * h * h) * t) * np.exp(-t * (1.5 + h * 1.1)) for h, a in ((1, 1), (2, .5), (3, .28), (4, .16), (5, .08)))
	x += .2 * np.random.default_rng(int(m)).uniform(-1, 1, len(t)) * np.exp(-t * 200)
	return x * adsr(len(t), .002, 9, 1, .25) * vel


def strum(ms, d, vel=1.0, down=True, spread=.011, damp=.45, seed=0):
	"""Acoustic strum: Karplus-Strong strings hit in order, down or up stroke."""
	order = ms if down else ms[::-1]
	rng = np.random.default_rng(seed + int(sum(ms)) + (0 if down else 7))
	n = round((d + .6) * R)
	x = np.zeros(n)
	for i, m in enumerate(order):
		s = pluck(m, d + .4, vel * (1 - .06 * i) * (1 if down else .7), damp, rng)
		o = round(i * spread * R)
		k = min(len(s), n - o)
		x[o:o + k] += s[:k]
	pick = filt(rng.uniform(-1, 1, round(.02 * R)), 'high', 3000) * np.exp(-np.arange(round(.02 * R)) / R * 250)
	x[:len(pick)] += pick * .25 * vel
	return x * adsr(n, .001, 9, 1, .08, n / R) / max(len(ms), 1) * 2.2


def chop(ms, d, vel=1.0, seed=0):
	"""Palm-muted chord chop: short, dark, percussive."""
	x = strum(ms, min(d, .12), vel, True, .004, .9, seed)
	n = round((min(d, .12) + .1) * R)
	x = x[:n] * np.exp(-np.arange(n) / R * 22)
	return filt(x, 'low', 2400)


VOWELS = {'oo': (300, 870, 2240), 'ah': (730, 1090, 2440), 'oh': (570, 840, 2410), 'ee': (270, 2290, 3010)}


def choir(ms, d, vel=1.0, vowel='oo', attack=.25, seed=0):
	"""Gang 'ooh' backing: detuned voices through vowel formants, gentle vibrato."""
	rng = np.random.default_rng(seed + int(sum(ms)))
	t = _t(d + attack)
	x = np.zeros(len(t))
	for m in ms:
		for k in range(3):
			f = midi(m) * (1 + rng.normal(0, .004)) * (1 + .006 * np.sin(2 * np.pi * (5 + k * .4) * t + k))
			ph = np.cumsum(f) / R
			x += 2 * (ph % 1) - 1
	x /= 3 * len(ms)
	f1, f2, f3 = VOWELS[vowel]
	y = filt(x, 'band', [f1 * .8, f1 * 1.25]) * 1.0 + filt(x, 'band', [f2 * .85, f2 * 1.15]) * .5 + filt(x, 'band', [f3 * .9, f3 * 1.1]) * .2
	y += filt(rng.normal(0, 1, len(t)), 'band', [1500, 5000]) * .02  # breath
	return y * adsr(len(t), attack, 9, 1, attack, d + attack) * vel * 3


def whistle(m, d, vel=1.0, slide_from=None):
	"""Breathy falsetto/whistle lead with delayed vibrato and optional slide in."""
	t = _t(d + .08)
	f = np.full(len(t), midi(m))
	if slide_from is not None:
		f = midi(m) + (midi(slide_from) - midi(m)) * np.exp(-t * 25)
	f = f * (1 + .012 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - .15) * 3, 0, 1))
	ph = np.cumsum(f) / R
	x = np.sin(2 * np.pi * ph) + .08 * np.sin(4 * np.pi * ph)
	x += filt(np.random.default_rng(int(m)).normal(0, 1, len(t)), 'band', [1500, 4500]) * .06
	return x * adsr(len(t), .04, .3, .85, .08, d + .08) * vel


def upright(m, d, vel=1.0):
	"""Plucked upright-style bass: thumpy attack, round body."""
	t = _t(d + .1)
	f = midi(m)
	x = np.sin(2 * np.pi * f * t) + .35 * np.sin(4 * np.pi * f * t) * np.exp(-t * 6) + .15 * np.sin(6 * np.pi * f * t) * np.exp(-t * 12)
	x += .3 * np.sin(2 * np.pi * f * 1.5 * t) * np.exp(-t * 40)
	return np.tanh(1.3 * x) * np.exp(-t * 2.2) * adsr(len(t), .004, 9, 1, .06, d + .1) * vel


def glide_lead(m, d, vel=1.0, glide_from=None, cutoff=1800, detune=.007):
	"""Soft detuned saw lead with portamento: hazy, melancholic top line."""
	t = _t(d + .12)
	f = np.full(len(t), midi(m))
	if glide_from is not None:
		f = midi(m) + (midi(glide_from) - midi(m)) * np.exp(-t * 14)
	f = f * (1 + .005 * np.sin(2 * np.pi * 4.8 * t) * np.clip((t - .2) * 2, 0, 1))
	x = np.zeros(len(t))
	for k in (-1, 0, 1):
		ph = np.cumsum(f * (1 + k * detune)) / R
		x += 2 * (ph % 1) - 1
	x = filt(x / 3, 'low', cutoff, 2)
	return x * adsr(len(t), .03, .4, .8, .12, d + .12) * vel


def vocal_chop(m, d, vel=1.0, vowel='ah', seed=0):
	"""Short pitched vocal-like stab (formant voice, fast gate)."""
	x = choir([m], d, vel, vowel, .008, seed)
	n = len(x)
	x *= np.exp(-np.arange(n) / R * 5)
	return x


def eguitar(m, d, vel=1.0, seed=0):
	"""Clean electric guitar note: bright pluck through a slow chorus."""
	x = pluck(m, d, vel, .25, np.random.default_rng(seed + int(m)))
	n = len(x)
	lfo = 1 + .0025 * np.sin(2 * np.pi * .8 * np.arange(n) / R)
	idx = np.clip(np.arange(n) * lfo - R * .006, 0, n - 1)
	wet = np.interp(idx, np.arange(n), x)
	return filt(.7 * x + .5 * wet, 'low', 3800)


def bell(m, d, vel=1.0):
	"""Glassy FM bell: 3.5 ratio modulator, long soft decay."""
	t = _t(d + 1)
	f = midi(m)
	x = np.sin(2 * np.pi * f * t + 2.2 * np.exp(-t * 4) * np.sin(2 * np.pi * f * 3.5 * t))
	return x * np.exp(-t * 2.5) * adsr(len(t), .002, 9, 1, .3) * vel


def bass808(m, d, vel=1.0, glide_from=None):
	"""Long 808 sub with click and optional slide; soft saturation."""
	t = _t(d)
	f = np.full(len(t), midi(m))
	if glide_from is not None:
		f = midi(m) + (midi(glide_from) - midi(m)) * np.exp(-t * 18)
	ph = np.cumsum(f * (1 + .5 * np.exp(-t * 60))) / R
	x = np.tanh(1.8 * np.sin(2 * np.pi * ph)) * adsr(len(t), .002, .9, .55, .08, d)
	return x * vel


# ---------------------------------------------------------------- drums

def kick(kind='round', vel=1.0):
	t = _t(.45)
	if kind == '808':
		t = _t(.9)
		f = 44 + 70 * np.exp(-t * 35)
		dec = 3.2
	elif kind == 'deep':
		f = 42 + 90 * np.exp(-t * 28)
		dec = 6
	elif kind == 'tight':
		f = 55 + 140 * np.exp(-t * 45)
		dec = 14
	else:
		f = 48 + 110 * np.exp(-t * 32)
		dec = 9
	ph = np.cumsum(f) / R
	x = np.sin(2 * np.pi * ph) * np.exp(-t * dec)
	click = filt(np.random.default_rng(1).uniform(-1, 1, len(t)), 'band', [1200, 5000]) * np.exp(-t * 300)
	x = np.tanh(1.6 * (x + .5 * click))
	return x * vel


def snare(kind='crack', vel=1.0, rng=None):
	rng = rng or np.random.default_rng(2)
	t = _t(.35)
	noise = rng.uniform(-1, 1, len(t))
	if kind == 'rim':
		x = filt(noise, 'band', [1500, 5000]) * np.exp(-t * 90) + .6 * np.sin(2 * np.pi * 820 * t) * np.exp(-t * 70)
	elif kind == 'brush':
		x = filt(noise, 'band', [900, 6500]) * np.exp(-t * 14) * np.minimum(1, t / .012)
	elif kind == 'clap':
		env = sum(np.exp(-np.clip(t - o, 0, None) * 120) * (t >= o) for o in (0, .011, .022)) + .6 * np.exp(-t * 18)
		x = filt(noise, 'band', [900, 4000]) * env / 2
	else:
		body = np.sin(2 * np.pi * (185 + 60 * np.exp(-t * 60)) * t) * np.exp(-t * 26)
		x = .8 * body + filt(noise, 'band', [1500, 7500]) * np.exp(-t * (20 if kind == 'crack' else 32))
	return np.tanh(1.3 * x) * vel


def hat(kind='closed', vel=1.0, rng=None):
	rng = rng or np.random.default_rng(3)
	d = {'closed': .06, 'open': .35, 'shaker': .09, 'ride': .9}[kind]
	t = _t(d)
	noise = rng.uniform(-1, 1, len(t))
	if kind == 'ride':
		metal = sum(np.sign(np.sin(2 * np.pi * f * t)) for f in (507, 741, 1103, 1339, 1587)) / 5
		x = filt(.5 * noise + metal, 'high', 3500) * np.exp(-t * 3.5)
	elif kind == 'shaker':
		x = filt(noise, 'band', [4000, 11000]) * np.minimum(1, t / .015) * np.exp(-t * 35)
	else:
		x = filt(noise, 'high', 7000, 3) * np.exp(-t * (70 if kind == 'closed' else 9))
	return x * vel


def tom(m, vel=1.0):
	t = _t(.4)
	f = midi(m) * (1 + .5 * np.exp(-t * 30))
	ph = np.cumsum(f) / R
	return np.sin(2 * np.pi * ph) * np.exp(-t * 9) * vel


def conga(m, vel=1.0, slap=False, rng=None):
	rng = rng or np.random.default_rng(4)
	t = _t(.35)
	f = midi(m) * (1 + .12 * np.exp(-t * 60))
	x = np.sin(2 * np.pi * np.cumsum(f) / R) * np.exp(-t * (16 if slap else 7))
	x += (.6 if slap else .15) * filt(rng.uniform(-1, 1, len(t)), 'band', [800, 4000]) * np.exp(-t * 90)
	return x * vel


def cowbell(vel=1.0):
	t = _t(.3)
	x = sum(np.where((f * t) % 1 < .5, 1.0, -1.0) for f in (540, 800)) / 2
	return filt(x, 'band', [500, 3000]) * np.exp(-t * 14) * np.minimum(1, t / .001) * vel


def metal_perc(vel=1.0, base=310, rng=None):
	t = _t(.5)
	x = sum(a * np.sin(2 * np.pi * base * r * t) * np.exp(-t * dcy) for r, a, dcy in ((1, 1, 9), (2.76, .6, 14), (5.4, .4, 20), (8.93, .25, 30)))
	return x * np.minimum(1, t / .0008) * vel


def taiko(vel=1.0):
	t = _t(.9)
	f = 62 * (1 + .6 * np.exp(-t * 25))
	x = np.sin(2 * np.pi * np.cumsum(f) / R) * np.exp(-t * 4.5)
	x += .3 * filt(np.random.default_rng(8).uniform(-1, 1, len(t)), 'low', 600) * np.exp(-t * 30)
	return np.tanh(1.5 * x) * vel


def stomp(vel=1.0, rng=None):
	"""Foot stomp on a wooden floor: low thud plus boards."""
	rng = rng or np.random.default_rng(9)
	t = _t(.35)
	x = np.sin(2 * np.pi * np.cumsum(70 * (1 + .8 * np.exp(-t * 40))) / R) * np.exp(-t * 14)
	x += .5 * filt(rng.uniform(-1, 1, len(t)), 'band', [150, 900]) * np.exp(-t * 30)
	x += .15 * np.sin(2 * np.pi * 210 * t) * np.exp(-t * 20)
	return np.tanh(1.4 * x) * vel


def tambourine(vel=1.0, rng=None, shake=False):
	rng = rng or np.random.default_rng(10)
	t = _t(.25 if shake else .18)
	jingles = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * 30) for f in (5200, 6900, 8300, 9700)) / 4
	x = filt(rng.uniform(-1, 1, len(t)), 'high', 6000) * np.exp(-t * (18 if shake else 40)) + .4 * jingles
	if shake:
		x *= np.minimum(1, t / .03)
	return x * vel


def perc_block(m, vel=1.0):
	t = _t(.12)
	return np.sin(2 * np.pi * midi(m) * t) * np.exp(-t * 55) * vel


# ---------------------------------------------------------------- effects (loop-safe)

def circular_convolve(x, ir):
	"""Convolve and fold the tail back into the start, so the loop seam is seamless."""
	y = fftconvolve(x, ir, axes=0)
	n = len(x)
	out = y[:n].copy()
	tail = y[n:]
	while len(tail):
		k = min(n, len(tail))
		out[:k] += tail[:k]
		tail = tail[k:]
	return out


def reverb_ir(seconds=1.8, damp=4000, seed=7):
	rng = np.random.default_rng(seed)
	t = _t(seconds)
	env = np.exp(-t * 6.9 / seconds)
	ir = np.stack([filt(rng.normal(0, 1, len(t)), 'low', damp) * env for _ in range(2)], axis=1)
	ir[:round(.012 * R)] *= np.linspace(0, 1, round(.012 * R))[:, None]
	return ir / np.sqrt(np.sum(ir * ir) / 2)


def reverb(x, amount=.2, seconds=1.8, damp=4000, seed=7):
	ir = reverb_ir(seconds, damp, seed)
	wet = np.stack([circular_convolve(x[:, c], ir[:, c]) for c in range(2)], axis=1)
	return x + wet * amount


def delay(x, seconds, feedback=.35, mix=.3, pingpong=True, lp=3000):
	n = len(x)
	d = round(seconds * R)
	out = np.zeros_like(x)
	tap = x.copy()
	g = 1.0
	for _ in range(8):
		tap = np.roll(filt(tap, 'low', lp, 1), d, axis=0)
		if pingpong:
			tap = tap[:, ::-1]
		g *= feedback
		out += tap * g
	return x + out * mix / max(feedback, 1e-6)


def duck(x, beats_positions, track, depth=.5, release=.18):
	"""Sidechain-style gain dip after each kick."""
	env = np.ones(track.n)
	t = _t(release * 3)
	shape = 1 - depth * np.exp(-t / release)
	for b in beats_positions:
		i0 = round(track.time(b) * R)
		ix = (np.arange(len(t)) + i0) % track.n
		env[ix] = np.minimum(env[ix], shape)
	return x * env[:, None]


def tape(x, wow=.0015, rate=.55, seed=11):
	"""Gentle wow: tiny periodic pitch drift via resampling, loop-safe (integer cycles)."""
	n = len(x)
	cycles = max(1, round(rate * n / R))
	idx = np.arange(n) + wow * R * np.sin(2 * np.pi * cycles * np.arange(n) / n)
	idx %= n
	i0 = np.floor(idx).astype(int)
	fr = (idx - i0)[:, None]
	return x[i0] * (1 - fr) + x[(i0 + 1) % n] * fr


def vinyl(n, amount=.004, seed=5):
	rng = np.random.default_rng(seed)
	hiss = filt(rng.normal(0, 1, n), 'band', [1500, 9000]) * amount * .35
	crack = np.zeros(n)
	pos = rng.integers(0, n, int(n / R * 9))
	crack[pos] = rng.uniform(-1, 1, len(pos)) * amount * 6
	crack = filt(crack, 'high', 1500)
	mono = hiss + crack
	return np.stack([mono, np.roll(mono, 37)], axis=1)


def master(x, target_rms=.085, ceiling=.8, warmth=1.2):
	x = x - x.mean(axis=0)
	x = np.tanh(x * warmth / max(np.max(np.abs(x)), 1e-6)) if warmth else x
	rms = np.sqrt(np.mean(x * x))
	x = x * min(target_rms / max(rms, 1e-9), ceiling / max(np.max(np.abs(x)), 1e-9))
	return x
