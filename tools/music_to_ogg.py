# -*- coding: utf-8 -*-
"""Music to OGG Vorbis (T-070): every WAV in assets/audio/music becomes an .ogg next to it (quality 5, ~160 kbps),
and the WAV source moves to assets_src/music_wav (ignored by Godot, kept in git). Run again after generating
new music with the build_music_*.py tools.
uv run --with imageio-ffmpeg python tools/music_to_ogg.py"""
import os, shutil, subprocess, concurrent.futures
import imageio_ffmpeg
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC = os.path.join(ROOT, "assets", "audio", "music"); SRC = os.path.join(ROOT, "assets_src", "music_wav")
os.makedirs(SRC, exist_ok=True)
open(os.path.join(ROOT, "assets_src", ".gdignore"), "a").close()
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
def convert(name):
    wav = os.path.join(MUSIC, name); ogg = wav[:-4] + ".ogg"
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
    shutil.move(wav, os.path.join(SRC, name))
    imp = wav + ".import"
    if os.path.exists(imp): os.remove(imp)
    return name
names = sorted(n for n in os.listdir(MUSIC) if n.endswith(".wav"))
with concurrent.futures.ThreadPoolExecutor(6) as pool:
    for i, n in enumerate(pool.map(convert, names), 1):
        if i % 40 == 0: print(i, "/", len(names), flush=True)
print("done", len(names))
