"""Builds the layered icon kit (guides/03_release/07_icon_kit_brief.md) from the GPT sheets.

Sheets live in art_requests/icon_kit_v1/sheets, results in assets/ui/icon_kit:
  kit/<group>_face[_<variant>].png, kit/<group>_rim[_<variant>].png, kit/<name>.png (auras)
  symbols/<symbol>.png, badges/<badge>.png
Every kit layer is a 384 canvas (cards show icons at up to 148 px). A face is fitted to the outer bounds of its rim (93%), so the rim
always hides the face edge and the face has room to slide under the rim during parallax.
Requires Pillow and numpy:  python tools/art/build_icon_kit.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SHEETS = ROOT / "art_requests/icon_kit_v1/sheets"
LAYERS = ROOT / "art_requests/icon_kit_v1/layers"
OUT = ROOT / "assets/ui/icon_kit"
CANVAS = 384
FAMILY = {"fire": (205, 72, 58), "ammo": (214, 152, 50), "survival": (92, 135, 62), "recon": (40, 132, 140), "logistics": (176, 146, 104)}


def cells(sheet, cols, rows):
	im = Image.open(SHEETS / sheet).convert("RGBA")
	w, h = im.size
	return {(r, c): clean(im.crop((c * w // cols, r * h // rows, (c + 1) * w // cols, (r + 1) * h // rows))) for r in range(rows) for c in range(cols)}


def clean(cell):
	"""Drops bits of neighbouring items that leak into a cell: small blobs touching the cell edge."""
	a = np.array(cell)
	step = 4
	mask = a[::step, ::step, 3] > 24
	h, w = mask.shape
	labels = np.zeros(mask.shape, dtype=int)
	blobs = []
	for y, x in zip(*np.nonzero(mask)):
		if labels[y, x]:
			continue
		n = len(blobs) + 1
		stack = [(y, x)]
		labels[y, x] = n
		area, edge = 0, False
		while stack:
			cy, cx = stack.pop()
			area += 1
			edge = edge or cy in (0, h - 1) or cx in (0, w - 1)
			for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
				if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not labels[ny, nx]:
					labels[ny, nx] = n
					stack.append((ny, nx))
		blobs.append((area, edge))
	if not blobs:
		return cell
	biggest = max(area for area, _ in blobs)
	drop = [i + 1 for i, (area, edge) in enumerate(blobs) if edge and area < biggest * .25]
	if drop:
		small = np.isin(labels, drop)
		grown = small.copy()
		grown[1:] |= small[:-1]; grown[:-1] |= small[1:]; grown[:, 1:] |= small[:, :-1]; grown[:, :-1] |= small[:, 1:]
		gone = grown.repeat(step, 0).repeat(step, 1)[:a.shape[0], :a.shape[1]]
		a[gone] = 0
	return Image.fromarray(a)


def bbox(im):
	return im.getchannel("A").point(lambda v: 255 if v > 128 else 0).getbbox()


def place(im, box, size, centre):
	crop = im.crop(box).resize((max(1, round(size[0])), max(1, round(size[1]))), Image.LANCZOS)
	canvas = Image.new("RGBA", (CANVAS, CANVAS))
	canvas.alpha_composite(crop, (round(centre[0] - crop.width / 2), round(centre[1] - crop.height / 2)))
	return canvas


def pair(face, rim, fill=.93):
	"""Returns (face, rim) on 512 canvases: the rim fills 92% of the canvas, the face 93% of the rim."""
	rb = bbox(rim)
	rw, rh = rb[2] - rb[0], rb[3] - rb[1]
	scale = CANVAS * .92 / max(rw, rh)
	centre = (CANVAS / 2, CANVAS / 2)
	rim_out = place(rim, rb, (rw * scale, rh * scale), centre)
	face_out = None
	if face is not None:
		fb = bbox(face)
		face_out = place(face, fb, (rw * scale * fill, rh * scale * fill), centre)
	return face_out, rim_out


def single(im, fit=.92):
	b = bbox(im)
	w, h = b[2] - b[0], b[3] - b[1]
	s = CANVAS * fit / max(w, h)
	return place(im, b, (w * s, h * s), (CANVAS / 2, CANVAS / 2))


def tint(face, rgb):
	"""Recolours an enamel face keeping its shading: luminance relative to the median times the colour."""
	a = np.array(face).astype(float)
	lum = a[..., :3] @ np.array([.3, .59, .11])
	mid = np.median(lum[a[..., 3] > 200])
	k = np.clip(lum / max(mid, 1), 0, 1.6)[..., None]
	a[..., :3] = np.clip(np.array(rgb)[None, None, :] * k, 0, 255)
	return Image.fromarray(a.astype("uint8"))


def save(im, rel):
	path = OUT / rel
	path.parent.mkdir(parents=True, exist_ok=True)
	im.save(path, optimize=True)


def main():
	a = cells("kit_bases_a_v1.png", 4, 4)
	b = cells("kit_bases_b_v1.png", 4, 3)
	for group, face, rim in [("ability", (0, 0), (0, 1)), ("hq", (0, 2), (0, 3)), ("garage", (1, 0), (1, 1)), ("station", (1, 2), (1, 3))]:
		f, r = pair(a[face], a[rim])
		save(f, f"kit/{group}_face.png")
		save(r, f"kit/{group}_rim.png")
	f, r = pair(a[(2, 0)], a[(2, 1)])
	save(f, "kit/status_face.png")
	save(r, "kit/status_rim_good.png")
	save(pair(None, a[(2, 2)])[1], "kit/status_rim_bad.png")
	# Dog tag: the khaki face is the only one shaped like the rim; the family faces are recoloured from it.
	f, r = pair(b[(0, 0)], a[(2, 3)])
	save(r, "kit/stat_rim.png")
	for family, rgb in FAMILY.items():
		save(tint(f, rgb), f"kit/stat_face_{family}.png")
	_, r = pair(None, b[(0, 3)])
	save(r, "kit/pickup_rim.png")
	for variant, cell in {"red": (1, 0), "orange": (1, 1), "blue": (1, 2), "olive": (1, 3), "ice": (2, 0), "teal": (2, 1)}.items():
		f, _ = pair(b[cell], b[(0, 3)], 1.0)
		save(f, f"kit/pickup_face_{variant}.png")
	save(single(b[(2, 2)], .98), "kit/aura_rays.png")
	save(single(b[(2, 3)], .98), "kit/aura_ring.png")
	# Run upgrades: the approved pilot layers (faces cut from the pilot sheet, rim cut from the same shields).
	for family in FAMILY:
		save(Image.open(LAYERS / f"kit/upgrade_back_{family}.png").resize((CANVAS, CANVAS), Image.LANCZOS), f"kit/upgrade_face_{family}.png")
		save(Image.open(LAYERS / f"kit/upgrade_rim_{family}.png").resize((CANVAS, CANVAS), Image.LANCZOS), f"kit/upgrade_rim_{family}.png")

	symbols = {
		("symbols_1_v1.png", 5, 4): "burst bullet_burst bullets_fast crosshair bullet_shatter pierce flame flame_chain bolt dizzy bell heart_cage boot_dodge vest bomb tank_shell boot_wind hood clover_casing grenade_up",
		("symbols_2_v1.png", 5, 4): "magazine_fast scope_star steering_bullet bullet_vs_rocket gyro hourglass_bullet torn_flag bolt_arc plug_spark medkit sandbags trajectory ghost_dash parachute door_dash loot_sack safe wrench_spark grapple grenade_clock",
		("symbols_3_v1.png", 5, 4): "airstrike ally_drone barrier hood_fade comrade dynamite gas grenade laser mine riot_shield snowflake star turret jeep wheel_wrench bricks bunker_wrench alloy blueprint",
		("symbols_4_v1.png", 5, 4): "medbay plating robot_arm supply interceptor tesla pulse dome emp_dish armor_plate cannon ammo_belt documents recipe trophy stopwatch crossed_rifles invulnerable trench token",
		("symbols_5_v1.png", 4, 3): "st_character st_command st_garage st_headquarters st_mechanic st_merchant st_range st_recycling st_roadmap st_wardrobe st_weapons st_yard",
	}
	for (sheet, cols, rows), names in symbols.items():
		grid = cells(sheet, cols, rows)
		for i, name in enumerate(names.split()):
			save(single(grid[(i // cols, i % cols)]), f"symbols/{name}.png")
	badges = cells("badges_v1.png", 4, 3)
	for i, name in enumerate("up longer often plus shield buggy apc tank bullet bomb tank_shell cooldown".split()):
		save(single(badges[(i // 4, i % 4)], .96)
			.resize((192, 192), Image.LANCZOS), f"badges/{name}.png")
	print("icon kit:", sum(1 for _ in OUT.rglob("*.png")), "png")


if __name__ == "__main__":
	main()
