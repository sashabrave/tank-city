"""Hero cat v8: measure the GPT Image 2.5 blueprint (front / side / back / top) into metres.

Run:  Blender -b --factory-startup --python tools/hero_v8_refs.py
Input:  art_requests/hero_cat_v8/1_blueprint.png (four orthographic views in one row)
Output: art_requests/hero_cat_v8/blueprint.json
  views.<front|side|back|top>.rows[i] = {"z": metres, "all": [lo, hi], "olive": [...], "fur": [...], "black": [...]}
  Front/back: lo..hi is X (character's right = +X in v6 space when seen from the front).
  Side (cat faces image-left = +Y forward): lo..hi is Y. Top: rows run along Y, spans along X.
Scale: the front view's full height (ear tips to soles) is HEIGHT metres; all views share that scale.
The Blender builder (tools/build_hero_v8.py) lofts parts from these spans and checks its silhouettes against them.
"""
import bpy, json, os
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join(ROOT, "art_requests/hero_cat_v8/1_blueprint.png")
OUT = os.path.join(ROOT, "art_requests/hero_cat_v8/blueprint.json")
HEIGHT = 1.1
STEP = .01

im = bpy.data.images.load(SHEET); W, H = im.size
a = np.empty(W * H * 4, dtype=np.float32); im.pixels.foreach_get(a)
rgb = a.reshape(H, W, 4)[::-1, :, :3]                      # row 0 = top of the image
bg = np.median(rgb[:, :40].reshape(-1, 3), axis=0)
fg = np.abs(rgb - bg).sum(axis=2) > .16
# Grid lines run across the whole sheet: drop those rows, then refill figure pixels from the rows around them.
edge = np.concatenate([fg[:, 40:62], fg[:, -62:-40]], axis=1)
lines = np.where(edge.mean(axis=1) > .5)[0]          # grid lines show in the empty side margins
for y in lines:
    lo, hi = max(0, y - 3), min(H - 1, y + 3)
    while lo in lines and lo > 0: lo -= 1
    while hi in lines and hi < H - 1: hi += 1
    fg[y] = fg[lo] & fg[hi]
vlines = np.where(np.concatenate([fg[2:28], fg[-28:-2]]).mean(axis=0) > .5)[0]
for x in vlines:
    fg[:, x] = fg[:, max(0, x - 3)] & fg[:, min(W - 1, x + 3)]
mx, mn = rgb.max(axis=2), rgb.min(axis=2)
sat = (mx - mn) / np.maximum(mx, 1e-4)
r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
classes = {
    "olive": fg & (g >= r * .95) & (g > b) & (sat > .12) & (mx > .2),
    "fur": fg & (r > g * 1.15) & (g > b) & (sat > .35),
    "black": fg & (mx < .24),
}

# Split the row into views at wide empty column gaps.
cols = fg.any(axis=0)
spans, start = [], None
for x, on in enumerate(np.append(cols, False)):
    if on and start is None: start = x
    if not on and start is not None:
        if spans and x - spans[-1][1] < 30 and start - spans[-1][1] < 30: spans[-1] = (spans[-1][0], x)
        else: spans.append((start, x))
        start = None
spans = [s for s in spans if s[1] - s[0] > 120]
assert len(spans) == 4, spans
names = ["front", "side", "back", "top"]

def extent(mask_cols):
    xs = np.where(mask_cols)[0]
    return [int(xs.min()), int(xs.max())] if len(xs) else None

front_rows = np.where(fg[:, spans[0][0]:spans[0][1]].any(axis=1))[0]
top_px, bot_px = int(front_rows.min()), int(front_rows.max())
scale = HEIGHT / (bot_px - top_px)                          # metres per pixel

out = {"height": HEIGHT, "metres_per_px": scale, "views": {}}
for name, (x0, x1) in zip(names, spans):
    sub = {k: m[:, x0:x1] for k, m in list(classes.items()) + [("all", fg)]}
    rows_px = np.where(sub["all"].any(axis=1))[0]
    v = {"px": [int(x0), int(x1), int(rows_px.min()), int(rows_px.max())], "rows": []}
    if name == "top":
        # centre on the helmet: the top view's y axis is the character's forward axis (front = image bottom)
        cy = (rows_px.min() + rows_px.max()) / 2
    full = sub["all"]
    xs_all = np.where(full.any(axis=0))[0]
    cx = (xs_all.min() + xs_all.max()) / 2 if name in ("front", "back", "top") else None
    if name == "side":
        # side: centre on the boots/legs column (body axis), not on the tail
        legs = sub["all"][bot_px - int(.12 / scale):bot_px]
        lx = np.where(legs.any(axis=0))[0]; cx = (lx.min() + lx.max()) / 2
    for z in np.arange(0, HEIGHT + 1e-6, STEP):
        if name == "top":
            row = int(round(cy + (z - HEIGHT / 2) / scale))     # here "z" is Y from back (-) to front (+), offset by H/2
        else:
            row = int(round(bot_px - z / scale))
        if row < 0 or row >= H: continue
        entry = {"z": round(float(z if name != "top" else z - HEIGHT / 2), 3)}
        for k, m in sub.items():
            e = extent(m[row])
            if e:
                lo, hi = (e[0] - cx) * scale, (e[1] - cx) * scale
                if name == "side": lo, hi = -hi, -lo                # image-left is +Y (forward)
                if name == "back": lo, hi = -hi, -lo                # mirror back view into front X
                entry[k] = [round(float(lo), 4), round(float(hi), 4)]
        if len(entry) > 1: v["rows"].append(entry)
    out["views"][name] = v
json.dump(out, open(OUT, "w"), indent=0)
f = {r["z"]: r for r in out["views"]["front"]["rows"]}; s = {r["z"]: r for r in out["views"]["side"]["rows"]}
for z in (1.05, .95, .85, .75, .65, .6, .55, .5, .45, .4, .35, .3, .25, .2, .15, .1, .05, .02):
    fr, sr = f.get(round(z, 3), {}), s.get(round(z, 3), {})
    print("Z %.2f  front %-16s side %-16s  olive %-16s fur %-16s black %s" % (z, fr.get("all"), sr.get("all"), fr.get("olive"), fr.get("fur"), fr.get("black")))
print("SAVED", OUT, "scale", round(scale * 1000, 3), "mm/px")
