"""Third music pack: chill but rhythmic broken-beat loops, each in its own genre.

Run with a Python that has NumPy + SciPy:
    python tools/build_music_breaks.py            # all tracks + preview reel
    python tools/build_music_breaks.py azimuth    # one track
Output: assets/audio/music/<id>.wav, catalog entries in chapter2_catalog.json,
preview in audio_demo/breaks/.
"""
from pathlib import Path
import json, sys
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent / 'audio'))
from synth_kit import *  # noqa: F401,F403

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/music'
DEMO = ROOT / 'audio_demo/breaks'
LOUDNESS = {'hub': .026, 'map': .028, 'battle': .032, 'miniboss': .034, 'boss': .036}


def pattern(tr, bus, bar_start, steps, sig_fn, grid=.25, gain=1.0, pan=0.0, humanize=.003):
	"""steps: string like 'x..x..X.' — x normal, X accent, g ghost, '.' rest."""
	for i, ch in enumerate(steps):
		if ch == '.':
			continue
		v = {'x': .8, 'X': 1.0, 'g': .28, 'o': .55}[ch]
		tr.place(bus, bar_start + i * grid, sig_fn(v), gain, pan, humanize)


def chord_hits(tr, bus, bar_start, chord, hits, inst, gain, spread=.4):
	for b, d, v in hits:
		for k, m in enumerate(chord):
			tr.place(bus, bar_start + b + k * .006, inst(m, tr.secs(d), v), gain, (k / max(len(chord) - 1, 1) - .5) * spread, .002)


def phrase(tr, bus, bar_start, notes, inst, gain, pan=0.0):
	for b, d, m, *v in notes:
		tr.place(bus, bar_start + b, inst(m, tr.secs(d), v[0] if v else .9), gain, pan, .002)


# Target loudness of each part (dB RMS while it plays); mix gains are derived, not hand-set.
BUS_DB = {'drums': -20, 'snare': -26, 'bass': -23, 'keys': -24, 'stab': -25, 'skank': -26, 'mallet': -24,
	'pluck': -26, 'arp': -27, 'lead': -23, 'pad': -29,
	'perc': -27, 'clav': -25, 'guitar': -25, 'riff': -24}


def active_rms(x, block=2048):
	e = np.array([np.mean(x[i:i + block] ** 2) for i in range(0, len(x) - block, block)])
	on = e[e > e.max() * .02]
	return np.sqrt(on.mean()) if len(on) else 1e-9


def mix(tr, parts, context, extra=None):
	"""parts: bus name -> dB offset from its BUS_DB target."""
	out = np.zeros((tr.n, 2))
	for name, offset in parts.items():
		if name in tr.buses:
			target = 10 ** ((BUS_DB[name] + offset) / 20)
			out += tr.buses[name] * target / active_rms(tr.buses[name])
	if extra is not None:
		out += extra * np.sqrt(np.mean(out ** 2)) / .03
	return master(out, LOUDNESS[context], ceiling=.62, warmth=1.1)


# ============================================================ 1. Азимут — lo-fi boom-bap
def azimuth():
	bars, bpb = 16, 4
	tr = Track(84, bars * bpb, swing=.16, seed=101)
	chords = [[50, 53, 57, 60, 64], [43, 53, 57, 59, 64], [48, 52, 55, 59, 62], [45, 55, 57, 61, 64]]
	roots = [38, 31, 36, 33]
	rng = tr.rng
	for bar in range(bars):
		b0 = bar * bpb
		c = bar % 4
		chord_hits(tr, 'keys', b0, chords[c], [(0, 1.6, .75), (1.75, 1.9, .5)] if bar % 2 == 0 else [(0, 3.5, .7)], epiano, .11)
		kick_steps = 'X......x..x.....' if bar % 4 != 3 else 'X......x..x...x.'
		snare_steps = '....X..g....X..g' if bar % 2 else '....X.......X.g.'
		if bar in (7, 15):
			snare_steps = '....X.......Xgxg'
		if bar != 8:
			pattern(tr, 'drums', b0, kick_steps, lambda v: kick('round', v), gain=.9)
		pattern(tr, 'drums', b0, snare_steps, lambda v: snare('crack', v, rng), gain=.55)
		pattern(tr, 'drums', b0, 'x.o.x.o.x.o.x.oo', lambda v: hat('closed', v, rng), gain=.22)
		r = roots[c]
		bass = [(0, 1.4, r), (1.75, .5, r), (2.5, 1.2, r + (7 if c % 2 else 12))]
		if bar != 8:
			phrase(tr, 'bass', b0, bass, lambda m, d, v: sub(m, d, v, 1.8), .5)
		# kalimba answer in every second bar, different in second half
		if bar % 2 == 1:
			line = [(2.5, .5, 69), (3, .5, 72), (3.5, .75, 74)] if bar < 8 else [(2, .5, 76), (2.5, .5, 74), (3, 1, 72)]
			phrase(tr, 'lead', b0, line, kalimba, .14, .25)
	keys = reverb(tr.buses['keys'], .22, 1.6, 3500)
	tr.buses['keys'] = duck(keys, [b * 4 for b in range(bars)], tr, .35)
	tr.buses['lead'] = delay(tr.buses['lead'], tr.secs(.75), .4, .35)
	tr.buses['drums'] = reverb(tr.buses['drums'], .06, .6, 5000, 3)
	x = mix(tr, {'keys': 0, 'drums': 0, 'bass': 0, 'lead': 0}, 'battle', vinyl(tr.n, .003))
	return tape(x, .0012, .5), tr


# ============================================================ 2. Морзе — 5/4 downtempo
def morse():
	bars, bpb = 16, 5
	tr = Track(96, bars * bpb, swing=.08, seed=202)
	rng = tr.rng
	# F# dorian
	chords = [[54, 57, 61, 64], [52, 56, 59, 64], [50, 54, 57, 61], [52, 57, 59, 64]]
	roots = [42, 40, 38, 40]
	call = [(0, .25, 73), (.5, .25, 73), (1, .75, 76), (2.5, .25, 73), (3, .75, 71)]
	for bar in range(bars):
		b0 = bar * bpb
		c = (bar // 2) % 4
		# plucked arpeggio in 3+2 grouping
		arp = chords[c]
		for i, b in enumerate([0, .5, 1, 1.5, 2, 3, 3.5, 4, 4.5]):
			tr.place('pluck', b0 + b, pluck(arp[(i * 2) % len(arp)] + 12, .4, .55 if i % 3 else .8, .55), .18, .35 if i % 2 else -.35, .002)
		pattern(tr, 'drums', b0, 'X.........x...x.....', lambda v: kick('tight', v), gain=.85)
		pattern(tr, 'drums', b0, '......X.......g.X...' if bar % 4 != 3 else '......X.......g.Xgxg', lambda v: snare('rim', v, rng), gain=.4)
		pattern(tr, 'drums', b0, 'xoxoxoxoxoxoxoxoxoxo', lambda v: hat('shaker', v, rng), gain=.2)
		phrase(tr, 'bass', b0, [(0, 1.8, roots[c]), (2.5, .9, roots[c] + 7), (3.75, 1, roots[c] + 10)], lambda m, d, v: fm_bass(m, d, v, 1.2), .42)
		if bar % 4 in (0, 2):
			phrase(tr, 'lead', b0, call if bar < 8 or bar % 4 == 0 else [(b, d, m - (2 if i == 4 else 0)) for i, (b, d, m) in enumerate(call)], marimba, .2)
		if bar % 2 == 0:
			tr.place('pad', b0, pad(arp, tr.secs(bpb * 2), .9, 1100, 1.2), .2)
	tr.buses['pluck'] = delay(tr.buses['pluck'], tr.secs(.75), .3, .3)
	tr.buses['lead'] = reverb(delay(tr.buses['lead'], tr.secs(1.5), .35, .3), .25, 2.2)
	tr.buses['pad'] = duck(reverb(tr.buses['pad'], .3, 2.5), [b * 5 + o for b in range(bars) for o in (0, 2.5)], tr, .45)
	x = mix(tr, {'pluck': 0, 'drums': 0, 'bass': 0, 'lead': 0, 'pad': 0}, 'battle')
	return x, tr


# ============================================================ 3. Сухой лёд — soft 2-step
def dry_ice():
	bars, bpb = 24, 4
	tr = Track(124, bars * bpb, swing=.3, seed=303)
	rng = tr.rng
	chords = [[57, 60, 64, 67, 71], [53, 57, 60, 64], [50, 53, 57, 60, 64], [52, 55, 59, 62]]
	roots = [33, 29, 26, 28]
	for bar in range(bars):
		b0 = bar * bpb
		c = (bar // 2) % 4
		pattern(tr, 'drums', b0, 'X.........X.....' if bar % 2 == 0 else 'X......x..X.....', lambda v: kick('round', v), gain=.8)
		pattern(tr, 'drums', b0, '....X.......X...' if bar % 8 != 7 else '....X.......X.gx', lambda v: snare('clap', v, rng), gain=.42)
		pattern(tr, 'drums', b0, '..x...x.gox...x.', lambda v: hat('closed', v, rng), gain=.26)
		if bar % 4 == 3:
			tr.place('drums', b0 + 3.5, hat('open', .6, rng), .15, .3)
		# organ stabs on offbeats
		for b in ([.75, 2.5] if bar % 2 == 0 else [.75, 1.5, 3.25]):
			tr.place('stab', b0 + b, organ(chords[c], tr.secs(.35), .8), .1, 0)
		r = roots[c] + 12
		line = [(0, .5, r), (.75, .25, r + 12), (1.5, .5, r + 7), (2.5, .75, r), (3.5, .25, r + 10)]
		phrase(tr, 'bass', b0, line, lambda m, d, v: fm_bass(m, d, v, 2.4), .36)
		if 8 <= bar < 16 and bar % 2 == 0:
			phrase(tr, 'lead', b0, [(0, .5, 76), (.75, .5, 79), (1.5, 1, 81), (3, .5, 79)] if bar % 4 == 0 else [(0, .5, 76), (.75, .5, 74), (1.5, 1.5, 72)], vibes, .14, -.2)
		if bar % 4 == 0:
			tr.place('pad', b0, pad(chords[c][1:], tr.secs(8), .8, 900, 1.5), .16)
	tr.buses['stab'] = delay(tr.buses['stab'], tr.secs(.75), .45, .45, lp=2200)
	tr.buses['pad'] = duck(reverb(tr.buses['pad'], .3, 2.5), [b * 4 + o for b in range(bars) for o in (0, 2.5)], tr, .55)
	tr.buses['lead'] = reverb(tr.buses['lead'], .3, 2)
	x = mix(tr, {'drums': 0, 'stab': 0, 'bass': 0, 'lead': 0, 'pad': 0}, 'battle')
	return x, tr


# ============================================================ 4. Калейдоскоп — polyrhythm IDM-lite
def kaleidoscope():
	bars, bpb = 16, 4
	tr = Track(102, bars * bpb, seed=404)
	rng = tr.rng
	chords = [[52, 56, 59, 63], [49, 52, 56, 59], [45, 52, 56, 59, 61], [47, 51, 54, 56]]
	roots = [40, 37, 33, 35]
	for bar in range(bars):
		b0 = bar * bpb
		c = (bar // 2) % 4
		tones = [m + 12 for m in chords[c]] + [chords[c][1] + 24]
		# dotted-eighth arpeggio = 3 against 4, restarting every 2 bars
		for k in range(6):
			pos = (bar % 2) * 4 + k * .75 + (bar % 2) * .25
			if pos - (bar % 2) * 4 < 4:
				tr.place('mallet', b0 + pos - (bar % 2) * 4, marimba(tones[(k + bar) % len(tones)], .3, .8), .2, np.sin(k) * .5, .001)
		kick_steps = 'X..x......X...x.' if bar % 2 == 0 else 'X..x....X.....x.'
		pattern(tr, 'drums', b0, kick_steps, lambda v: kick('tight', v), gain=.85)
		pattern(tr, 'drums', b0, '....X.......X..g' if bar % 4 != 2 else '....X......gX...', lambda v: snare('crack', v, rng), gain=.45)
		pattern(tr, 'drums', b0, 'x.xox.x.x.xox.x.', lambda v: hat('closed', v, rng), gain=.22)
		if bar % 4 == 3:  # glitch stutter
			for k in range(8):
				tr.place('drums', b0 + 3 + k / 8, hat('closed', .9 - k * .08, rng), .25)
				tr.place('drums', b0 + 3.5 + k / 16, perc_block(84 - k, .5), .08)
		phrase(tr, 'bass', b0, [(0, .6, roots[c]), (.75, .4, roots[c] + 12), (2.5, 1, roots[c]), (3.5, .4, roots[c] + 7)], lambda m, d, v: sub(m, d, v, 2.2), .45)
		if bar % 2 == 0:
			tr.place('pad', b0, pad(chords[c], tr.secs(8), .9, 1600, .6, .01), .14)
		if bar >= 8:
			phrase(tr, 'lead', b0, [(1, .5, 83), (1.5, .5, 80), (2, .25, 78), (2.25, 1.25, 80)] if bar % 2 else [(0, 1.5, 76), (2, 1, 75)], kalimba, .12, .3)
	tr.buses['mallet'] = delay(tr.buses['mallet'], tr.secs(.5), .3, .25)
	tr.buses['pad'] = duck(reverb(tr.buses['pad'], .35, 2.8), [b * 4 for b in range(bars)], tr, .4)
	tr.buses['lead'] = reverb(tr.buses['lead'], .35, 2.2)
	x = mix(tr, {'mallet': 0, 'drums': 0, 'bass': 0, 'pad': 0, 'lead': 0}, 'battle')
	return x, tr


# ============================================================ 5. Пыльный тракт — dub one-drop
def dust_road():
	bars, bpb = 16, 4
	tr = Track(74, bars * bpb, swing=.12, seed=505)
	rng = tr.rng
	chords = [[55, 58, 62], [60, 63, 67], [55, 58, 62], [54, 57, 60, 62]]
	riffs = [[(0, .75, 31), (1, .5, 34), (1.5, .5, 38), (2.5, 1, 31), (3.5, .5, 29)],
			[(0, .75, 36), (1, .5, 39), (1.5, .5, 43), (2.5, 1, 36), (3.5, .5, 38)],
			[(0, .75, 31), (1, .5, 34), (1.5, .5, 38), (2.5, .5, 41), (3, 1, 38)],
			[(0, .75, 38), (1, .5, 42), (1.5, .5, 45), (2.5, 1, 38), (3.5, .5, 37)]]
	for bar in range(bars):
		b0 = bar * bpb
		c = bar % 4
		pattern(tr, 'drums', b0, '........X.......', lambda v: kick('deep', v), gain=.9)
		pattern(tr, 'drums', b0, '........X.......' if bar % 4 != 3 else '........X...x.xx', lambda v: snare('rim', v, rng), gain=.45)
		pattern(tr, 'drums', b0, 'x.gxx.gxx.gxx.gx', lambda v: hat('closed', v, rng), gain=.18)
		for b in (.5, 1.5, 2.5, 3.5):
			tr.place('skank', b0 + b, organ(chords[c], tr.secs(.18), .8), .12, .25)
		phrase(tr, 'bass', b0, riffs[c], lambda m, d, v: sub(m, d, v, 1.4), .6)
		if bar % 4 == 1 or (bar >= 8 and bar % 4 == 3):
			phrase(tr, 'lead', b0, [(0, 1, 74), (1.5, .5, 72), (2, 1.5, 70)] if bar % 4 == 1 else [(.5, .5, 67), (1, .5, 70), (1.5, 2, 69)], lambda m, d, v: square_lead(m, d, v, .006, 1800), .06, -.3)
	tr.buses['skank'] = delay(tr.buses['skank'], tr.secs(.75), .55, .5, lp=1800)
	tr.buses['lead'] = reverb(delay(tr.buses['lead'], tr.secs(1.5), .5, .4, lp=1500), .3, 2.5)
	tr.buses['drums'] = reverb(tr.buses['drums'], .12, 1.2, 3000)
	x = mix(tr, {'drums': 0, 'skank': 0, 'bass': 2, 'lead': -3}, 'map', vinyl(tr.n, .002, 9))
	return x, tr


# ============================================================ 6. Квартет — jazz-hop in triplets
def quartet():
	bars, bpb = 16, 4
	tr = Track(70, bars * bpb, seed=606)
	rng = tr.rng
	chords = [[58, 62, 65, 69], [55, 58, 62, 65], [51, 55, 58, 62], [53, 57, 60, 63]]
	walk = [[34, 38, 41, 43], [31, 34, 38, 36], [27, 31, 34, 33], [29, 33, 36, 35]]
	for bar in range(bars):
		b0 = bar * bpb
		c = bar % 4
		for beat in range(4):
			tr.place('drums', b0 + beat, hat('ride', .55 if beat % 2 else .45, rng), .14, .35, .002)
			if beat % 2 == 1:
				tr.place('drums', b0 + beat + 2 / 3, hat('ride', .3, rng), .12, .35, .002)
		pattern(tr, 'drums', b0, 'X.....x..x..', lambda v: kick('round', v), grid=1 / 3, gain=.7)
		pattern(tr, 'drums', b0, '...X..g..X.g' if bar % 4 != 3 else '...X..g..Xgx', lambda v: snare('brush', v, rng), grid=1 / 3, gain=.4)
		phrase(tr, 'bass', b0, [(i, .9, m) for i, m in enumerate(walk[c])], pluck, .5)
		chord_hits(tr, 'keys', b0, chords[c], [(0, 1.2, .6), (2 + 2 / 3, 1.2, .45)], vibes, .075, .6)
		if bar % 2 == 1:
			phrase(tr, 'lead', b0, [(0, 1 / 3, 77), (1 / 3, 1 / 3, 74), (2 / 3, 1, 72), (2, 1 / 3, 70), (2 + 1 / 3, 1.5, 69)] if bar < 8 else
				[(1, 1 / 3, 74), (1 + 2 / 3, 1 / 3, 77), (2, 2, 79)], epiano, .1, -.2)
	tr.buses['keys'] = reverb(tr.buses['keys'], .3, 2)
	tr.buses['lead'] = reverb(tr.buses['lead'], .25, 1.8)
	tr.buses['bass'] = filt(tr.buses['bass'], 'low', 900)
	x = mix(tr, {'drums': 0, 'bass': -2, 'keys': 0, 'lead': 0}, 'hub', vinyl(tr.n, .0025, 12))
	return tape(x, .001, .4), tr


# ============================================================ 7. Трасса — chopped breakbeat
def highway():
	bars, bpb = 16, 4
	tr = Track(112, bars * bpb, swing=.06, seed=707)
	rng = tr.rng
	chords = [[50, 53, 57, 62], [46, 50, 53, 57], [48, 52, 55, 60], [45, 49, 52, 57]]
	roots = [26, 34, 36, 33]
	breaks = ['X.X.....X.X..X..', 'X.X...x.......X.', 'X.X.....X.X...X.', 'X.....X...X.X...']
	snares = ['....X..X.X..X..X', '....X..X.X..X...', '....X..X.X..X..X', '....X.g..gX.Xgxg']
	for bar in range(bars):
		b0 = bar * bpb
		c = (bar // 2) % 4
		v = bar % 4
		if bar not in (6, 7):
			pattern(tr, 'drums', b0, breaks[v], lambda v: kick('tight', v), gain=.8)
		pattern(tr, 'drums', b0, snares[v], lambda v: snare('crack', v, rng), gain=.42)
		pattern(tr, 'drums', b0, 'xoxoxoxoxoxoxoxo', lambda v: hat('closed', v, rng), gain=.18)
		if bar % 8 == 7:
			tr.place('drums', b0 + 3, tom(50, .7), .3, -.3)
			tr.place('drums', b0 + 3.5, tom(45, .7), .3, .3)
		phrase(tr, 'bass', b0, [(0, 3.5, roots[c])], lambda m, d, v: sub(m, d, v, 2.5), .48)
		if bar % 2 == 0:
			tr.place('pad', b0, pad(chords[c], tr.secs(8), .9, 1300, .4, .008), .18)
		arp = [m + 12 for m in chords[c]]
		for k in range(8):
			if bar >= 4 and (k % 3 != 2 or bar >= 8):
				tr.place('arp', b0 + k * .5, square_lead(arp[(k * 3) % 4], tr.secs(.3), .7 if k % 2 else .9, 0, 1500 + 200 * (bar % 4)), .045, .4 if k % 2 else -.4)
	tr.buses['arp'] = delay(tr.buses['arp'], tr.secs(.75), .4, .35)
	tr.buses['pad'] = duck(reverb(tr.buses['pad'], .3, 2.2), [b * 4 + o for b in range(bars) for o in (0, 2.5)], tr, .5)
	x = mix(tr, {'drums': 0, 'bass': 0, 'pad': 0, 'arp': 0}, 'miniboss')
	return x, tr


# ============================================================ 8. Гроза — dark trip-hop
def storm():
	bars, bpb = 16, 4
	tr = Track(76, bars * bpb, swing=.1, seed=808)
	rng = tr.rng
	chords = [[52, 55, 59], [53, 57, 60], [52, 55, 59, 62], [50, 53, 57, 60]]
	roots = [28, 29, 28, 26]
	for bar in range(bars):
		b0 = bar * bpb
		c = bar % 4
		pattern(tr, 'drums', b0, 'X.....X...X.....' if bar % 2 == 0 else 'X.....X.X.......', lambda v: kick('deep', v), gain=1)
		pattern(tr, 'snare', b0, '....X.......X...' if bar % 4 != 3 else '....X.......X.gX', lambda v: snare('crack', v, rng), gain=.55)
		pattern(tr, 'drums', b0, 'x.x.x.xgx.x.x.xg', lambda v: hat('closed', v, rng), gain=.17)
		phrase(tr, 'bass', b0, [(0, 1.4, roots[c]), (1.5, .4, roots[c] + 12), (2.5, 1.4, roots[c] + (1 if c == 0 else 0))], lambda m, d, v: sub(m, d, v, 3.0), .55)
		tr.place('pad', b0, pad(chords[c], tr.secs(4), .9, 700, 1.0, .012), .22)
		for k, b in enumerate([0, .75, 1.5, 2.5, 3, 3.5]):
			tr.place('pluck', b0 + b, pluck(chords[c][k % len(chords[c])] + 12, .5, .6, .7), .15, (k % 3 - 1) * .5)
		if bar >= 8 and bar % 2 == 0:
			phrase(tr, 'lead', b0, [(0, 1.5, 71), (1.5, .5, 72), (2, 2, 71)] if bar % 4 == 0 else [(0, 1, 76), (1, .5, 74), (1.5, 2.5, 72)], lambda m, d, v: square_lead(m, d, v, .008, 1200), .05)
	tr.buses['snare'] = reverb(tr.buses['snare'], .5, 2.4, 3000)
	tr.buses['pluck'] = delay(tr.buses['pluck'], tr.secs(.75), .45, .35, lp=2000)
	tr.buses['pad'] = duck(reverb(tr.buses['pad'], .35, 3), [b * 4 + o for b in range(bars) for o in (0, 1.5, 2.5)], tr, .5)
	tr.buses['lead'] = reverb(tr.buses['lead'], .4, 3)
	x = mix(tr, {'drums': 1, 'snare': 1, 'bass': 1, 'pad': 0, 'pluck': 0, 'lead': 0}, 'boss', vinyl(tr.n, .002, 13))
	return x, tr


# ============================================================ 9. Квадрат — funk breaks
def square_funk():
	bars, bpb = 16, 4
	tr = Track(98, bars * bpb, swing=.14, seed=909)
	rng = tr.rng
	chords = [[52, 55, 59, 62], [57, 61, 64, 67], [52, 55, 59, 62], [54, 57, 60, 64]]
	roots = [28, 33, 28, 30]
	clav_rhythm = [(0, .2), (.75, .15), (1.25, .2), (2, .15), (2.5, .2), (3.25, .15), (3.5, .2)]
	for bar in range(bars):
		b0 = bar * bpb
		c = bar % 4
		pattern(tr, 'drums', b0, 'X.x....x..X..x..' if bar % 2 == 0 else 'X.x....x..X.....', lambda v: kick('tight', v), gain=.85)
		pattern(tr, 'drums', b0, '....X..g.g..X..g' if bar % 4 != 3 else '....X..g.g..Xgxg', lambda v: snare('crack', v, rng), gain=.45)
		pattern(tr, 'drums', b0, 'xoXoxoXoxoXoxoXo', lambda v: hat('closed', v, rng), gain=.2)
		for b, d in clav_rhythm:
			if bar % 8 < 6 or b < 2:
				chord_hits(tr, 'clav', b0, chords[c][1:], [(b, d, .8 if b % 1 == 0 else .6)], clav, .1, .3)
		r = roots[c]
		phrase(tr, 'bass', b0, [(0, .4, r), (.5, .2, r + 12), (.75, .2, r), (1.5, .4, r + 7), (2.25, .2, r + 10), (2.5, .5, r + 12), (3.5, .3, r + 3)], lambda m, d, v: fm_bass(m, d, v, 3), .4)
		if bar >= 8 and bar % 2 == 0:
			phrase(tr, 'lead', b0, [(0, .25, 74), (.5, .25, 76), (.75, .75, 79), (2, .5, 76), (2.75, 1, 74)], epiano, .12)
	tr.buses['clav'] = reverb(tr.buses['clav'], .12, 1)
	tr.buses['lead'] = reverb(delay(tr.buses['lead'], tr.secs(.75), .3, .3), .2, 1.5)
	return mix(tr, {'drums': 0, 'clav': 0, 'bass': 0, 'lead': 0}, 'battle'), tr


# ============================================================ 11. Ртуть — 7/8 mallets
def mercury():
	bars, bpb = 20, 3.5
	tr = Track(104, bars * bpb, seed=1111)
	rng = tr.rng
	chords = [[47, 50, 54, 57], [45, 48, 52, 55], [43, 47, 50, 54], [45, 49, 52, 57]]
	for bar in range(bars):
		b0 = bar * bpb
		c = (bar // 2) % 4
		tones = [m + 12 for m in chords[c]]
		# 2+2+3 eighths
		for i, (b, deg) in enumerate([(0, 0), (.5, 2), (1, 1), (1.5, 3), (2, 0), (2.5, 2), (3, 3)]):
			tr.place('mallet', b0 + b, marimba(tones[deg] + (12 if i in (4,) and bar % 2 else 0), .3, .9 if b in (0, 1, 2) else .6), .2, (i / 6 - .5) * .7, .001)
		pattern(tr, 'drums', b0, 'X...X...x.....', lambda v: kick('round', v), gain=.8)
		pattern(tr, 'drums', b0, '..g...g.X...g.' if bar % 4 != 3 else '..g...g.X.gxgx', lambda v: snare('rim', v, rng), gain=.42)
		pattern(tr, 'drums', b0, 'x.o.x.o.x.o.o.', lambda v: hat('closed', v, rng), gain=.2)
		r = chords[c][0] - 12
		phrase(tr, 'bass', b0, [(0, .9, r), (1, .9, r + 7), (2, 1.4, r + 12 if bar % 2 else r + 5)], lambda m, d, v: sub(m, d, v, 1.6), .45)
		if bar % 4 == 1:
			phrase(tr, 'lead', b0, [(0, 1, 78), (1, .5, 76), (1.5, 2, 74)] if bar < 10 else [(0, .5, 81), (.5, .5, 78), (1, 2.5, 76)], vibes, .12, -.2)
		if bar % 2 == 0:
			tr.place('pad', b0, pad(chords[c], tr.secs(7), .8, 1200, 1), .14)
	tr.buses['mallet'] = delay(tr.buses['mallet'], tr.secs(1), .25, .2)
	tr.buses['lead'] = reverb(tr.buses['lead'], .3, 2)
	tr.buses['pad'] = reverb(tr.buses['pad'], .3, 2.5)
	return mix(tr, {'mallet': 0, 'drums': 0, 'bass': 0, 'lead': 0, 'pad': 0}, 'battle'), tr


# ============================================================ 12. Кочевник — afro broken beat
def nomad():
	bars, bpb = 16, 4
	tr = Track(108, bars * bpb, swing=.1, seed=1212)
	rng = tr.rng
	chords = [[57, 61, 64, 67], [55, 59, 62, 67], [57, 61, 64, 67], [52, 55, 59, 62]]
	ostinato = [(0, 69), (.5, 76), (.75, 73), (1.5, 76), (2, 69), (2.75, 74), (3.25, 73), (3.5, 71)]
	for bar in range(bars):
		b0 = bar * bpb
		c = bar % 4
		pattern(tr, 'drums', b0, 'X.....X...X.....', lambda v: kick('round', v), gain=.8)
		pattern(tr, 'drums', b0, '....X.......X...' if bar % 2 == 0 else '....X.....g.X...', lambda v: snare('rim', v, rng), gain=.35)
		pattern(tr, 'drums', b0, 'xoxoxoxoxoxoxoxo', lambda v: hat('shaker', v, rng), gain=.22)
		for b, m, slap in [(0, 62, False), (.75, 67, True), (1.5, 62, False), (2, 62, False), (2.5, 67, True), (3.25, 69, False), (3.5, 67, True)]:
			tr.place('perc', b0 + b, conga(m, .8, slap, rng), .3, .4 if m > 64 else -.3, .004)
		for b, m in ostinato:
			shift = (chords[c][0] - 57)
			tr.place('mallet', b0 + b, kalimba(m + shift, .3, .8), .2, .2, .002)
		r = chords[c][0] - 24
		phrase(tr, 'bass', b0, [(0, .5, r), (.75, .25, r + 12), (1.5, .5, r + 7), (2.5, .5, r + 10), (3, .75, r + 7)], lambda m, d, v: sub(m, d, v, 1.8), .45)
		if bar >= 8 and bar % 2:
			phrase(tr, 'lead', b0, [(0, .5, 81), (.5, 1, 79), (2, .5, 76), (2.5, 1.5, 78)], lambda m, d, v: square_lead(m, d, v, .006, 1800), .05)
	tr.buses['mallet'] = delay(tr.buses['mallet'], tr.secs(.75), .3, .25)
	tr.buses['perc'] = reverb(tr.buses['perc'], .12, .8)
	tr.buses['lead'] = reverb(tr.buses['lead'], .3, 2)
	return mix(tr, {'drums': 0, 'perc': 0, 'mallet': 0, 'bass': 0, 'lead': -1}, 'battle'), tr


# ============================================================ 13. Попутный ветер — lofi bossa
def tailwind():
	bars, bpb = 16, 4
	tr = Track(82, bars * bpb, swing=.1, seed=1313)
	rng = tr.rng
	chords = [[53, 57, 60, 64], [55, 58, 62, 65], [52, 55, 58, 62], [57, 60, 64, 67]]
	roots = [41, 43, 36, 45]
	comp = [(0, .4), (.75, .4), (1.5, .5), (2.5, .4), (3.25, .5)]
	for bar in range(bars):
		b0 = bar * bpb
		c = bar % 4
		pattern(tr, 'drums', b0, 'X......xX.......', lambda v: kick('round', v), gain=.6)
		pattern(tr, 'drums', b0, 'x..x..x...x..x..', lambda v: snare('rim', v, rng), gain=.28)
		pattern(tr, 'drums', b0, 'xoxoxoxoxoxoxoxo', lambda v: hat('shaker', v, rng), gain=.16)
		for b, d in comp:
			for k, m in enumerate(chords[c]):
				tr.place('guitar', b0 + b + k * .012, pluck(m, tr.secs(d), .7, .65, rng), .2, (k - 1.5) * .2)
		phrase(tr, 'bass', b0, [(0, 1.3, roots[c]), (1.5, .4, roots[c] + 7), (2, 1.3, roots[c] - 5 if roots[c] > 40 else roots[c] + 7), (3.5, .4, roots[c])], lambda m, d, v: sub(m, d, v, 1.2), .45)
		if bar % 2 == 0:
			phrase(tr, 'lead', b0, [(0, .75, 72), (1, .5, 69), (1.5, 1, 67), (3, .5, 69)] if bar % 4 == 0 else [(.5, .5, 74), (1, .5, 72), (1.5, 1.5, 70), (3.5, .5, 69)], epiano, .1, .2)
	tr.buses['guitar'] = reverb(tr.buses['guitar'], .2, 1.5)
	tr.buses['lead'] = reverb(tr.buses['lead'], .3, 2)
	x = mix(tr, {'drums': 0, 'guitar': 0, 'bass': 0, 'lead': 0}, 'map', vinyl(tr.n, .0022, 14))
	return tape(x, .0012, .5), tr


# ============================================================ 14. Ориентир — ambient breaks
def landmark():
	bars, bpb = 16, 4
	tr = Track(88, bars * bpb, swing=.12, seed=1414)
	rng = tr.rng
	chords = [[50, 54, 57, 61, 64], [52, 56, 59, 62], [47, 50, 54, 57], [55, 59, 62, 66]]
	for bar in range(bars):
		b0 = bar * bpb
		c = (bar // 2) % 4
		if bar % 8 >= 2:
			pattern(tr, 'drums', b0, 'X.....x...X.....', lambda v: kick('round', v), gain=.6)
			pattern(tr, 'drums', b0, '....X..g....X...', lambda v: snare('brush', v, rng), gain=.4)
		pattern(tr, 'drums', b0, 'x.x.x.x.x.x.x.x.', lambda v: hat('closed', v * .7, rng), gain=.16)
		if bar % 2 == 0:
			tr.place('pad', b0, pad(chords[c], tr.secs(8), .9, 1500, 1.5, .009), .22)
		tones = [m + 12 for m in chords[c]]
		for k in range(8):
			tr.place('mallet', b0 + k * .5, vibes(tones[(k * 2 + bar) % len(tones)], .4, .55 + .3 * (k % 2 == 0)), .15, np.sin(k * 1.3) * .6)
		phrase(tr, 'bass', b0, [(0, 3.5, chords[c][0] - 12)], lambda m, d, v: sub(m, d, v, 1.1), .4)
	tr.buses['mallet'] = reverb(delay(tr.buses['mallet'], tr.secs(.75), .4, .35), .3, 2.5)
	tr.buses['pad'] = reverb(tr.buses['pad'], .5, 3.5)
	return mix(tr, {'drums': -2, 'mallet': 0, 'pad': 2, 'bass': 0}, 'map'), tr


# ============================================================ 15. Самовар — lofi waltz
def samovar():
	bars, bpb = 24, 3
	tr = Track(84, bars * bpb, swing=.18, seed=1515)
	rng = tr.rng
	chords = [[55, 59, 62, 66], [52, 55, 59, 62], [48, 52, 55, 59], [50, 54, 57, 60]]
	roots = [31, 28, 36, 38]
	for bar in range(bars):
		b0 = bar * bpb
		c = (bar // 2) % 4
		pattern(tr, 'drums', b0, 'X.......x...' if bar % 2 == 0 else 'X.....x.....', lambda v: kick('round', v), gain=.6)
		pattern(tr, 'drums', b0, '....X...X..g', lambda v: snare('brush', v, rng), gain=.35)
		pattern(tr, 'drums', b0, 'x.o.x.o.x.oo', lambda v: hat('closed', v, rng), gain=.14)
		phrase(tr, 'bass', b0, [(0, 1.8, roots[c])], lambda m, d, v: sub(m, d, v, 1.2), .4)
		chord_hits(tr, 'keys', b0, chords[c], [(1, .8, .5), (2, .8, .45)], epiano, .08, .5)
		if bar % 4 in (0, 1):
			line = [[(0, 1, 74), (1, .5, 76), (1.5, 1.5, 79)], [(0, 1.5, 78), (1.5, .5, 76), (2, 1, 74)]][bar % 2]
			if bar >= 12:
				line = [(b, d, m + (2 if i == 1 else 0)) for i, (b, d, m) in enumerate(line)]
			phrase(tr, 'lead', b0, line, kalimba, .15, .2)
	tr.buses['keys'] = reverb(tr.buses['keys'], .25, 1.8)
	tr.buses['lead'] = reverb(delay(tr.buses['lead'], tr.secs(1), .3, .25), .25, 2)
	x = mix(tr, {'drums': 0, 'bass': -1, 'keys': 0, 'lead': 0}, 'hub', vinyl(tr.n, .0025, 15))
	return tape(x, .0015, .45), tr


# ============================================================ 16. Ночная смена — neo-soul
def night_shift():
	bars, bpb = 12, 4
	tr = Track(68, bars * bpb, swing=.22, seed=1616)
	rng = tr.rng
	chords = [[56, 60, 63, 67, 70], [53, 56, 60, 63, 67], [49, 53, 56, 60, 63], [51, 55, 58, 61, 65]]
	roots = [32, 29, 25, 27]
	for bar in range(bars):
		b0 = bar * bpb
		c = bar % 4
		pattern(tr, 'drums', b0, 'X.......x.X.....', lambda v: kick('round', v), gain=.7, humanize=.006)
		for b in (1.06, 3.06):  # lazy, late backbeat
			tr.place('drums', b0 + b, snare('rim' if bar % 2 else 'crack', .7, rng), .38)
		pattern(tr, 'drums', b0, 'x.oox.o.x.oox.o.', lambda v: hat('closed', v, rng), gain=.16, humanize=.005)
		chord_hits(tr, 'keys', b0, chords[c], [(0, 1.8, .7), (2.5, 1.4, .5)], epiano, .09, .6)
		r = roots[c]
		tr.place('bass', b0, sub(r, tr.secs(1.6), .9, 1.4), .5)
		tr.place('bass', b0 + 2.5, sub(r + 12, tr.secs(1.2), .8, 1.4, glide_from=r + 7), .5)
		if bar % 2 == 1:
			phrase(tr, 'lead', b0, [(1, .5, 75), (1.5, .5, 77), (2, .25, 80), (2.25, 1.5, 79)] if bar < 6 else [(0, 1, 82), (1.5, .5, 80), (2, 2, 77)], piano, .09, -.2)
	tr.buses['keys'] = reverb(tr.buses['keys'], .25, 2)
	tr.buses['lead'] = reverb(tr.buses['lead'], .3, 2.2)
	x = mix(tr, {'drums': 0, 'keys': 1, 'bass': 0, 'lead': 0}, 'hub', vinyl(tr.n, .002, 16))
	return tape(x, .001, .35), tr


# ============================================================ 17. Прорыв — liquid drum & bass
def breakthrough():
	bars, bpb = 24, 4
	tr = Track(172, bars * bpb, seed=1717)
	rng = tr.rng
	chords = [[53, 56, 60, 63], [49, 53, 56, 60], [51, 55, 58, 62], [48, 51, 55, 58]]
	for bar in range(bars):
		b0 = bar * bpb
		c = (bar // 2) % 4
		pattern(tr, 'drums', b0, 'X.........X.....' if bar % 2 == 0 else 'X.........x.X...', lambda v: kick('tight', v), gain=.8)
		pattern(tr, 'drums', b0, '....X..g.g..X...' if bar % 4 != 3 else '....X..g.g..X.gx', lambda v: snare('crack', v, rng), gain=.45)
		pattern(tr, 'drums', b0, 'x.xox.xox.xox.xo', lambda v: hat('closed', v, rng), gain=.2)
		if bar % 2 == 0:
			tr.place('pad', b0, pad(chords[c], tr.secs(8), .9, 1300, .8, .008), .2)
			phrase(tr, 'bass', b0, [(0, 5, chords[c][0] - 24), (6, 1.5, chords[c][0] - 17)], lambda m, d, v: sub(m, d, v, 1.8), .5)
		if bar % 4 in (1, 3):
			phrase(tr, 'lead', b0, [(0, 1, 75), (1.5, .5, 72), (2, 2, 70)] if bar % 4 == 1 else [(0, .5, 72), (.5, .5, 75), (1, 3, 77)], piano, .1, .2)
	tr.buses['pad'] = duck(reverb(tr.buses['pad'], .35, 2.5), [b * 4 + o for b in range(bars) for o in (0, 2.5)], tr, .4)
	tr.buses['lead'] = reverb(delay(tr.buses['lead'], tr.secs(1.5), .3, .3), .35, 2.5)
	return mix(tr, {'drums': 0, 'pad': 0, 'bass': 0, 'lead': 0}, 'miniboss'), tr


# ============================================================ 18. Тиски — 6/8 taiko
def vice():
	bars = 32
	tr = Track(132, bars * 3, seed=1818)  # 6/8 bar = 3 quarter beats, eighth = .5
	rng = tr.rng
	chords = [[55, 58, 62], [51, 55, 58], [53, 57, 60], [50, 54, 57, 60]]
	for bar in range(bars):
		b0 = bar * 3
		c = (bar // 2) % 4
		pattern(tr, 'drums', b0, 'X..x..', lambda v: taiko(v), grid=.5, gain=.7)
		pattern(tr, 'drums', b0, '...X..' if bar % 4 != 3 else '...Xgx', lambda v: snare('crack', v, rng), grid=.5, gain=.35)
		pattern(tr, 'drums', b0, 'xoxoxo', lambda v: hat('closed', v, rng), grid=.5, gain=.18)
		if bar % 4 == 3:
			for k, m in enumerate([55, 52, 48]):
				tr.place('drums', b0 + 1.5 + k * .5, tom(m, .7), .3, (k - 1) * .4)
		tones = [m + 12 for m in chords[c]]
		for k in range(6):
			tr.place('arp', b0 + k * .5, square_lead(tones[[0, 1, 2, 1, 2, 1][k] % len(tones)], tr.secs(.3), .8, 0, 1400 + 150 * (bar % 4)), .05, .3 if k % 2 else -.3)
		phrase(tr, 'bass', b0, [(0, 1.4, chords[c][0] - 24), (1.5, 1.4, chords[c][0] - 17)], lambda m, d, v: sub(m, d, v, 2.2), .5)
		if bar % 2 == 0:
			tr.place('pad', b0, pad(chords[c], tr.secs(6), .8, 900, .6), .18)
	tr.buses['arp'] = delay(tr.buses['arp'], tr.secs(.75), .35, .3)
	tr.buses['drums'] = reverb(tr.buses['drums'], .15, 1.4, 3000)
	tr.buses['pad'] = reverb(tr.buses['pad'], .3, 2.5)
	return mix(tr, {'drums': -1, 'arp': 1, 'bass': -3, 'pad': 0}, 'miniboss'), tr


# ============================================================ 19. Жернова — industrial slow break
def millstones():
	bars, bpb = 16, 4
	tr = Track(90, bars * bpb, swing=.08, seed=1919)
	rng = tr.rng
	chords = [[49, 52, 56], [49, 52, 56, 59], [45, 49, 52], [47, 51, 54]]
	for bar in range(bars):
		b0 = bar * bpb
		c = bar % 4
		pattern(tr, 'drums', b0, 'X.....X.X.......' if bar % 2 == 0 else 'X.....X.....X...', lambda v: kick('deep', v), gain=1)
		pattern(tr, 'snare', b0, '....X.......X...', lambda v: snare('crack', v, rng), gain=.55)
		pattern(tr, 'perc', b0, '..x...x.x..x..x.' if bar % 2 else '..x.....x..x...x', lambda v: metal_perc(v, 310 + 40 * (bar % 3)), gain=.12, pan=.3)
		pattern(tr, 'drums', b0, 'x.x.x.x.x.x.x.x.', lambda v: hat('closed', v, rng), gain=.14)
		phrase(tr, 'bass', b0, [(0, .7, chords[c][0] - 24), (.75, .7, chords[c][0] - 24), (1.5, 1, chords[c][0] - 12), (3, .9, chords[c][0] - 23)], lambda m, d, v: sub(m, d, v, 4), .5)
		tr.place('pad', b0, pad(chords[c], tr.secs(4), .8, 600, .5, .015), .2)
		if bar >= 8 and bar % 2 == 0:
			phrase(tr, 'lead', b0, [(0, 2, 68), (2, .5, 69), (2.5, 1.5, 68)] if bar % 4 == 0 else [(0, 1.5, 73), (1.5, 2.5, 71)], lambda m, d, v: square_lead(m, d, v, .01, 1100), .05)
	tr.buses['snare'] = reverb(tr.buses['snare'], .45, 1.8, 2800)
	tr.buses['perc'] = delay(tr.buses['perc'], tr.secs(.75), .35, .3, lp=2500)
	tr.buses['pad'] = duck(reverb(tr.buses['pad'], .3, 2.5), [b * 4 + o for b in range(bars) for o in (0, 1.5, 2)], tr, .5)
	tr.buses['lead'] = reverb(tr.buses['lead'], .4, 3)
	return mix(tr, {'drums': 1, 'snare': 0, 'perc': 0, 'bass': 1, 'pad': 0, 'lead': 0}, 'boss'), tr


# ============================================================ 20. Цунами — big beat
def tsunami():
	bars, bpb = 16, 4
	tr = Track(120, bars * bpb, swing=.1, seed=2020)
	rng = tr.rng
	riff = [(0, .4, 40), (.75, .25, 43), (1, .4, 40), (1.75, .25, 45), (2.5, .5, 47), (3.25, .5, 45)]
	chords = [[52, 55, 59], [48, 52, 55], [50, 54, 57], [47, 50, 54]]
	for bar in range(bars):
		b0 = bar * bpb
		c = (bar // 2) % 4
		pattern(tr, 'drums', b0, 'X.X...X...X..X..' if bar % 2 == 0 else 'X.X.......X.X...', lambda v: kick('round', v), gain=.9)
		pattern(tr, 'drums', b0, '....X.......X...' if bar % 4 != 3 else '....X..X.X..XgXX', lambda v: snare('crack', v, rng), gain=.5)
		pattern(tr, 'drums', b0, 'x.X.x.X.x.X.x.X.', lambda v: hat('closed', v, rng), gain=.2)
		if bar % 4 == 0:
			tr.place('drums', b0, hat('open', .8, rng), .15)
		shift = chords[c][0] - 52
		for b, d, m in riff:
			tr.place('riff', b0 + b, pad([m + shift + 12, m + shift + 19], tr.secs(d), .9, 900 + 350 * (bar % 4), .004, .012), .35, 0)
		phrase(tr, 'bass', b0, [(b, d, m + shift - 12) for b, d, m in riff], lambda m, d, v: sub(m, d, v, 2.5), .45)
		if bar >= 8 and bar % 2 == 1:
			phrase(tr, 'lead', b0, [(0, .5, 76), (.5, .5, 79), (1, 1, 83), (2.5, 1.5, 81)], lambda m, d, v: square_lead(m, d, v, .006, 2200), .05)
	tr.buses['riff'] = reverb(tr.buses['riff'], .15, 1.2)
	tr.buses['lead'] = reverb(delay(tr.buses['lead'], tr.secs(.75), .35, .3), .3, 2)
	return mix(tr, {'drums': 0, 'riff': 0, 'bass': 0, 'lead': 0}, 'boss'), tr


TRACKS = {
	'break_azimuth': ('Азимут', 'battle', azimuth, 'лоуфай, бум-бэп со свингом'),
	'break_morse': ('Морзе', 'battle', morse, '5/4, щипковый арпеджиатор, маримба'),
	'break_dry_ice': ('Сухой лёд', 'battle', dry_ice, 'мягкий 2-step, органные стабы с эхом'),
	'break_kaleidoscope': ('Калейдоскоп', 'battle', kaleidoscope, 'полиритм 3 на 4, глитч-сбивки'),
	'break_dust_road': ('Пыльный тракт', 'map', dust_road, 'даб, one-drop, эхо на слабых долях'),
	'break_quartet': ('Квартет', 'hub', quartet, 'джаз-хоп в триолях, щётки и вибрафон'),
	'break_highway': ('Трасса', 'miniboss', highway, 'рубленый брейкбит, суб-бас, арпеджио'),
	'break_storm': ('Гроза', 'boss', storm, 'тёмный трип-хоп, глубокая бочка'),
	'break_square': ('Квадрат', 'battle', square_funk, 'фанк-брейк, клавинет, слэп-бас'),
	'break_mercury': ('Ртуть', 'battle', mercury, '7/8, маримба 2+2+3'),
	'break_nomad': ('Кочевник', 'battle', nomad, 'афро-брейк, конги, калимба'),
	'break_tailwind': ('Попутный ветер', 'map', tailwind, 'лоуфай-босса, гитара щипком'),
	'break_landmark': ('Ориентир', 'map', landmark, 'эмбиент-брейки, вибрафон'),
	'break_samovar': ('Самовар', 'hub', samovar, 'лоуфай-вальс 3/4, калимба'),
	'break_night_shift': ('Ночная смена', 'hub', night_shift, 'неосоул, ленивый бэкбит'),
	'break_breakthrough': ('Прорыв', 'miniboss', breakthrough, 'ликвид драм-н-бейс, пианино'),
	'break_vice': ('Тиски', 'miniboss', vice, '6/8, тайко, напряжённое арпеджио'),
	'break_millstones': ('Жернова', 'boss', millstones, 'индастриал, металлическая перкуссия'),
	'break_tsunami': ('Цунами', 'boss', tsunami, 'биг-бит, фильтрованный рифф'),
}

if __name__ == '__main__':
	DEMO.mkdir(parents=True, exist_ok=True)
	only = sys.argv[1:]
	report = {}
	reel = []
	for id, (title, context, fn, style) in TRACKS.items():
		if only and not any(o in id for o in only):
			continue
		x, tr = fn()
		x[-64:] += np.linspace(0, 1, 64)[:, None] * (x[0] - x[-1])
		info = save(OUT / (id + '.wav'), x)
		info.update(title=title, context=context, bpm=tr.bpm, style=style, seam=round(float(np.max(np.abs(x[0] - x[-1]))), 5))
		report[id] = info
		print(id, info)
		snippet = x[:R * 16].copy()
		k = np.arange(len(snippet))
		snippet *= np.minimum(1, np.minimum(k / (R * .05), (len(k) - 1 - k) / (R * .8)))[:, None]
		reel.extend([snippet * (.032 / max(np.sqrt(np.mean(snippet ** 2)), 1e-6)) * 2.2, np.zeros((R // 2, 2))])
	if reel:
		save(DEMO / ('preview.wav' if not only else 'preview_' + '_'.join(only) + '.wav'), np.concatenate(reel))
	if not only:
		catalog_path = OUT / 'chapter2_catalog.json'
		catalog = json.loads(catalog_path.read_text())
		for id, (title, context, *_rest) in TRACKS.items():
			catalog[id] = {'title': title, 'context': context}
		catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2))
		(DEMO / 'validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
