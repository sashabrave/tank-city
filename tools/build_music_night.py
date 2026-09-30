"""Music themes, night set: chiller, dark-melodic alternative hip-hop textures.

Homage by texture only (melancholic minor harmony, sliding 808s, half-time
drums with short hat rolls, washed pumping pads, hazy glide leads, pitched
vocal chops, clean chorus guitar, tape warmth). All melodies are original.

Same layout as build_music_folk.py: 5 loops + 12 fanfares per theme, merged
into assets/audio/music/themes.json.

    python tools/build_music_night.py            # all three
    python tools/build_music_night.py neon       # one theme
Preview: audio_demo/night/<id>.wav
"""
from pathlib import Path
import json, sys
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent / 'audio'))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from synth_kit import *  # noqa: F401,F403
from build_music_breaks import pattern, chord_hits, phrase, active_rms
from build_music_folk import render, seed_of, MODES, MODE_TITLES, KINDS

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/music'
DEMO = ROOT / 'audio_demo/night'


def glider():
	"""Lead voice that slides from its previous note, reset per bar phrase."""
	state = {'last': None}

	def play(m, d, v):
		prev = state['last']
		state['last'] = m
		return glide_lead(m, d, v, prev if prev is not None and abs(prev - m) <= 5 else None, 1700)
	return play


def hat_roll(tr, at, count, rng, gain=.16):
	for k in range(count):
		tr.place('drums', at + k / 8, hat('closed', .5 + .5 * k / count, rng), gain, .2)


# ============================================================ Неон: half-time 808 haze
def neon_groove(tr, b0, bar, e, rng):
	# Calm half-time: no hat rolls or ghost notes, hats only as a soft pulse.
	if e == 0:
		pattern(tr, 'perc', b0, 'x.......x.......', lambda v: hat('shaker', v, rng), gain=.08)
		return
	pattern(tr, 'drums', b0, 'X.........x.....', lambda v: kick('808', v), gain=.7)
	pattern(tr, 'drums', b0, '........X.......', lambda v: snare('clap', v * .8, rng), gain=.34)
	pattern(tr, 'drums', b0, '..x...x...x...x.' if e >= 2 else 'x.......x.......', lambda v: hat('closed', v * .7, rng), gain=.11)
	if e >= 3:
		pattern(tr, 'perc', b0, 'x...x...x...x...', lambda v: hat('shaker', v, rng), gain=.08)


def neon_harmony(tr, b0, bar, chord, e):
	tr.place('keys', b0, pad(chord, tr.secs(4), .9, 1000, 1.0, .008), .3)
	if bar % 2 == 0:
		for b, i in ([(0, -1), (1.5, -3)] if e >= 1 else [(0, -1)]):
			tr.place('guitar', b0 + b, felt(chord[i] + 12, tr.secs(1.6), .6), .26, .3 if i % 2 else -.3)
	if e >= 2 and bar % 4 == 1:
		tr.place('perc', b0 + 2.75, vocal_chop(chord[-1] + 12, .5, .6, 'ah', bar), .22, -.25)


def neon_bass(tr, b0, bar, chord, r, e, nxt):
	if e == 0:
		tr.place('bass', b0, bass808(r, tr.secs(3.5), .6), .5)
		return
	tr.place('bass', b0, bass808(r, tr.secs(2.2), .9), .5)
	if e >= 2 and bar % 2 == 1:
		tr.place('bass', b0 + 2.5, bass808(nxt, tr.secs(1.3), .7, r), .5)


NEON = dict(title='Неон', bpm=124, bpb=4, swing=.06, bars=24,
	chords=[[54, 57, 61, 64, 68], [50, 54, 57, 61], [47, 50, 54, 57, 61], [49, 54, 56, 59]], roots=[30, 26, 35, 37],
	dark=[[47, 50, 54, 59], [43, 47, 50, 54], [40, 43, 47, 50, 54], [42, 46, 49, 52]], dark_roots=[35, 31, 28, 30],
	groove=neon_groove, harmony=neon_harmony, bass=neon_bass, lead=glider(), keys=None,
	motif=[(0, 2, 73), (2, 1, 71), (3, 2.5, 69), (6, 2, 66)],
	answer=[(0, 2, 73), (2, 1, 76), (3, 2.5, 73), (6, 2, 69)],
	vowel='ah', pump={'keys': .28, 'choir': .2}, chime=felt)


# ============================================================ Спальный район: sad clean guitar
def district_groove(tr, b0, bar, e, rng):
	pattern(tr, 'drums', b0, 'x.o.x.o.x.o.x.oo' if e >= 1 else 'x...x...x...x...', lambda v: hat('closed', v, rng), gain=.15 if e else .08)
	if e == 0:
		return
	pattern(tr, 'drums', b0, 'X......x..X.....' if bar % 2 == 0 else 'X.........X..x..', lambda v: kick('round', v), gain=.75)
	pattern(tr, 'drums', b0, '....X.......X...', lambda v: snare('rim' if e == 1 else 'crack', v * (.7 if e >= 2 else 1), rng), gain=.4)
	if e >= 2 and bar % 4 == 3:
		pattern(tr, 'drums', b0, '...........g.g.g', lambda v: snare('crack', v, rng), gain=.3)
	if e >= 3:
		pattern(tr, 'perc', b0, '..x...x...x...x.', lambda v: hat('shaker', v, rng), gain=.12)


def district_harmony(tr, b0, bar, chord, e):
	order = [0, 2, 4, 3, 1, 3, 2, 4]
	step = 1 if e >= 1 else 2
	for k in range(0, 8, step):
		i = order[k] % len(chord)
		tr.place('guitar', b0 + k * .5, eguitar(chord[i] + 12, tr.secs(1.1), .8 if k % 4 == 0 else .55, bar * 8 + k), .35, (i / 4 - .5) * .5, .003)
	if bar % 2 == 0:
		tr.place('keys', b0, pad(chord[:3], tr.secs(8), .7, 800, 1.4, .006), .25)


def district_bass(tr, b0, bar, chord, r, e, nxt):
	if e == 0:
		tr.place('bass', b0, bass808(r, tr.secs(3.6), .6), .5)
		return
	tr.place('bass', b0, bass808(r, tr.secs(1.6), .85), .5)
	tr.place('bass', b0 + 2.5, bass808(r if e < 2 else r + 7, tr.secs(1.2), .7), .5)


DISTRICT = dict(title='Спальный район', bpm=82, bpb=4, swing=.18, bars=16,
	chords=[[57, 60, 64, 67, 71], [53, 57, 60, 64], [50, 53, 57, 60, 64], [52, 56, 59, 62, 65]], roots=[33, 29, 26, 28],
	dark=[[50, 53, 57, 60, 64], [46, 50, 53, 57], [43, 46, 50, 53], [45, 49, 52, 55]], dark_roots=[26, 34, 31, 33],
	groove=district_groove, harmony=district_harmony, bass=district_bass, lead=bell, keys=None,
	motif=[(0, .5, 76), (.5, .5, 72), (1, 2, 71), (2.5, .5, 69), (3, 1, 72)],
	answer=[(0, .5, 76), (.5, .5, 79), (1, 2, 77), (2.5, .5, 76), (3, 1, 71)],
	vowel='oo', pump={'keys': .35})


# ============================================================ Помехи: broken downtempo + chops
def static_groove(tr, b0, bar, e, rng):
	if e == 0:
		pattern(tr, 'drums', b0, '..x...x...x...x.', lambda v: hat('closed', v, rng), gain=.08)
		return
	pattern(tr, 'drums', b0, 'X..x......X..x..' if bar % 2 == 0 else 'X......x..X.....', lambda v: kick('tight', v), gain=.75)
	pattern(tr, 'drums', b0, '....X.......X...' if e >= 2 else '....x.......x...', lambda v: snare('crack', v, rng), gain=.38)
	pattern(tr, 'drums', b0, 'x.xox.x.x.xox.x.' if e >= 2 else 'x...x...x...x...', lambda v: hat('closed', v, rng), gain=.14)
	if e >= 2 and bar % 4 == 3:  # glitch: stuttered hats and chops
		for k in range(8):
			tr.place('drums', b0 + 3 + k / 8, hat('closed', 1 - k * .08, rng), .18)
	if e >= 3:
		pattern(tr, 'perc', b0, '.......x.....x..', lambda v: perc_block(80, v), gain=.1)


def static_harmony(tr, b0, bar, chord, e):
	tr.place('keys', b0, pad(chord, tr.secs(4), .9, 1300, .3, .012), .3)
	if e >= 1:
		tones = [m + 12 for m in chord]
		cut = 1100 + 250 * (bar % 4)
		for k in range(16 if e >= 2 else 8):
			step = .25 if e >= 2 else .5
			if k % 3 != 2 or e >= 3:
				tr.place('guitar', b0 + k * step, square_lead(tones[(k * 2) % len(tones)], tr.secs(.18), .7, 0, cut), .1, .35 if k % 2 else -.35)
	if e >= 2 and bar % 4 == 3:
		for k in range(4):
			tr.place('perc', b0 + 3 + k * .25, vocal_chop(chord[-1] + 12, .12, .8, 'ah', k), .25, .2)


def static_bass(tr, b0, bar, chord, r, e, nxt):
	line = [(0, .7, r), (1.5, .5, r), (2.75, 1, r + 7)]
	if e == 0:
		line = [(0, 3.5, r)]
	for b, d, m in line:
		tr.place('bass', b0 + b, bass808(m, tr.secs(d), .85), .5)


STATIC = dict(title='Помехи', bpm=92, bpb=4, swing=.1, bars=16,
	chords=[[49, 52, 56, 59], [45, 52, 56, 61], [52, 56, 59, 64], [47, 51, 54, 56]], roots=[25, 33, 28, 35],
	dark=[[54, 57, 61, 64], [49, 52, 56], [50, 54, 57, 61], [44, 48, 51, 54]], dark_roots=[30, 25, 26, 32],
	groove=static_groove, harmony=static_harmony, bass=static_bass, lead=lambda m, d, v: vocal_chop(m, d + .15, v, 'ah', int(m)), keys=None,
	motif=[(0, .25, 68), (.5, .25, 68), (.75, .5, 71), (1.5, .5, 68), (2, .25, 66), (2.5, 1, 64)],
	answer=[(0, .25, 68), (.5, .25, 71), (.75, .5, 73), (1.5, .5, 71), (2, .25, 68), (2.5, 1, 66)],
	vowel='oo', pump={'keys': .55})

THEMES = {'neon': NEON, 'district': DISTRICT, 'static': STATIC}


def fanfare(th, kind, v):
	seconds = {'greeting': 3.6, 'start': 3.6, 'victory': 4.6, 'defeat': 5.0}[kind]
	tr = Track(th['bpm'] if th['bpm'] < 120 else th['bpm'] / 2, seconds * (th['bpm'] if th['bpm'] < 120 else th['bpm'] / 2) / 60, seed=seed_of(th['title'] + kind) + v)
	rng = tr.rng
	I, IV, V = th['chords'][0], th['chords'][2], th['chords'][3]
	r = th['roots'][0]
	top = max(I) + 12
	lead = lambda m, d, vv, g=None: glide_lead(m, d, vv, g, 1800)
	chime = th.get('chime', bell)
	if kind == 'greeting':
		tr.place('keys', 0, pad(I, tr.secs(3.2), .9, 1200, .8, .01), .5)
		for k, iv in enumerate([[-5, -3, 0], [0, -1, -5], [-5, 0, 2]][v]):
			tr.place('guitar', .5 + k * .5, chime(top + iv, tr.secs(1.5), .8), .35, (k - 1) * .3)
		tr.place('bass', .5, bass808(r, tr.secs(2.5), .7), .5)
	elif kind == 'start':
		n = round(tr.secs(1.5) * R)
		riser = filt(rng.uniform(-1, 1, n), 'band', [400, 3000]) * np.linspace(0, 1, n) ** 2
		tr.place('perc', 0, riser, .3)
		go = 1.5
		tr.place('drums', go, kick('808', 1), 1)
		tr.place('drums', go, snare('clap', 1, rng), .6)
		tr.place('bass', go, bass808(r, tr.secs(2.2), 1, r + [12, 7, 5][v]), .6)
		tr.place('keys', go, pad(I, tr.secs(2), 1, 1500, .02, .01), .5)
		tr.place('lead', go + .25, lead(top + [0, 2, -2][v], tr.secs(1.6), .9, top - 5), .35)
		for k in range(3):
			tr.place('perc', go + .5 + k * .25, vocal_chop(top - 12, .12, .8, 'ah', k), .3)
	elif kind == 'victory':
		for i, (ch, rr) in enumerate([(IV, th['roots'][2]), (V, th['roots'][3]), (I, r)]):
			hold = 2.8 if i == 2 else 1
			tr.place('keys', i, pad(ch, tr.secs(hold), 1, 1300, .05, .01), .5)
			tr.place('bass', i, bass808(rr, tr.secs(hold), .8), .5)
			tr.place('drums', i, kick('808', .9), .8)
		tr.place('drums', 2, snare('clap', 1, rng), .6)
		line = [[(0, .5, top - 5), (.5, .5, top - 3), (1, .5, top - 2), (2, 2.4, top)],
			[(0, .75, top - 3), (1, .75, top - 2), (2, 2.4, top + 2)],
			[(0, .5, top - 7), (1, .5, top - 3), (2, 2.4, top + 4)]][v]
		for b, d, m in line:
			tr.place('lead', b, lead(m, tr.secs(d), .85), .35)
		for k in range(4):
			tr.place('guitar', 2 + k * .5, chime(top + [0, -5, -3, 0][k] + 12 * (k == 3), tr.secs(1.2), .6), .3, (k - 1.5) * .3)
	else:
		drops = [[0, -2, -4, -7], [0, -1, -3, -5], [0, -3, -5, -12]][v]
		t0, prev = 0, None
		for i, iv in enumerate(drops):
			d = .8 + i * .3
			tr.place('lead', t0, lead(top - 12 + iv, tr.secs(d + .2), .8 - i * .12, prev), .35)
			prev = top - 12 + iv
			t0 += d
		tr.place('keys', 0, pad(I[:3], tr.secs(4), .8, 700, 1, .012), .5)
		tr.place('bass', 0, bass808(r, tr.secs(3.5), .8, r + 5), .5)
	for name in list(tr.buses):
		tr.buses[name] = reverb(tr.buses[name], .3, 2)
	out = np.zeros((tr.n, 2))
	for name, db in {'lead': -22, 'guitar': -24, 'bass': -25, 'drums': -22, 'keys': -25, 'perc': -28}.items():
		if name in tr.buses:
			out += tr.buses[name] * 10 ** (db / 20) / active_rms(tr.buses[name], 512)
	if kind == 'defeat':
		out = filt(out, 'low', 2000)
	out = tape(master(out, .045, .7, 1.1), .001, .5)
	k = np.arange(tr.n)
	return out * np.minimum(1, np.minimum(k / (R * .004), (tr.n - 1 - k) / (R * .7)))[:, None]


if __name__ == '__main__':
	DEMO.mkdir(parents=True, exist_ok=True)
	only = sys.argv[1:]
	index_path = OUT / 'themes.json'
	index = json.loads(index_path.read_text()) if index_path.exists() else {}
	catalog_path = OUT / 'chapter2_catalog.json'
	catalog = json.loads(catalog_path.read_text())
	for id, th in THEMES.items():
		if only and id not in only:
			continue
		entry = {'title': th['title'], 'mood': 'night'}
		reel = []
		gap = np.zeros((R // 2, 2))
		for mode in MODES:
			x, tr = render(th, mode)
			name = f'night_{id}_{mode}'
			info = save(OUT / (name + '.wav'), x)
			print(name, info)
			entry[mode] = name
			catalog[name] = {'title': th['title'] if mode == 'battle' else f"{th['title']} · {MODE_TITLES[mode]}", 'context': mode}
			n = R * (20 if mode == 'battle' else 12)
			k = np.arange(n)
			reel.extend([x[:n] * np.minimum(1, np.minimum(k / (R * .05), (n - 1 - k) / (R * .6)))[:, None] * 2.2, gap])
		for kind in KINDS:
			entry[kind] = []
			for v in range(3):
				name = f'night_{id}_{kind}_{v + 1}'
				save(OUT / (name + '.wav'), fanfare(th, kind, v))
				entry[kind].append(name)
				reel.extend([fanfare(th, kind, v), gap])
		index[id] = entry
		save(DEMO / f'{id}.wav', np.concatenate(reel))
	index_path.write_text(json.dumps(index, ensure_ascii=False, indent=2))
	catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2))
