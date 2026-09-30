"""Realistic-leaning combat sounds from plain synthesis (NumPy + SciPy, no recordings).

Layers instead of chip tones: transient click, band-limited blast, low thump,
mechanical action, outdoor slap echo, debris grains, modal metal resonances,
engine firing-pulse trains. Loops are built periodic, so the seam is seamless.

    python tools/build_combat_audio.py           # preview only -> audio_demo/combat
    python tools/build_combat_audio.py --apply   # overwrite banks in assets/audio/chip
"""
from pathlib import Path
import json, sys, wave
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent / 'audio'))
from synth_kit import R, save, filt  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
CHIP = ROOT / 'assets/audio/chip'
DEMO = ROOT / 'audio_demo/combat'


def T(d):
	return np.arange(max(1, round(d * R))) / R


def env_exp(t, rate, attack=.0008):
	return np.minimum(1, t / attack) * np.exp(-t * rate)


def pad_to(x, n):
	return np.pad(x, (0, max(0, n - len(x))))[:n]


def add(dst, src, at=0.0, gain=1.0):
	i = round(at * R)
	if i >= len(dst):
		return dst
	k = min(len(src), len(dst) - i)
	dst[i:i + k] += src[:k] * gain
	return dst


def noise(rng, n):
	return rng.uniform(-1, 1, n)


def brown(rng, n):
	x = np.cumsum(rng.normal(0, 1, n))
	x = filt(x, 'high', 20)
	return x / max(np.max(np.abs(x)), 1e-9)


def sweep_noise(rng, d, f0, f1, order=2, steps=10):
	"""Noise whose lowpass cutoff glides f0 -> f1: crossfade a bank of filtered copies."""
	n = round(d * R)
	src = noise(rng, n)
	cut = f0 * (f1 / f0) ** np.linspace(0, 1, steps)
	bank = np.stack([filt(src, 'low', f, order) for f in cut])
	pos = np.linspace(0, steps - 1, n)
	i = np.minimum(pos.astype(int), steps - 2)
	fr = pos - i
	cols = np.arange(n)
	return bank[i, cols] * (1 - fr) + bank[i + 1, cols] * fr


def sid(s):
	return sum(ord(c) * (i + 1) for i, c in enumerate(s)) % 997


def modes(t, freqs, decays, amps):
	x = np.zeros(len(t))
	for f, d, a in zip(freqs, decays, amps):
		x += a * np.sin(2 * np.pi * f * t + a) * np.exp(-t * d)
	return x


def slap_echo(x, rng, delays=(.085, .16, .27), gain=.28, lp=1800):
	"""Outdoor reflections: few delayed, darker copies plus a short diffuse tail."""
	out = x.copy()
	for i, dl in enumerate(delays):
		add(out, filt(x, 'low', lp / (1 + i * .6)), dl * rng.uniform(.9, 1.1), gain / (1 + i))
	return out


def tail(rng, d, lp, level, rate):
	t = T(d)
	return filt(noise(rng, len(t)), 'low', lp) * np.exp(-t * rate) * np.minimum(1, t / .01) * level


def finish(x, peak=.7, fade=.02):
	x = x - np.mean(x)
	x = np.tanh(x * 1.4 / max(np.max(np.abs(x)), 1e-9))
	n = round(fade * R)
	x[-n:] *= np.linspace(1, 0, n)
	x[:24] *= np.linspace(0, 1, 24)
	return x * peak / max(np.max(np.abs(x)), 1e-9)


# ----------------------------------------------------------------- guns
GUNS = {
	# crack band, body lowpass, thump Hz, body length s, tail s, echo gain, mechanics
	'pistol': dict(crack=(2500, 9000), body=2600, thump=140, blen=.05, tail=.35, echo=.22, mech=.9),
	'smg': dict(crack=(3000, 10000), body=3000, thump=170, blen=.03, tail=.18, echo=.12, mech=.5),
	'rifle': dict(crack=(2200, 11000), body=2200, thump=110, blen=.06, tail=.5, echo=.3, mech=.6),
	'sniper': dict(crack=(1800, 12000), body=1800, thump=80, blen=.09, tail=1.1, echo=.45, mech=0),
	'shotgun': dict(crack=(1500, 7000), body=1500, thump=75, blen=.11, tail=.7, echo=.38, mech=0),
	'vehicle_mg': dict(crack=(1800, 8000), body=1600, thump=90, blen=.05, tail=.28, echo=.18, mech=.3),
	'tank': dict(crack=(900, 5000), body=700, thump=45, blen=.25, tail=1.6, echo=.5, mech=0),
	'boss': dict(crack=(800, 4500), body=600, thump=38, blen=.3, tail=1.8, echo=.5, mech=0),
}


def gun(name, v):
	g = GUNS[name]
	rng = np.random.default_rng(1000 + sid(name) + v * 31)
	k = 1 + (v - 1) * .05 * rng.uniform(-1, 1)
	d = g['tail'] + .15
	t = T(d)
	x = np.zeros(len(t))
	# 1. supersonic crack / muzzle click: very short, bright
	c = filt(noise(rng, round(.006 * R)), 'band', list(g['crack'])) * env_exp(T(.006), 900)
	add(x, c, 0, 1.0)
	# 2. muzzle blast: noise, cutoff falling fast
	blen = g['blen'] * k
	blast = sweep_noise(rng, blen * 3, g['body'] * 1.6, g['body'] * .25) * env_exp(T(blen * 3), 3 / blen, .0015)
	add(x, blast, .0005, 1.1)
	# 3. low thump (pressure wave)
	tt = T(blen * 4)
	f = g['thump'] * k * (1 + 1.5 * np.exp(-tt * 60))
	add(x, np.sin(2 * np.pi * np.cumsum(f) / R) * env_exp(tt, 1.6 / blen, .002), 0, .9)
	# 4. environment tail and discrete slaps
	add(x, tail(rng, g['tail'], 900 if name in ('tank', 'boss', 'sniper') else 1400, .16, 5 / g['tail']), .02)
	x = slap_echo(x, rng, gain=g['echo'], lp=1600)
	# 5. mechanical action (slide / bolt) a bit later, quiet
	if g['mech']:
		tm = T(.03)
		clack = modes(tm, [2300 * k, 3700 * k, 5200], [180, 240, 300], [.6, .4, .25]) + .4 * filt(noise(rng, len(tm)), 'high', 3000) * np.exp(-tm * 400)
		add(x, clack, .045 + .02 * rng.random(), .11 * g['mech'])
	if name in ('tank', 'boss'):
		# long rolling rumble, the cannon "carries" over terrain
		add(x, filt(brown(rng, len(t)), 'low', 160) * np.exp(-t * 2.2) * np.minimum(1, t / .05), .01, .8)
	return finish(x, .72)


def mortar(v):
	"""Tube 'thoonk': hollow resonance, short puff, distant whistle up."""
	rng = np.random.default_rng(2000 + v)
	t = T(.9)
	x = np.zeros(len(t))
	tt = T(.25)
	f = 95 * (1 + .6 * np.exp(-tt * 40)) * (1 + .03 * v)
	add(x, np.sin(2 * np.pi * np.cumsum(f) / R) * env_exp(tt, 18, .003), 0, 1)
	add(x, np.sin(2 * np.pi * np.cumsum(f * 2.7) / R) * env_exp(tt, 30, .003), 0, .3)
	add(x, sweep_noise(rng, .2, 2500, 300) * env_exp(T(.2), 25, .002), 0, .7)
	add(x, tail(rng, .7, 700, .15, 6), .03)
	return finish(slap_echo(x, rng, gain=.3), .7)


def launcher(v, rocket=False):
	"""Grenade launcher 'bloop' or RPG ignition + whoosh."""
	rng = np.random.default_rng(3000 + v + 50 * rocket)
	d = 1.0 if rocket else .5
	t = T(d)
	x = np.zeros(len(t))
	tt = T(.12)
	pop = np.sin(2 * np.pi * np.cumsum(170 * (1 + .8 * np.exp(-tt * 50)) * (1 + .04 * v)) / R) * env_exp(tt, 30, .002)
	add(x, pop, 0, .9)
	add(x, filt(noise(rng, round(.01 * R)), 'band', [1500, 6000]) * env_exp(T(.01), 500), 0, .6)
	if rocket:
		n = round(.85 * R)
		tw = T(.85)
		whoosh = filt(noise(rng, n), 'band', [500, 3000]) * np.minimum(1, tw / .05) * np.exp(-tw * 3)
		hiss = filt(noise(rng, n), 'high', 4000) * np.exp(-tw * 5)
		add(x, whoosh + .5 * hiss, .01, .9)
		add(x, sweep_noise(rng, .3, 1800, 200) * env_exp(T(.3), 12, .002), 0, .8)
	else:
		add(x, tail(rng, .35, 1000, .12, 9), .02)
	return finish(slap_echo(x, rng, gain=.22), .7)


# ----------------------------------------------------------------- explosions
def explosion(v, heavy=False, vehicle=False):
	rng = np.random.default_rng(4000 + v + 100 * heavy + 200 * vehicle)
	d = 2.0 if heavy or vehicle else 1.1
	t = T(d)
	x = np.zeros(len(t))
	# initial crack
	add(x, filt(noise(rng, round(.012 * R)), 'band', [800, 7000]) * env_exp(T(.012), 300), 0, .9)
	# low boom: sine sweep down + brown noise body
	f = (55 if heavy or vehicle else 75) * (1 + 1.4 * np.exp(-t * 10)) * (1 + .04 * v)
	add(x, np.sin(2 * np.pi * np.cumsum(f) / R) * env_exp(t, 4 if heavy else 7, .004), 0, 1.0)
	body = sweep_noise(rng, d, 4200, 180, 2, 32) * env_exp(t, 3.2 if heavy else 5.5, .003)
	add(x, body, 0, .95)
	add(x, filt(brown(rng, len(t)), 'low', 220) * env_exp(t, 2 if heavy else 3.5, .02), 0, .8)
	# debris: sparse grains, stones and small metal, falling in density
	grains = 70 if heavy or vehicle else 35
	for _ in range(grains):
		at = .08 + rng.exponential(.25 if heavy else .15)
		if at > d - .05:
			continue
		tg = T(.02)
		if rng.random() < .3 or vehicle:
			gs = modes(tg, rng.uniform(1500, 4500, 2), [220, 300], [.5, .3])
		else:
			gs = filt(noise(rng, len(tg)), 'band', [rng.uniform(600, 1500), rng.uniform(2500, 6000)])
		add(x, gs * np.exp(-tg * 180), at, rng.uniform(.03, .12) * np.exp(-at * 1.5))
	if vehicle:
		# metal body: low clang and rattling hull
		tc = T(1.2)
		add(x, modes(tc, [180, 262, 415, 690, 1120], [3, 4, 6, 8, 12], [.5, .35, .3, .2, .12]), .05, .35)
	return finish(slap_echo(x, rng, (.12, .25, .41), .3, 900), .78)


def debris(v):
	rng = np.random.default_rng(5000 + v)
	t = T(.6)
	x = np.zeros(len(t))
	add(x, filt(brown(rng, len(t)), 'low', 400) * env_exp(t, 9, .005), 0, .5)
	for _ in range(28):
		at = rng.exponential(.12)
		if at > .5:
			continue
		tg = T(.025)
		add(x, filt(noise(rng, len(tg)), 'band', [rng.uniform(400, 1200), rng.uniform(2000, 5000)]) * np.exp(-tg * 150), at, rng.uniform(.1, .35) * np.exp(-at * 3))
	return finish(x, .6)


def crumble(v):
	"""Wall section breaking: crack, rubble stream, low settle."""
	rng = np.random.default_rng(5500 + v)
	d = .75
	t = T(d)
	x = np.zeros(len(t))
	add(x, filt(noise(rng, round(.02 * R)), 'band', [400, 3500]) * env_exp(T(.02), 160), 0, .7)
	add(x, sweep_noise(rng, d, 2500, 250) * env_exp(t, 6, .01), 0, .5)
	add(x, filt(brown(rng, len(t)), 'low', 260) * env_exp(t, 5, .02), 0, .6)
	for _ in range(45):
		at = .02 + rng.exponential(.14)
		if at > d - .05:
			continue
		tg = T(.03)
		add(x, filt(noise(rng, len(tg)), 'band', [rng.uniform(300, 900), rng.uniform(1500, 4500)]) * np.exp(-tg * rng.uniform(90, 200)), at, rng.uniform(.06, .25) * np.exp(-at * 2))
	return finish(x, .65)


# ----------------------------------------------------------------- impacts
def impact(kind, v):
	rng = np.random.default_rng(6000 + sid(kind) + v * 7)
	k = 1 + .06 * (v - 1)
	d = {'hit_metal': .45, 'hit_stone': .22, 'hit_wood': .22, 'hit_body': .2, 'base_hit': .8, 'player_hurt': .3}[kind]
	t = T(d)
	x = np.zeros(len(t))
	if kind in ('hit_metal', 'base_hit'):
		low = kind == 'base_hit'
		fr = np.array([420, 1030, 1680, 2470, 3390]) * (0.45 if low else 1) * k * rng.uniform(.96, 1.04, 5)
		add(x, filt(noise(rng, round(.004 * R)), 'high', 2000) * env_exp(T(.004), 900), 0, .8)
		add(x, modes(t, fr, [9, 14, 20, 28, 38] if low else [14, 20, 26, 35, 50], [.6, .5, .4, .25, .15]), 0, .7)
		add(x, filt(noise(rng, len(t)), 'band', [800, 5000]) * env_exp(t, 60), 0, .25)
		if low:
			add(x, np.sin(2 * np.pi * np.cumsum(70 * (1 + np.exp(-t * 30))) / R) * env_exp(t, 10, .002), 0, .8)
	elif kind == 'hit_stone':
		add(x, filt(noise(rng, len(t)), 'band', [500, 4000]) * env_exp(t, 45, .001), 0, .9)
		add(x, np.sin(2 * np.pi * 160 * k * t) * env_exp(t, 40, .001), 0, .4)
		for _ in range(6):
			tg = T(.012)
			add(x, filt(noise(rng, len(tg)), 'high', 2500) * np.exp(-tg * 300), rng.uniform(.01, .12), rng.uniform(.1, .3))
	elif kind == 'hit_wood':
		add(x, modes(t, np.array([190, 460, 910, 1480]) * k, [30, 45, 70, 90], [.6, .45, .3, .2]), 0, .8)
		add(x, filt(noise(rng, len(t)), 'band', [700, 3500]) * env_exp(t, 70), 0, .45)
	else:  # body / player_hurt: dull thud with fabric
		add(x, np.sin(2 * np.pi * np.cumsum(110 * k * (1 + .7 * np.exp(-t * 50))) / R) * env_exp(t, 28, .002), 0, 1)
		add(x, filt(noise(rng, len(t)), 'low', 900) * env_exp(t, 35, .002), 0, .6)
		add(x, filt(noise(rng, len(t)), 'band', [2000, 6000]) * env_exp(t, 80), .005, .15)
		if kind == 'player_hurt':  # plus a short, clearly readable armour ping
			add(x, modes(t, [1250, 1980], [18, 24], [.4, .25]), .01, .35)
	return finish(x, .66)


def ricochet(v):
	rng = np.random.default_rng(7000 + v)
	d = .55
	t = T(d)
	x = np.zeros(len(t))
	add(x, filt(noise(rng, round(.006 * R)), 'high', 2500) * env_exp(T(.006), 700), 0, .8)
	f0 = rng.uniform(2800, 3600)
	f = f0 * np.exp(-t * rng.uniform(1.5, 2.6)) * (1 + .015 * np.sin(2 * np.pi * 38 * t))
	whine = np.sin(2 * np.pi * np.cumsum(f) / R) * np.minimum(1, t / .015) * np.exp(-t * 5)
	add(x, whine + .3 * filt(noise(rng, len(t)), 'band', [2000, 6000]) * np.exp(-t * 12), .004, .5)
	return finish(x, .55)


def body_fall(v):
	"""Soldier going down: two thuds + small gear rattle, no voice."""
	rng = np.random.default_rng(7500 + v)
	t = T(.5)
	x = np.zeros(len(t))
	for at, g in ((0, 1), (.11 + .03 * v, .7)):
		tt = T(.15)
		add(x, np.sin(2 * np.pi * np.cumsum(85 * (1 + .6 * np.exp(-tt * 40))) / R) * env_exp(tt, 30, .003) + .5 * filt(noise(rng, len(tt)), 'low', 700) * env_exp(tt, 40, .002), at, g)
	for _ in range(5):
		tg = T(.02)
		add(x, modes(tg, rng.uniform(2000, 4500, 2), [200, 260], [.5, .3]), rng.uniform(.02, .3), .12)
	return finish(x, .6)


def grenade_throw(v):
	rng = np.random.default_rng(8000 + v)
	t = T(.35)
	sw = np.sin(np.pi * np.clip(t / .3, 0, 1)) ** 2
	x = filt(noise(rng, len(t)), 'band', [600 + 200 * v, 2600]) * sw
	add(x, modes(T(.03), [2600, 3900], [200, 260], [.4, .3]), .0, .25)
	return finish(x, .45)


def grenade_land(v):
	rng = np.random.default_rng(8100 + v)
	t = T(.45)
	x = np.zeros(len(t))
	for i, at in enumerate([0, .13 + .02 * v, .22 + .02 * v]):
		tt = T(.12)
		add(x, modes(tt, np.array([1850, 2900, 4300]) * (1 + .03 * v), [40, 55, 70], [.5, .3, .2]) + .4 * np.sin(2 * np.pi * 180 * tt) * np.exp(-tt * 50), at, .8 / (1 + i))
	return finish(x, .5)


def mechanism(v):
	"""Bolt / pump: two metallic clacks with a slide between."""
	rng = np.random.default_rng(8200 + v)
	t = T(.32)
	x = np.zeros(len(t))
	for at, f in ((0, 1), (.15 + .02 * v, 1.15)):
		tt = T(.05)
		add(x, modes(tt, np.array([1900, 3100, 4700]) * f, [120, 160, 220], [.6, .4, .3]) + .5 * filt(noise(rng, len(tt)), 'high', 2500) * np.exp(-tt * 300), at, .8)
	add(x, filt(noise(rng, round(.1 * R)), 'band', [1500, 5000]) * np.sin(np.pi * np.linspace(0, 1, round(.1 * R))) ** 2, .04, .12)
	return finish(x, .5)


def mine_arm(v):
	rng = np.random.default_rng(8300 + v)
	t = T(.3)
	x = np.zeros(len(t))
	for at in (0, .09):
		tt = T(.03)
		add(x, modes(tt, [3200 + 300 * v, 5100], [250, 320], [.6, .3]), at, .7)
	add(x, np.sin(2 * np.pi * 2400 * T(.08)) * np.exp(-T(.08) * 40), .18, .2)
	return finish(x, .45)


# ----------------------------------------------------------------- loops
LOOP_S = 4.0


def loop_filter(x, kind, f, order=2):
	n = len(x)
	return filt(np.tile(x, 3), kind, f, order)[n:2 * n]


def pulse_train(rng, rate, n, make, jitter=.08):
	"""Place `make()` pulses around a circular buffer; count is integer so it loops."""
	x = np.zeros(n)
	count = max(1, round(rate * n / R))
	period = n / count
	for i in range(count):
		p = make(i)
		at = int(i * period + rng.normal(0, jitter * period))
		ix = (np.arange(len(p)) + at) % n
		np.add.at(x, ix, p)
	return x


def engine(name):
	rng = np.random.default_rng(9000 + sid(name))
	n = round(LOOP_S * R)
	cfg = {'engine_tank': (26, 90, 420, .5), 'engine_apc': (34, 120, 600, .35), 'engine_buggy': (58, 200, 1500, .2)}[name]
	fire_rate, body_f, lp, rough = cfg

	def cyl(i):
		tt = T(1.6 / fire_rate)
		g = 1 + rough * rng.normal(0, .35) + (.25 if i % 4 == 0 else 0)
		return (np.sin(2 * np.pi * body_f * tt) * np.exp(-tt * fire_rate * 3) + .6 * rng.uniform(-1, 1, len(tt)) * np.exp(-tt * fire_rate * 5)) * g
	x = pulse_train(rng, fire_rate, n, cyl, .03)
	x = loop_filter(x, 'low', lp)
	x += .12 * loop_filter(rng.uniform(-1, 1, n), 'band', [lp, lp * 3])  # intake / exhaust hiss
	x = np.tanh(x * 1.5 / np.max(np.abs(x)))
	return x * .5 / np.max(np.abs(x))


def tracks_loop():
	rng = np.random.default_rng(9100)
	n = round(LOOP_S * R)

	def link(i):
		tt = T(.05)
		return modes(tt, rng.uniform(700, 1600, 3), [90, 120, 160], [.5, .35, .25]) * rng.uniform(.5, 1)
	x = pulse_train(rng, 14, n, link, .12)
	x += .5 * loop_filter(rng.uniform(-1, 1, n), 'low', 250)  # ground rumble
	x += .15 * pulse_train(rng, 3.5, n, lambda i: np.sin(2 * np.pi * 60 * T(.12)) * np.exp(-T(.12) * 25), .05)
	return x * .45 / np.max(np.abs(x))


def rotor_small():
	"""Quad drone: four slightly detuned propellers, beating against each other."""
	rng = np.random.default_rng(9200)
	n = round(LOOP_S * R)
	t = np.arange(n) / R
	x = np.zeros(n)
	for f in (178, 183.5, 190.25, 196.5):  # integer cycles over 4 s
		ph = 2 * np.pi * f * t
		x += np.sin(ph) + .5 * np.sin(2 * ph + .3) + .25 * np.sin(3 * ph + .7) + .12 * np.sin(5 * ph)
	x += .25 * loop_filter(rng.uniform(-1, 1, n), 'band', [1500, 5000])
	return x * .4 / np.max(np.abs(x))


def helicopter():
	rng = np.random.default_rng(9300)
	n = round(LOOP_S * R)

	def blade(i):
		tt = T(.09)
		return np.sin(2 * np.pi * 70 * tt) * np.exp(-tt * 45) + .7 * filt(rng.uniform(-1, 1, len(tt)), 'band', [200, 1200]) * np.exp(-tt * 40)
	x = pulse_train(rng, 11, n, blade, .01)
	t = np.arange(n) / R
	x += .15 * np.sin(2 * np.pi * 220 * t) * (1 + .5 * np.sin(2 * np.pi * 11 * t))  # tail rotor whine
	x += .2 * loop_filter(rng.uniform(-1, 1, n), 'low', 600)
	return x * .5 / np.max(np.abs(x))


def servo():
	rng = np.random.default_rng(9400)
	n = round(LOOP_S * R)
	t = np.arange(n) / R
	f = 320 + 8 * np.sin(2 * np.pi * .5 * t)
	ph = 2 * np.pi * np.cumsum(f) / R
	ph *= round(ph[-1] / (2 * np.pi)) * 2 * np.pi / ph[-1]
	x = np.sin(ph) + .4 * np.sin(2 * ph) + .2 * np.sin(3 * ph)
	x += .3 * loop_filter(rng.uniform(-1, 1, n), 'band', [1800, 4000])
	x += .35 * pulse_train(rng, 30, n, lambda i: np.sin(2 * np.pi * 1400 * T(.008)) * np.exp(-T(.008) * 500), .1)
	return x * .35 / np.max(np.abs(x))


def ground_drone():
	rng = np.random.default_rng(9500)
	n = round(LOOP_S * R)
	t = np.arange(n) / R
	x = np.sin(2 * np.pi * 460 * t) + .3 * np.sin(2 * np.pi * 920 * t)
	x *= 1 + .2 * np.sin(2 * np.pi * 6 * t)
	x += .5 * loop_filter(rng.uniform(-1, 1, n), 'low', 400)
	x += .2 * pulse_train(rng, 9, n, lambda i: modes(T(.03), [900, 1500], [150, 200], [.5, .3]), .15)
	return x * .35 / np.max(np.abs(x))


def rocket_loop():
	rng = np.random.default_rng(9600)
	n = round(LOOP_S * R)
	t = np.arange(n) / R
	roar = loop_filter(rng.uniform(-1, 1, n), 'band', [300, 2500]) * (1 + .25 * np.sin(2 * np.pi * 7 * t))
	x = roar + .4 * loop_filter(rng.uniform(-1, 1, n), 'high', 4500) + .3 * loop_filter(rng.uniform(-1, 1, n), 'low', 150)
	return x * .45 / np.max(np.abs(x))


def seam(x):
	n = 256
	x = x.copy()
	x[-n:] += np.linspace(0, 1, n) * (x[0] - x[-1])
	return x


# ----------------------------------------------------------------- bank table
ONE_SHOTS = {
	**{f'fire_{g}': (lambda g: (lambda v: gun(g, v)))(g) for g in GUNS},
	'fire_mortar': mortar,
	'fire_grenade_launcher': lambda v: launcher(v),
	'fire_rpg': lambda v: launcher(v, True),
	'explosion_small': lambda v: explosion(v),
	'explosion_heavy': lambda v: explosion(v, True),
	'vehicle_destroy': lambda v: explosion(v, True, True),
	'debris': debris,
	'wall_crumble': crumble,
	'hit_metal': lambda v: impact('hit_metal', v),
	'hit_stone': lambda v: impact('hit_stone', v),
	'hit_wood': lambda v: impact('hit_wood', v),
	'hit_body': lambda v: impact('hit_body', v),
	'base_hit': lambda v: impact('base_hit', v),
	'player_hurt': lambda v: impact('player_hurt', v),
	'ricochet': ricochet,
	'infantry_down': body_fall,
	'grenade_throw': grenade_throw,
	'grenade_land': grenade_land,
	'weapon_mechanism': mechanism,
	'mine_arm': mine_arm,
}
# Bright clicks read louder than the old soft tones at equal RMS.
TRIM = {'weapon_mechanism': .5, 'mine_arm': .55, 'ricochet': .8, 'hit_metal': .8, 'grenade_land': .75, 'fire_smg': .85}
VARIANTS = {k: 4 for k in ONE_SHOTS if k.startswith('fire_') or k.startswith('hit_')}
LOOPS = {
	'engine_tank': lambda: engine('engine_tank'),
	'engine_apc': lambda: engine('engine_apc'),
	'engine_buggy': lambda: engine('engine_buggy'),
	'tracks': tracks_loop,
	'rotor_drone': rotor_small,
	'helicopter_rotor': helicopter,
	'turret_servo': servo,
	'ground_drone_motor': ground_drone,
	'rocket_flight': rocket_loop,
}


def loudness(x):
	"""RMS of the loudest 60 ms window: what the ear compares for short effects."""
	w = round(.06 * R)
	c = np.convolve(x * x, np.ones(w) / w, mode='valid') if len(x) > w else [np.mean(x * x)]
	return float(np.sqrt(np.max(c)))


def load(path):
	with wave.open(str(path)) as w:
		x = np.frombuffer(w.readframes(w.getnframes()), '<i2').astype(float) / 32767
		return x.reshape(-1, w.getnchannels()).mean(1), w.getframerate()


if __name__ == '__main__':
	apply = '--apply' in sys.argv
	manifest = json.loads((CHIP / 'manifest.json').read_text())
	(DEMO / 'new').mkdir(parents=True, exist_ok=True)
	reel_old, reel_new, report = [], [], {}
	gap = np.zeros(round(.35 * R))
	for id, fn in list(ONE_SHOTS.items()) + [(k, None) for k in LOOPS]:
		old_files = manifest[id]['files']
		count = VARIANTS.get(id, len(old_files)) if fn else 1
		old, old_rate = load(CHIP / old_files[0])
		files = []
		for v in range(1, count + 1):
			x = fn(v) if fn else seam(LOOPS[id]())
			# match the loudness the game was already mixed around (bus gains stay valid)
			x *= min(TRIM.get(id, 1) * loudness(old) / max(loudness(x), 1e-9), .95 / np.max(np.abs(x)))
			name = f'{id}_{v:02}.wav'
			save((CHIP if apply else DEMO / 'new') / name, x)
			files.append(name)
			if v == 1:
				report[id] = dict(seconds=round(len(x) / R, 3), peak=round(float(np.max(np.abs(x))), 3), loud_old=round(loudness(old), 4), loud_new=round(loudness(x), 4))
				o = np.interp(np.arange(round(len(old) * R / old_rate)) / R, np.arange(len(old)) / old_rate, old)
				reel_old.extend([o[:R * 2] if not fn else o, gap])
				reel_new.extend([x[:R * 2] if not fn else x, gap])
		if apply:
			manifest[id]['files'] = files
			manifest[id]['loop'] = fn is None
			manifest[id].pop('stats', None)
	if apply:
		(CHIP / 'manifest.json').write_text(json.dumps(manifest, indent=2))
	# A/B reel: each sound old then new
	ab = []
	for o, n in zip(reel_old[::2], reel_new[::2]):
		ab.extend([o, gap, n, gap, gap])
	save(DEMO / 'before_after.wav', np.concatenate(ab))
	save(DEMO / 'new_only.wav', np.concatenate(reel_new))
	(DEMO / 'report.json').write_text(json.dumps(report, indent=2))
	print(json.dumps(report, indent=1)[:3000])
	print('applied' if apply else 'preview only')
