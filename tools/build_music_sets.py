"""Two more theme sets on the shared render engine (build_music_folk.render).

day  — soft retro disco / synth-pop, homage to Cream Soda by texture only
       (four-on-the-floor, offbeat hats, octave bass, electric piano, warm
       pumping pads, dreamy synth leads). Files disco_*.
night — indie anthem rock with baroque colours, homage to Arcade Fire by
       texture only (marching floor toms, driving eighth bass, organ and
       strings, glockenspiel, piano, gang 'oh' choir, swells). Files anthem_*.
All melodies and progressions are original.

    python tools/build_music_sets.py              # both sets
    python tools/build_music_sets.py fountain     # one theme id
Preview: audio_demo/sets/<id>.wav
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
DEMO = ROOT / 'audio_demo/sets'


def glider(cutoff=2000):
	state = {'last': None}

	def play(m, d, v):
		prev = state['last']
		state['last'] = m
		return glide_lead(m, d, v, prev if prev is not None and abs(prev - m) <= 4 else None, cutoff)
	return play


def four_floor(tr, b0, bar, e, rng, clap='clap'):
	"""Shared disco kit: kick on every beat, offbeat open hat, clap on 2 and 4."""
	if e == 0:
		pattern(tr, 'perc', b0, 'x.o.x.o.x.o.x.o.', lambda v: hat('shaker', v, rng), gain=.1)
		return
	pattern(tr, 'drums', b0, 'X...X...X...X...' if e >= 2 else 'X.......X.......', lambda v: kick('round', v), gain=.72)
	pattern(tr, 'drums', b0, '..x...x...x...x.', lambda v: hat('open' if e >= 2 else 'closed', v * .6, rng), gain=.1 if e >= 2 else .12)
	if e >= 2:
		pattern(tr, 'drums', b0, '....X.......X...', lambda v: snare(clap, v * .8, rng), gain=.36)
		pattern(tr, 'perc', b0, 'x.xxx.xxx.xxx.xx', lambda v: hat('closed', v * .5, rng), gain=.08)
	if e >= 3 and bar % 4 == 3:
		pattern(tr, 'drums', b0 + 3, 'xxXX', lambda v: snare(clap, v, rng), gain=.3)


# ============================================================ day: Фонтан
def fountain_harmony(tr, b0, bar, chord, e):
	tr.place('keys', b0, strings(chord[1:], tr.secs(4), .7, .5, 2200), .22)
	hits = [(.5, .4, .7), (1.5, .4, .55), (2.5, .4, .7), (3.5, .4, .55)] if e >= 1 else [(0, 3.5, .5)]
	chord_hits(tr, 'guitar', b0, chord, hits, epiano, .09, .5)


def fountain_bass(tr, b0, bar, chord, r, e, nxt):
	if e == 0:
		tr.place('bass', b0, synth_bass(r, tr.secs(3.5), .6, .6), .5)
		return
	for k in range(8):
		m = r + (12 if k % 2 else 0)
		if e >= 2 or k % 2 == 0:
			tr.place('bass', b0 + k * .5, synth_bass(m, tr.secs(.4), .85 if k % 2 == 0 else .65), .5)


FOUNTAIN = dict(title='Фонтан', mood='day', bpm=114, bpb=4, swing=.04, bars=16,
	chords=[[57, 60, 64, 67, 71], [50, 53, 57, 60, 64], [55, 59, 62, 65, 69], [48, 52, 55, 59, 64]], roots=[33, 38, 31, 36],
	dark=[[57, 60, 64, 67], [53, 57, 60, 64], [52, 56, 59, 62], [57, 60, 64, 67]], dark_roots=[33, 29, 28, 33],
	groove=four_floor, harmony=fountain_harmony, bass=fountain_bass, lead=glider(2200),
	motif=[(0, .5, 76), (.5, .5, 79), (1, 1.5, 81), (3, .5, 79), (3.5, .5, 76), (4, 1, 74), (5, 2.5, 72)],
	answer=[(0, .5, 76), (.5, .5, 79), (1, 1.5, 83), (3, .5, 81), (3.5, .5, 79), (4, 1, 76), (5, 2.5, 79)],
	vowel='oo', pump={'keys': .45, 'guitar': .2, 'choir': .3}, pump_beats=[0, 1, 2, 3],
	chord_inst=lambda ch, d, v: strings(ch, d, v, .15), sparkle=epiano, bass_inst=synth_bass, kick_kind='round', clap='clap')


# ============================================================ day: Пломбир
def plombir_groove(tr, b0, bar, e, rng):
	four_floor(tr, b0, bar, e, rng)
	if e >= 1:
		pattern(tr, 'perc', b0, 'xoxoxoxoxoxoxoxo', lambda v: hat('shaker', v, rng), gain=.1, pan=-.3)


def plombir_harmony(tr, b0, bar, chord, e):
	if bar % 2 == 0:
		tr.place('keys', b0, pad(chord, tr.secs(8), .8, 1500, .8, .007), .2)
	if e >= 1:
		for i, ch in enumerate('.x.x..x..x.x..x.' if e >= 2 else '..x...x...x...x.'):
			if ch == 'x':
				tr.place('guitar', b0 + i * .25, chop(chord[1:], .12, .75, bar * 16 + i), .55, .25 if i % 2 else -.25, .002)
	else:
		chord_hits(tr, 'guitar', b0, chord, [(0, 3.5, .5)], epiano, .1)


def plombir_bass(tr, b0, bar, chord, r, e, nxt):
	line = [(0, .4, r), (.75, .25, r + 12), (1.5, .4, r), (2, .25, r + 12), (2.5, .4, r + 7), (3.25, .5, r + 12)]
	if e == 0:
		line = [(0, 3.5, r)]
	for b, d, m in line:
		tr.place('bass', b0 + b, synth_bass(m, tr.secs(d), .8, .8), .5)


PLOMBIR = dict(title='Пломбир', mood='day', bpm=108, bpb=4, swing=.1, bars=16,
	chords=[[53, 57, 60, 64, 67], [52, 55, 59, 62], [50, 53, 57, 60, 64], [46, 50, 53, 57, 60]], roots=[29, 28, 26, 34],
	dark=[[50, 53, 57, 60, 64], [46, 50, 53, 57], [43, 46, 50, 53, 57], [45, 49, 52, 55]], dark_roots=[26, 34, 31, 33],
	groove=plombir_groove, harmony=plombir_harmony, bass=plombir_bass, lead=vibes,
	motif=[(0, .5, 72), (.5, .5, 74), (1, 1, 76), (2.5, .5, 72), (3, 1, 69)],
	answer=[(0, .5, 72), (.5, .5, 74), (1, 1, 77), (2.5, .5, 76), (3, 1, 74)],
	vowel='ah', pump={'keys': .4},
	chord_inst=lambda ch, d, v: pad(ch, d, v, 1600, .1, .007), sparkle=vibes, bass_inst=synth_bass, kick_kind='round', clap='clap')


# ============================================================ day: Трамвай
def tram_harmony(tr, b0, bar, chord, e):
	tr.place('keys', b0, pad(chord, tr.secs(4), .9, 1800, .3, .01), .22)
	if e >= 1:
		tones = [m + 12 for m in chord]
		for k in range(16 if e >= 2 else 8):
			step = .25 if e >= 2 else .5
			tr.place('guitar', b0 + k * step, square_lead(tones[[0, 2, 1, 3, 2, 4, 3, 1][k % 8] % len(tones)], tr.secs(.16), .7, 0, 1600 + 150 * (bar % 4)), .08, .35 if k % 2 else -.35)


def tram_bass(tr, b0, bar, chord, r, e, nxt):
	if e == 0:
		tr.place('bass', b0, synth_bass(r, tr.secs(3.5), .6, .5), .5)
		return
	for k in range(8):
		tr.place('bass', b0 + k * .5, synth_bass(r if k < 6 or e < 2 else nxt, tr.secs(.35), .8 if k % 2 == 0 else .6, .7), .5)


TRAM = dict(title='Трамвай', mood='day', bpm=118, bpb=4, swing=0, bars=16,
	chords=[[52, 55, 59, 62, 66], [48, 52, 55, 59], [45, 48, 52, 55, 59], [47, 52, 54, 57]], roots=[28, 36, 33, 35],
	dark=[[45, 48, 52, 55], [41, 45, 48, 52], [52, 55, 59, 62], [47, 51, 54, 57]], dark_roots=[33, 29, 28, 35],
	groove=lambda tr, b0, bar, e, rng: four_floor(tr, b0, bar, e, rng, 'crack'), harmony=tram_harmony, bass=tram_bass, lead=glider(1900),
	motif=[(0, 1, 71), (1, .5, 74), (1.5, 1.5, 76), (4, .5, 74), (4.5, .5, 71), (5, 2.5, 69)],
	answer=[(0, 1, 71), (1, .5, 74), (1.5, 1.5, 78), (4, .5, 76), (4.5, .5, 74), (5, 2.5, 71)],
	vowel='oo', pump={'keys': .5, 'choir': .3},
	chord_inst=lambda ch, d, v: pad(ch, d, v, 1800, .08, .01), sparkle=lambda m, d, v: square_lead(m, d, v, 0, 1800), bass_inst=synth_bass, kick_kind='round', clap='crack')


# ============================================================ night: Колокольня (6/8)
def belfry_groove(tr, b0, bar, e, rng):
	if e == 0:
		pattern(tr, 'perc', b0, 'x.o.x.', lambda v: hat('shaker', v, rng), grid=.5, gain=.08)
		return
	for b in (0, 1.5):  # marching floor toms on each dotted beat
		tr.place('drums', b0 + b, tom(40, .9 if b == 0 else .7), .45, -.15)
	if e >= 2:
		tr.place('drums', b0, kick('round', .9), .6)
		tr.place('drums', b0 + 1.5, snare('crack', .8, rng), .38)
		pattern(tr, 'perc', b0, 'xoxoxo', lambda v: tambourine(v, rng, True), grid=.5, gain=.13, pan=.3)
	if e >= 3:
		pattern(tr, 'drums', b0, '..x..x', lambda v: tom(45, v * .6), grid=.5, gain=.35)
	if bar % 4 == 3 and e >= 2:
		for k, m in enumerate([50, 47, 43, 40]):
			tr.place('drums', b0 + 1 + k * .5, tom(m, .7), .35, (k - 1.5) * .3)


def belfry_harmony(tr, b0, bar, chord, e):
	if bar % 2 == 0:
		tr.place('guitar', b0, organ(chord[:3], tr.secs(6), .55), .25)
	if e >= 1:
		tr.place('keys', b0, strings(chord, tr.secs(3), .7, .4), .22)
	if e >= 2:
		for k, i in enumerate([0, 2, 3, 2, 3, 4]):
			tr.place('perc', b0 + k * .5, glock(chord[i % len(chord)] + 24, tr.secs(.6), .5), .12, (k / 5 - .5) * .6)


def belfry_bass(tr, b0, bar, chord, r, e, nxt):
	if e == 0:
		tr.place('bass', b0, upright(r, tr.secs(2.8), .6), .5)
		return
	for k in range(6):
		if e >= 2 or k in (0, 3):
			tr.place('bass', b0 + k * .5, fm_bass(r + (7 if k == 5 else 0), tr.secs(.42), .8 if k in (0, 3) else .6, 1.2), .45)


BELFRY = dict(title='Колокольня', mood='night', bpm=96, bpb=3, swing=0, bars=24,
	chords=[[50, 54, 57, 62], [47, 50, 54, 59], [43, 47, 50, 55], [45, 49, 52, 57]], roots=[38, 35, 31, 33],
	dark=[[47, 50, 54, 59], [43, 47, 50, 55], [45, 49, 52, 57], [42, 46, 49, 54]], dark_roots=[35, 31, 33, 30],
	groove=belfry_groove, harmony=belfry_harmony, bass=belfry_bass, lead=glock,
	motif=[(0, .5, 74), (.5, .5, 76), (1, 1, 78), (1.5, .5, 76), (3, 1.5, 74), (4.5, 1.5, 71)],
	answer=[(0, .5, 74), (.5, .5, 78), (1, 1, 81), (1.5, .5, 78), (3, 1.5, 76), (4.5, 1.5, 74)],
	vowel='oh',
	chord_inst=lambda ch, d, v: strings(ch, d, v, .2), sparkle=glock, bass_inst=lambda m, d, v: fm_bass(m, d, v, 1.2), kick_kind='round', clap='crack')


# ============================================================ night: Окраина
def outskirts_groove(tr, b0, bar, e, rng):
	pattern(tr, 'drums', b0, 'x.x.x.x.x.x.x.x.' if e else 'x...x...x...x...', lambda v: hat('closed', v * .6, rng), gain=.1)
	if e == 0:
		return
	pattern(tr, 'drums', b0, 'X...X...X...X...' if e >= 2 else 'X.......X.......', lambda v: kick('round', v), gain=.7)
	pattern(tr, 'drums', b0, '....X.......X...', lambda v: snare('crack', v * (.8 if e >= 2 else .5), rng), gain=.38)
	if e >= 2:
		pattern(tr, 'perc', b0, '..x...x...x...x.', lambda v: tambourine(v, rng), gain=.14, pan=-.3)
	if e >= 3:
		pattern(tr, 'drums', b0, 'x.x.x.x.x.x.x.x.', lambda v: tom(43, v * .5), gain=.25)


def outskirts_harmony(tr, b0, bar, chord, e):
	if e >= 1:
		for k in range(8 if e >= 2 else 4):
			step = .5 if e >= 2 else 1
			for m in chord[1:4]:
				tr.place('guitar', b0 + k * step, piano(m, tr.secs(.4), .5 if k % 2 else .7), .05, .1)
	else:
		chord_hits(tr, 'guitar', b0, chord, [(0, 3.5, .6)], piano, .08)
	if bar % 2 == 0:
		tr.place('keys', b0, strings(chord, tr.secs(8), .8, 1.2), .24)


def outskirts_bass(tr, b0, bar, chord, r, e, nxt):
	for k in range(8 if e >= 1 else 1):
		tr.place('bass', b0 + k * .5, fm_bass(r, tr.secs(.42 if e else 3.5), .8 if k % 2 == 0 else .65, 1.0), .45)


OUTSKIRTS = dict(title='Окраина', mood='night', bpm=112, bpb=4, swing=0, bars=16,
	chords=[[52, 56, 59, 64], [49, 52, 56, 61], [45, 49, 52, 57], [47, 51, 54, 59]], roots=[40, 37, 33, 35],
	dark=[[49, 52, 56, 61], [45, 49, 52, 57], [42, 45, 49, 54], [44, 48, 51, 56]], dark_roots=[37, 33, 30, 32],
	groove=outskirts_groove, harmony=outskirts_harmony, bass=outskirts_bass, lead=glider(2000),
	motif=[(0, 1, 76), (1, 1, 76), (2, .5, 78), (2.5, 1.5, 80), (4, 1, 78), (5, 3, 76)],
	answer=[(0, 1, 76), (1, 1, 78), (2, .5, 80), (2.5, 1.5, 83), (4, 1, 80), (5, 3, 78)],
	vowel='oh', pump={'keys': .25},
	chord_inst=lambda ch, d, v: strings(ch, d, v, .2), sparkle=piano, bass_inst=lambda m, d, v: fm_bass(m, d, v, 1.0), kick_kind='round', clap='crack')


# ============================================================ night: Маяки
def beacons_groove(tr, b0, bar, e, rng):
	if e == 0:
		pattern(tr, 'perc', b0, 'x.......x.......', lambda v: hat('shaker', v, rng), gain=.08)
		return
	pattern(tr, 'drums', b0, 'X.....x.X.......' if e >= 2 else 'X.......X.......', lambda v: tom(38, v), gain=.45)
	pattern(tr, 'drums', b0, '....X.......X...', lambda v: snare('crack' if e >= 2 else 'rim', v * .8, rng), gain=.36)
	if e >= 2:
		pattern(tr, 'drums', b0, 'X.......X.......', lambda v: kick('round', v), gain=.55)
		pattern(tr, 'perc', b0, 'x.x.x.x.x.x.x.x.', lambda v: hat('shaker', v, rng), gain=.1)
	if bar % 4 == 3 and e >= 2:
		pattern(tr, 'drums', b0 + 2, 'x.x.xxxx', lambda v: tom(45, v), grid=.25, gain=.35)


def beacons_harmony(tr, b0, bar, chord, e):
	tr.place('guitar', b0, reed(chord[:3], tr.secs(4), .6), .22)
	if e >= 1:
		tones = [m + 12 for m in chord]
		for k in range(8):
			tr.place('perc', b0 + k * .5, marimba(tones[[0, 1, 2, 3, 2, 1, 2, 0][k] % len(tones)], .3, .7 if k % 2 == 0 else .5), .14, np.sin(k) * .5)
	if e >= 2 and bar % 2 == 0:
		tr.place('keys', b0, strings(chord, tr.secs(8), .7, .8), .2)


def beacons_bass(tr, b0, bar, chord, r, e, nxt):
	line = [(0, 1.4, r), (1.5, .4, r), (2, 1.4, r + 7), (3.5, .4, nxt - 1 if nxt > r else nxt + 1)]
	phrase(tr, 'bass', b0, line if e >= 2 else [(0, 3.5, r)], upright, .5)


BEACONS = dict(title='Маяки', mood='night', bpm=100, bpb=4, swing=.08, bars=16,
	chords=[[50, 54, 57, 62], [43, 47, 50, 55], [47, 50, 54, 59], [45, 49, 52, 57]], roots=[38, 31, 35, 33],
	dark=[[47, 50, 54, 59], [43, 47, 50, 55], [45, 48, 52, 57], [42, 46, 49, 54]], dark_roots=[35, 31, 33, 30],
	groove=beacons_groove, harmony=beacons_harmony, bass=beacons_bass, lead=whistle,
	motif=[(0, .5, 74), (.5, .5, 73), (1, 1.5, 71), (3, 1, 69), (4, 1, 71), (5, 2.5, 74)],
	answer=[(0, .5, 74), (.5, .5, 76), (1, 1.5, 78), (3, 1, 76), (4, 1, 74), (5, 2.5, 71)],
	vowel='oh',
	chord_inst=lambda ch, d, v: reed(ch, d, v), sparkle=marimba, bass_inst=upright, kick_kind='round', clap='crack')

THEMES = {'fountain': FOUNTAIN, 'plombir': PLOMBIR, 'tram': TRAM, 'belfry': BELFRY, 'outskirts': OUTSKIRTS, 'beacons': BEACONS}
PREFIX = {'day': 'disco', 'night': 'anthem'}


def fanfare(th, kind, v):
	seconds = {'greeting': 3.6, 'start': 3.6, 'victory': 4.6, 'defeat': 5.0}[kind]
	bpm = th['bpm']
	tr = Track(bpm, seconds * bpm / 60, seed=seed_of(th['title'] + kind) + v)
	rng = tr.rng
	I, IV, V = th['chords'][0], th['chords'][2], th['chords'][3]
	r = th['roots'][0]
	top = max(I) + 12
	lead, sparkle, bass_inst, chord_inst = th['lead'], th['sparkle'], th['bass_inst'], th['chord_inst']
	if kind == 'greeting':
		tr.place('keys', 0, chord_inst(I, tr.secs(3), .8), .45)
		for k, iv in enumerate([[-5, -3, 0], [0, -1, -5], [-5, 0, 2]][v]):
			tr.place('guitar', .5 + k * .5, sparkle(top + iv, tr.secs(1.2), .8), .35, (k - 1) * .3)
		tr.place('bass', .5, bass_inst(r, tr.secs(2.4), .7), .5)
	elif kind == 'start':
		hits = [[0, .5, 1], [0, .5, 1, 1.5], [0, .25, .5, 1, 1.25]][v]
		for b in hits:
			tr.place('drums', b, snare(th['clap'], .9, rng), .5)
		go = hits[-1] + .5
		tr.place('drums', go, kick(th['kick_kind'], 1), 1)
		tr.place('drums', go, tom(40, 1), .5)
		tr.place('keys', go, chord_inst(I, tr.secs(2.2), 1), .5)
		tr.place('bass', go, bass_inst(r, tr.secs(2), .9), .5)
		tr.place('lead', go + .25, lead(top + [0, 2, 4][v], tr.secs(1.8), .9), .3)
		tr.place('choir', go, choir([m + 12 for m in I[-3:]], tr.secs(1.2), 1, 'oh', .05, v), .5)
	elif kind == 'victory':
		for i, (ch, rr) in enumerate([(IV, th['roots'][2]), (V, th['roots'][3]), (I, r)]):
			hold = 2.8 if i == 2 else 1
			tr.place('keys', i, chord_inst(ch, tr.secs(hold), .9), .45)
			tr.place('bass', i, bass_inst(rr, tr.secs(hold), .8), .5)
			tr.place('drums', i, kick(th['kick_kind'], .9), .8)
		tr.place('drums', 2, snare(th['clap'], 1, rng), .55)
		line = [[(0, .5, top - 5), (.5, .5, top - 3), (1, .5, top - 1), (2, 2.4, top)],
			[(0, .75, top - 3), (1, .75, top - 1), (2, 2.4, top + 2)],
			[(0, .5, top - 7), (1, .5, top - 3), (2, 2.4, top + 4)]][v]
		phrase(tr, 'lead', 0, line, lead, .3)
		tr.place('choir', 2, choir([m + 12 for m in I[-3:]], tr.secs(2.4), 1, 'oh', .2, v), .5)
		for k in range(4):
			tr.place('guitar', 2 + k * .25, sparkle(top + [0, 4, 7, 12][k], tr.secs(.8), .6), .25, (k - 1.5) * .3)
	else:
		drops = [[0, -2, -3, -7], [0, -1, -3, -5], [0, -3, -5, -12]][v]
		t0 = 0
		for i, iv in enumerate(drops):
			d = .8 + i * .3
			tr.place('lead', t0, lead(top - 12 + iv, tr.secs(d + .2), .8 - i * .12), .3)
			t0 += d
		minor = [I[0], I[0] + 3, I[0] + 7]
		tr.place('keys', 0, chord_inst(minor, tr.secs(4), .7), .45)
		tr.place('bass', 0, bass_inst(r, tr.secs(3.5), .8), .5)
	for name in list(tr.buses):
		tr.buses[name] = reverb(tr.buses[name], .3, 1.8)
	out = np.zeros((tr.n, 2))
	for name, db in {'lead': -22, 'guitar': -24, 'bass': -25, 'drums': -22, 'keys': -24, 'choir': -28}.items():
		if name in tr.buses:
			out += tr.buses[name] * 10 ** (db / 20) / active_rms(tr.buses[name], 512)
	if kind == 'defeat':
		out = filt(out, 'low', 2200)
	out = master(out, .047, .7, 1.1)
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
		prefix = PREFIX[th['mood']]
		entry = {'title': th['title'], 'mood': th['mood']}
		reel = []
		gap = np.zeros((R // 2, 2))
		for mode in MODES:
			x, tr = render(th, mode)
			name = f'{prefix}_{id}_{mode}'
			info = save(OUT / (name + '.wav'), x)
			print(name, info)
			entry[mode] = name
			catalog[name] = {'title': th['title'] if mode == 'battle' else f"{th['title']} · {MODE_TITLES[mode]}", 'context': mode}
			n = min(len(x), R * (20 if mode == 'battle' else 12))
			k = np.arange(n)
			reel.extend([x[:n] * np.minimum(1, np.minimum(k / (R * .05), (n - 1 - k) / (R * .6)))[:, None] * 2.2, gap])
		for kind in KINDS:
			entry[kind] = []
			for v in range(3):
				name = f'{prefix}_{id}_{kind}_{v + 1}'
				x = fanfare(th, kind, v)
				save(OUT / (name + '.wav'), x)
				entry[kind].append(name)
				reel.extend([x, gap])
		index[id] = entry
		save(DEMO / f'{id}.wav', np.concatenate(reel))
	index_path.write_text(json.dumps(index, ensure_ascii=False, indent=2))
	catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2))
