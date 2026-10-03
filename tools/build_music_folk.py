"""Music themes, concept v2: very rhythmic chill with an indie folk-soul vibe.

Homage by texture only (strummed acoustic grooves, stomps and claps, gang 'ooh'
backing, falsetto-like whistle leads, walking upright bass, sudden builds and
drops). All melodies and progressions here are original.

Each theme: battle, hub, map, miniboss, boss loops + greeting / start / victory /
defeat fanfares, three variants each.

    python tools/build_music_folk.py             # all themes
    python tools/build_music_folk.py halt        # one theme
Output: assets/audio/music/folk_<id>_*.wav, themes.json (replaced), catalog.
Preview: audio_demo/folk/<id>.wav
"""
from pathlib import Path
import json, sys
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent / 'audio'))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from synth_kit import *  # noqa: F401,F403
from build_music_breaks import pattern, chord_hits, phrase, mix, BUS_DB, active_rms

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/music'
DEMO = ROOT / 'audio_demo/folk'
BUS_DB.update({'guitar': -23, 'choir': -29, 'lead': -23, 'perc': -27, 'drums': -20, 'bass': -23, 'keys': -26})
MODES = {'battle': (1.0, 2), 'hub': (.8, 0), 'map': (.9, 1), 'miniboss': (1.06, 3), 'boss': (.97, 3)}
MODE_TITLES = {'battle': 'бой', 'hub': 'хаб', 'map': 'карта', 'miniboss': 'командир', 'boss': 'босс'}


def seed_of(s):
	return sum(ord(c) * (i + 5) for i, c in enumerate(s)) % 100000


# ============================================================ theme A: Полустанок
def halt_groove(tr, b0, bar, e, rng):
	pattern(tr, 'perc', b0, 'xoxoxoxoxoxoxoxo'[:16] if e >= 1 else 'x.o.x.o.x.o.x.o.', lambda v: hat('shaker', v, rng), gain=.22 if e else .12)
	if e >= 1:
		pattern(tr, 'drums', b0, 'X.......X.....' + ('x.' if bar % 2 else '..'), lambda v: stomp(v, rng), gain=.9)
	if e >= 2:
		pattern(tr, 'drums', b0, '....X.......X...', lambda v: snare('clap', v, rng), gain=.45)
		pattern(tr, 'perc', b0, '..x...x...x...x.', lambda v: tambourine(v, rng), gain=.16, pan=.35)
	if e >= 3:
		pattern(tr, 'drums', b0, '......x.......xx', lambda v: stomp(v, rng), gain=.6)
		pattern(tr, 'drums', b0, '.....g.......g..', lambda v: snare('clap', v, rng), gain=.3)
	if bar % 8 == 7 and e >= 2:
		for k in range(4):
			tr.place('drums', b0 + 3 + k * .25, snare('clap', .5 + k * .12, rng), .35)


def halt_harmony(tr, b0, bar, chord, e):
	if e == 0:
		tr.place('guitar', b0, strum(chord, tr.secs(3.5), .7, True, .02, .5, bar), .5)
		tr.place('guitar', b0 + 2.5, strum(chord[-4:], tr.secs(1.4), .35, False, .015, .5, bar), .5)
		return
	for b, down, v in [(0, True, 1), (1, True, .7), (1.5, False, .5), (2.5, False, .55), (3, True, .8), (3.5, False, .5)]:
		tr.place('guitar', b0 + b, strum(chord if down else chord[-4:], tr.secs(.9), v, down, .012, .45, bar * 7 + int(b * 2)), .5, .15 if down else -.15, .003)


def halt_bass(tr, b0, bar, chord, r, e, nxt):
	if e == 0:
		tr.place('bass', b0, upright(r, tr.secs(3.5), .7), .5)
		return
	line = [(0, .9, r), (1, .9, r + 7), (2, .9, r + 12 if bar % 2 else r + 7), (3, .45, r + 4), (3.5, .45, nxt - 1)]
	phrase(tr, 'bass', b0, line if e >= 2 else line[:2] + [(2, 1.8, r + 7)], upright, .5)


HALT = dict(title='Полустанок', bpm=96, bpb=4, swing=.2, bars=16,
	chords=[[43, 47, 50, 55, 59, 67], [40, 47, 52, 55, 59, 64], [48, 52, 55, 60, 64], [48, 51, 55, 60, 63]], roots=[31, 28, 36, 36],
	dark=[[40, 47, 52, 55, 59, 64], [48, 52, 55, 60, 64], [45, 52, 57, 60, 64], [47, 51, 54, 57, 63]], dark_roots=[28, 36, 33, 35],
	groove=halt_groove, harmony=halt_harmony, bass=halt_bass, lead=whistle, keys=lambda ms, d, v: organ(ms, d, v),
	motif=[(0, .5, 74), (.5, .5, 71), (1, 1, 74), (2, .5, 76), (2.5, 1.5, 74), (4.5, .5, 71), (5, .5, 72), (5.5, .5, 71), (6, 1.5, 67)],
	answer=[(0, .5, 74), (.5, .5, 76), (1, 1, 79), (2, .5, 78), (2.5, 1.5, 76), (4.5, .5, 74), (5, .5, 72), (5.5, .5, 71), (6, 1.5, 71)],
	vowel='oo')


# ============================================================ theme B: Светлячки (6/8)
def flies_groove(tr, b0, bar, e, rng):
	if e >= 1:
		tr.place('drums', b0, stomp(.9, rng), .9)
		tr.place('drums', b0 + 1.5, tom(45, .5 if e == 1 else .8), .35, -.2)
	if e >= 2:
		tr.place('drums', b0 + 1.5, snare('clap', .8, rng), .42)
		pattern(tr, 'perc', b0, 'xoxoxo', lambda v: tambourine(v, rng, True), grid=.5, gain=.16, pan=.3)
		if bar % 2:
			tr.place('drums', b0 + 2.5, stomp(.5, rng), .6)
	else:
		pattern(tr, 'perc', b0, 'x.o.x.', lambda v: hat('shaker', v, rng), grid=.5, gain=.12)
	if e >= 3:
		tr.place('drums', b0 + 1, stomp(.6, rng), .6)
		pattern(tr, 'drums', b0, '..g..g', lambda v: snare('rim', v, rng), grid=.5, gain=.3)
	if bar % 4 == 3 and e >= 2:
		for k, m in enumerate([50, 47, 43]):
			tr.place('drums', b0 + 1.5 + k * .5, tom(m, .7), .35, (k - 1) * .4)


def flies_harmony(tr, b0, bar, chord, e):
	order = [0, 2, 3, 4, 3, 2]
	for k, i in enumerate(order):
		tr.place('guitar', b0 + k * .5, pluck(chord[i % len(chord)], tr.secs(1.2), .8 if k in (0, 3) else .55, .5), .35, (i / 4 - .5) * .6, .002)
	if e >= 2:
		tr.place('guitar', b0, strum(chord, tr.secs(1.3), .8, True, .014, .5, bar), .35, .2)
		tr.place('guitar', b0 + 1.5, strum(chord[-4:], tr.secs(1.3), .55, False, .012, .5, bar + 3), .35, -.2)
	if e >= 1 and bar % 2 == 0:
		tr.place('keys', b0, organ(chord[1:4], tr.secs(5.8), .5), .25)


def flies_bass(tr, b0, bar, chord, r, e, nxt):
	line = [(0, 1.4, r), (1.5, .9, r + 7)] + ([(2.5, .45, nxt + 2 if nxt < r else nxt - 2)] if e >= 2 else [])
	phrase(tr, 'bass', b0, line if e else [(0, 2.8, r)], upright, .5)


FLIES = dict(title='Светлячки', bpm=90, bpb=3, swing=0, bars=24,
	chords=[[50, 57, 62, 65, 69], [46, 53, 58, 62, 65], [41, 48, 53, 57, 60, 65], [48, 52, 55, 60, 64]], roots=[38, 34, 41, 36],
	dark=[[43, 50, 55, 58, 62], [50, 57, 62, 65, 69], [45, 52, 55, 61, 64], [50, 57, 62, 65, 69]], dark_roots=[31, 38, 33, 38],
	groove=flies_groove, harmony=flies_harmony, bass=flies_bass, lead=whistle, keys=organ,
	motif=[(0, 1, 69), (1, .5, 70), (1.5, 1.5, 69), (3, .5, 65), (3.5, .5, 67), (4, 2, 62)],
	answer=[(0, 1, 72), (1, .5, 70), (1.5, 1.5, 69), (3, .5, 67), (3.5, .5, 65), (4, 2, 64)],
	vowel='ah')


# ============================================================ theme C: Кривая тропа
def path_groove(tr, b0, bar, e, rng):
	pattern(tr, 'drums', b0, 'xoxoxoxoxoxoxoxo' if e >= 2 else 'x.x.x.x.x.x.x.x.', lambda v: hat('closed', v, rng), gain=.18 if e else .1)
	if e == 0:
		pattern(tr, 'drums', b0, '....x.......x...', lambda v: snare('rim', v, rng), gain=.25)
		return
	pattern(tr, 'drums', b0, 'X..x..X...X..x..' if e >= 2 else 'X.........X.....', lambda v: kick('tight', v), gain=.8)
	pattern(tr, 'drums', b0, '....X..g.g..X..g' if e >= 2 else '....x.......x...', lambda v: snare('crack' if e >= 2 else 'rim', v, rng), gain=.45)
	if e >= 3:
		pattern(tr, 'drums', b0, '....X.......X...', lambda v: snare('clap', v, rng), gain=.3)
		pattern(tr, 'perc', b0, '..x...x...x...x.', lambda v: tambourine(v, rng), gain=.14, pan=-.3)
	if bar % 8 == 7 and e >= 2:
		pattern(tr, 'drums', b0 + 3, 'gxgX', lambda v: snare('crack', v, rng), gain=.4)


def path_harmony(tr, b0, bar, chord, e):
	if e == 0:
		chord_hits(tr, 'keys', b0, chord, [(0, 3.5, .6)], piano, .12)
		return
	for i, ch in enumerate('.x.x..x..x.x..x.'):
		if ch == 'x':
			tr.place('guitar', b0 + i * .25, chop(chord[1:], .12, .8 if i % 4 == 2 else .6, bar * 16 + i), .6, .25 if i % 2 else -.25, .002)
	if e >= 2:
		chord_hits(tr, 'keys', b0, chord, [(0, .6, .7), (2.75, .9, .55)], piano, .1)


def path_bass(tr, b0, bar, chord, r, e, nxt):
	line = [(0, .4, r), (.75, .25, r + 12), (1.5, .4, r + 7), (2.5, .25, r + 10), (2.75, .5, r + 12), (3.5, .4, r + 3)]
	phrase(tr, 'bass', b0, line if e >= 2 else [(0, 1.4, r), (2.5, 1, r + 7)], upright, .5)


PATH = dict(title='Кривая тропа', bpm=104, bpb=4, swing=.12, bars=16,
	chords=[[52, 55, 59, 62, 64], [45, 49, 55, 59, 64], [48, 52, 55, 59, 64], [47, 52, 54, 57, 64]], roots=[28, 33, 36, 35],
	dark=[[52, 55, 59, 62, 64], [48, 52, 55, 59, 64], [50, 54, 57, 62, 66], [47, 51, 54, 57, 63]], dark_roots=[28, 36, 38, 35],
	groove=path_groove, harmony=path_harmony, bass=path_bass, lead=whistle, keys=piano,
	motif=[(0, .25, 76), (.25, .25, 79), (.5, .75, 81), (1.5, .5, 79), (2, .5, 76), (3, 1, 74)],
	answer=[(0, .25, 76), (.25, .25, 79), (.5, .75, 83), (1.5, .5, 81), (2, .5, 79), (3, 1, 78)],
	vowel='oh')

THEMES = {'halt': HALT, 'fireflies': FLIES, 'crooked_path': PATH}


def render(th, mode):
	factor, base = MODES[mode]
	bpb, bars = th['bpb'], th['bars']
	tr = Track(round(th['bpm'] * factor, 2), bars * bpb, swing=th['swing'], seed=seed_of(th['title'] + mode))
	rng = tr.rng
	dark = mode == 'boss'
	chords = th['dark'] if dark else th['chords']
	roots = th['dark_roots'] if dark else th['roots']
	span = max(b + d for b, d, _ in th['motif'])
	motif_bars = max(1, int(np.ceil(span / bpb)))
	q = bars // 4
	for bar in range(bars):
		b0 = bar * bpb
		per = 2 if bars > 16 or mode == 'hub' else 1
		c = (bar // per) % 4
		chord, r = chords[c], roots[c]
		nxt = roots[((bar + 1) // per) % 4]
		# builds and drops inside the loop: lighter intro, full, a drop, full with fill
		if base == 0:
			e = 0
		elif bar < q:
			e = base - 1
		elif 3 * q <= bar < 3 * q + q // 2:
			e = max(base - 1, 1)
		else:
			e = base
		th['groove'](tr, b0, bar, e, rng)
		th['harmony'](tr, b0, bar, chord, e)
		th['bass'](tr, b0, bar, [m for m in chord], r, e, nxt)
		chorus = 2 * q <= bar < 3 * q
		every = motif_bars * (4 if mode == 'hub' else 2)
		if bar % every == 0 and (mode != 'hub' or bar % 8 == 4 or bar == 0):
			line = th['answer'] if chorus else th['motif']
			if dark:
				line = [(b, d * 1.1, m - 12) for b, d, m in line]
			phrase(tr, 'lead', b0, line, th['lead'], .3, .15)
		if th.get('vowel') and ((chorus and base >= 2) or (dark and bar % 2 == 0) or (mode == 'hub' and bar % 4 == 0)):
			voice = [m + 12 for m in chord[-3:]] if not dark else [m for m in chord[-3:]]
			tr.place('choir', b0, choir(voice, tr.secs(bpb * (2 if dark or mode == 'hub' else 1)), .8, th['vowel'], .3, bar), .5)
	downbeats = [b * bpb for b in range(bars)]
	for name, amt, secs in [('guitar', .16, 1.4), ('choir', .45, 3), ('lead', .3, 2.4), ('keys', .25, 2)]:
		if name in tr.buses:
			tr.buses[name] = reverb(tr.buses[name], amt, secs)
	if 'lead' in tr.buses:
		tr.buses['lead'] = delay(tr.buses['lead'], tr.secs(.75), .3, .25)
	if 'drums' in tr.buses:
		tr.buses['drums'] = reverb(tr.buses['drums'], .08, .9, 4000, 3)
	if 'guitar' in tr.buses and base >= 2 and 'pump' not in th:
		tr.buses['guitar'] = duck(tr.buses['guitar'], downbeats, tr, .2)
	# optional sidechain 'pump' of chosen buses on given beats of every bar
	for name, depth in th.get('pump', {}).items():
		if name in tr.buses and base >= 1:
			tr.buses[name] = duck(tr.buses[name], [b * bpb + o for b in range(bars) for o in th.get('pump_beats', [0])], tr, depth, .22)
	offsets = {'hub': {'guitar': 0, 'bass': -3, 'perc': -4, 'drums': -5, 'lead': -2, 'choir': 0, 'keys': 0},
		'map': {'guitar': 0, 'bass': -1, 'perc': -2, 'drums': -2, 'lead': 0, 'choir': 0, 'keys': -1},
		'battle': {'guitar': 0, 'bass': 0, 'perc': 0, 'drums': 0, 'lead': 0, 'choir': 0, 'keys': -1},
		'miniboss': {'guitar': 0, 'bass': 0, 'perc': 0, 'drums': 1, 'lead': 0, 'choir': 0, 'keys': -1},
		'boss': {'guitar': -1, 'bass': 1, 'perc': -1, 'drums': 1, 'lead': 0, 'choir': 2, 'keys': 0}}[mode]
	x = mix(tr, offsets, mode, vinyl(tr.n, .0015, seed_of(mode)) if mode in ('hub', 'map') else None)
	x = tape(x, .0008, .4)
	x[-64:] += np.linspace(0, 1, 64)[:, None] * (x[0] - x[-1])
	return x, tr


# ---------------------------------------------------------------- fanfares
def fanfare(th, kind, v):
	seconds = {'greeting': 3.4, 'start': 3.6, 'victory': 4.4, 'defeat': 4.8}[kind]
	bpm = th['bpm']
	tr = Track(bpm, seconds * bpm / 60, seed=seed_of(th['title'] + kind) + v)
	rng = tr.rng
	I, IV, V = th['chords'][0], th['chords'][2], th['chords'][3]
	r = th['roots'][0]
	top = I[-1]
	if kind == 'greeting':
		lines = [[(0, .5, top - 5), (.5, .5, top - 3), (1, 1.8, top)], [(0, .5, top), (.5, .5, top - 1), (1, 1.8, top - 5)], [(0, .25, top - 5), (.25, .75, top), (1, 1.8, top + 2)]]
		tr.place('guitar', .5, strum(I, tr.secs(3), .9, True, .02, .45, v), .5)
		phrase(tr, 'lead', .5, lines[v], th['lead'], .3)
		tr.place('choir', .9, choir([m + 12 for m in I[-3:]], tr.secs(2.2), .8, th['vowel'], .4, v), .5)
		tr.place('bass', .5, upright(r, tr.secs(2.5), .8), .5)
		tr.place('perc', 0, tambourine(.8, rng, True), .3)
	elif kind == 'start':
		hits = [[0, .5, 1], [0, .5, 1, 1.5], [0, .25, .5, 1, 1.25]][v]
		for k, b in enumerate(hits):
			tr.place('drums', b, stomp(.9, rng) if k % 2 == 0 else snare('clap', .9, rng), .8)
		go = hits[-1] + .5
		tr.place('drums', go, stomp(1, rng), 1)
		tr.place('drums', go, snare('clap', 1, rng), .6)
		tr.place('guitar', go, strum(I, tr.secs(2.4), 1, True, .01, .45, v + 9), .5)
		tr.place('choir', go, choir([m + 12 for m in I[-3:]], tr.secs(1.2), 1, 'ah', .05, v), .6)
		tr.place('bass', go, upright(r, tr.secs(2), .9), .5)
		tr.place('lead', go + .25, th['lead'](top + [0, 2, 4][v], tr.secs(1.8), .9, top - 5), .3)
	elif kind == 'victory':
		for i, (ch, rr) in enumerate([(IV, th['roots'][2]), (V, th['roots'][3]), (I, r)]):
			hold = 2.6 if i == 2 else .9
			tr.place('guitar', i, strum(ch, tr.secs(hold), .9, True, .012, .45, i + v), .5)
			tr.place('bass', i, upright(rr, tr.secs(hold), .8), .5)
			tr.place('drums', i, stomp(.9, rng), .8)
		tr.place('drums', 2, snare('clap', 1, rng), .6)
		tr.place('perc', 2, tambourine(1, rng, True), .35)
		lines = [[(0, .5, top - 5), (.5, .5, top - 3), (1, .5, top - 1), (1.5, .5, top), (2, 2.2, top + 2)],
			[(0, .75, top), (1, .5, top - 1), (1.5, .5, top), (2, 2.2, top + 4)],
			[(0, .5, top - 5), (1, .5, top + 2), (1.5, .5, top), (2, 2.2, top + 7)]][v]
		phrase(tr, 'lead', 0, lines, th['lead'], .3)
		tr.place('choir', 2, choir([m + 12 for m in I[-3:]], tr.secs(2.2), 1, 'ah', .2, v), .6)
	else:
		drops = [[0, -2, -3, -7], [0, -1, -3, -5], [0, -3, -5, -12]][v]
		t0 = 0
		for i, iv in enumerate(drops):
			d = .7 + i * .3
			tr.place('lead', t0, th['lead'](top + iv, tr.secs(d + .2), .8 - i * .12), .3)
			t0 += d
		minor = [I[0], I[0] + 7, I[0] + 12, I[0] + 15]
		tr.place('guitar', .2, strum(minor, tr.secs(3.2), .6, True, .03, .5, v), .5)
		tr.place('choir', .2, choir([m for m in minor[1:]], tr.secs(3), .7, 'oo', .6, v), .5)
		tr.place('bass', 0, upright(r, tr.secs(3.2), .8), .5)
		tr.place('drums', 0, stomp(.8, rng), .7)
	for name in list(tr.buses):
		tr.buses[name] = reverb(tr.buses[name], .25, 1.5)
	out = np.zeros((tr.n, 2))
	for name, db in {'lead': -22, 'guitar': -23, 'bass': -25, 'drums': -21, 'choir': -27, 'perc': -28}.items():
		if name in tr.buses:
			out += tr.buses[name] * 10 ** (db / 20) / active_rms(tr.buses[name], 512)
	if kind == 'defeat':
		out = filt(out, 'low', 2400)
	out = master(out, .05, .7, 1.1)
	k = np.arange(tr.n)
	return out * np.minimum(1, np.minimum(k / (R * .004), (tr.n - 1 - k) / (R * .6)))[:, None]


KINDS = ['greeting', 'start', 'victory', 'defeat']

if __name__ == '__main__':
	DEMO.mkdir(parents=True, exist_ok=True)
	only = sys.argv[1:]
	index_path = OUT / 'themes.json'
	index = json.loads(index_path.read_text()) if index_path.exists() else {}
	index = {k: v for k, v in index.items() if not str(v.get('battle', '')).startswith('folk_') or k in THEMES}
	catalog_path = OUT / 'chapter2_catalog.json'
	catalog = json.loads(catalog_path.read_text())
	for id, th in THEMES.items():
		if only and id not in only:
			continue
		entry = {'title': th['title'], 'mood': 'night' if id == 'halt' or id == 'fireflies' else 'day'}
		reel = []
		gap = np.zeros((R // 2, 2))
		for mode in MODES:
			x, tr = render(th, mode)
			name = f'folk_{id}_{mode}'
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
				name = f'folk_{id}_{kind}_{v + 1}'
				x = fanfare(th, kind, v)
				save(OUT / (name + '.wav'), x)
				entry[kind].append(name)
				reel.extend([x, gap])
		index[id] = entry
		save(DEMO / f'{id}.wav', np.concatenate(reel))
	index_path.write_text(json.dumps(index, ensure_ascii=False, indent=2))
	catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2))
