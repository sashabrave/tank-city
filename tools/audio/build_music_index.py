"""Write assets/audio/music/durations.json (seconds per track id) from WAV headers.

Run after regenerating music. The radio reads it instead of loading every WAV.
"""
from pathlib import Path
import json, wave

MUSIC = Path(__file__).resolve().parents[2] / 'assets/audio/music'
durations = {}
for path in sorted(MUSIC.glob('*.wav')):
	with wave.open(str(path)) as w:
		durations[path.stem] = round(w.getnframes() / w.getframerate(), 3)
(MUSIC / 'durations.json').write_text(json.dumps(durations, indent=1))
print(len(durations), 'durations')
