"""Write assets/audio/music/durations.json (seconds per track id) from the OGG files.

Run after regenerating music (needs the soundfile package). The radio reads it
instead of loading every track.
"""
from pathlib import Path
import json
import soundfile as sf

MUSIC = Path(__file__).resolve().parents[2] / 'assets/audio/music'
durations = {}
for path in sorted(MUSIC.glob('*.ogg')):
	info = sf.info(str(path))
	durations[path.stem] = round(info.frames / info.samplerate, 3)
(MUSIC / 'durations.json').write_text(json.dumps(durations, indent=1))
print(len(durations), 'durations')
