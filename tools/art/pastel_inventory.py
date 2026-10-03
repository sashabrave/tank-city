"""Pastel accents for the inventory series (author, 3 Oct): rarity chevrons take LootCatalog.RARITY_COLORS, ammo
box stripes take a softened Ammo.COLORS. Shading (value) is kept, only hue and saturation change.
Run after cutting the sheets:  python tools/art/pastel_inventory.py  (Pillow, numpy)."""
import colorsys, re
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SYM = ROOT / "assets/ui/icon_kit/symbols"
SRC = ROOT / "art_requests/inventory_side_v1/cut"   # untouched cuts, so the script can run again
RARITY = re.search(r'RARITY_COLORS=\[(.*?)\]', (ROOT / "scripts/loot_catalog.gd").read_text()).group(1).replace('"', '').split(",")
AMMO = dict(re.findall(r'"([a-z]+)":"([0-9a-f]{6})"', re.search(r'const COLORS=\{(.*?)\}', (ROOT / "scripts/combat/ammo.gd").read_text()).group(1)))
CREAM = np.array([.93, .91, .87])

def rgb(h): return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])
def pastel(c, k=.38): return c * (1 - k) + CREAM * k

def to_hsv(a):
    flat = a[..., :3].reshape(-1, 3) / 255
    return np.array([colorsys.rgb_to_hsv(*p) for p in flat]).reshape(a.shape[0], a.shape[1], 3)

def paint(a, mask, target, keep_value=True):
    th, ts, tv = colorsys.rgb_to_hsv(*target)
    hsv = to_hsv(a)
    ys, xs = np.nonzero(mask)
    for y, x in zip(ys, xs):
        v = hsv[y, x, 2] / max(.01, np.percentile(hsv[mask][:, 2], 90)) * tv if keep_value else tv
        r, g, b = colorsys.hsv_to_rgb(th, ts, min(1.0, v))
        a[y, x, :3] = (r * 255, g * 255, b * 255)
    return a

def source(name):
    SRC.mkdir(parents=True, exist_ok=True)
    keep = SRC / name
    if not keep.exists(): Image.open(SYM / name).save(keep)
    return np.array(Image.open(keep).convert("RGBA")).astype(float)

def ranks():
    for i, hexc in enumerate(RARITY):
        a = source(f"rank_{i}.png"); h, w = a.shape[:2]
        hsv = to_hsv(a)
        yy, xx = np.mgrid[0:h, 0:w]
        ys, xs = np.nonzero(a[..., 3] > 30); cy, cx = ys.mean(), xs.mean(); rad = max(np.ptp(ys), np.ptp(xs)) / 2
        r = np.hypot(yy - cy, xx - cx) / rad
        inner = (a[..., 3] > 30) & (r < .74)
        frame = (a[..., 3] > 30) & ~inner
        target = rgb(hexc)
        a = paint(a, inner & (hsv[..., 1] > .12), target)
        a = paint(a, inner & (hsv[..., 1] <= .12), pastel(target * .55, .1))      # grey field of the common patch
        a = paint(a, frame & (hsv[..., 1] > .2), pastel(rgb("eccf8c"), .15))      # soft gold frame for all
        Image.fromarray(np.clip(a, 0, 255).astype("uint8")).save(SYM / f"rank_{i}.png", optimize=True)

def ammo():
    for kind, hexc in AMMO.items():
        name = f"ammo_{kind}.png"
        if not (SYM / name).exists(): continue
        a = source(name); h, w = a.shape[:2]
        hsv = to_hsv(a)
        xx = np.mgrid[0:h, 0:w][1]
        stripe = (a[..., 3] > 30) & (xx > w * .56) & (hsv[..., 1] > .5) & (hsv[..., 2] > .3)
        if stripe.sum() < 30: continue
        a = paint(a, stripe, pastel(rgb(hexc)))
        Image.fromarray(np.clip(a, 0, 255).astype("uint8")).save(SYM / name, optimize=True)

if __name__ == "__main__":
    ranks(); ammo(); print("pastel ok", RARITY, len(AMMO))
