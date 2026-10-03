"""Builds the static icon symbols (guides/03_release/07_icon_kit_brief.md) from the GPT sheets.

Sheets live in art_requests/icon_kit_v1/sheets (stored at 3/4 of 4K), results in assets/ui/icon_kit/symbols:
one drawn object per icon on a 384 canvas, no plates or frames. data/icon_kit.json maps icon ids to symbols.
Requires Pillow and numpy:  python tools/art/build_icon_kit.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SHEETS = ROOT / "art_requests/icon_kit_v1/sheets"
OUT = ROOT / "assets/ui/icon_kit"
CANVAS = 384
# Author decisions after play (brief, «Решения автора после игры»): gold alloy bars and the silver paw
# token replace the generated symbols; a rebuild keeps those files.
AUTHOR_KEPT = {"alloy", "token", "bullet_vs_rocket"}  # bullet_vs_rocket: T-123 redraw


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


def single(im, fit=.92):
	b = bbox(im)
	w, h = b[2] - b[0], b[3] - b[1]
	s = CANVAS * fit / max(w, h)
	return place(im, b, (w * s, h * s), (CANVAS / 2, CANVAS / 2))


def save(im, rel):
	path = OUT / rel
	path.parent.mkdir(parents=True, exist_ok=True)
	im.save(path, optimize=True)


def main():
	symbols = {
		("symbols_1_v1.png", 5, 4): "burst bullet_burst bullets_fast crosshair bullet_shatter pierce flame flame_chain bolt dizzy bell heart_cage boot_dodge vest bomb tank_shell boot_wind hood clover_casing grenade_up",
		("symbols_2_v1.png", 5, 4): "magazine_fast scope_star steering_bullet bullet_vs_rocket gyro hourglass_bullet torn_flag bolt_arc plug_spark medkit sandbags trajectory ghost_dash parachute door_dash loot_sack safe wrench_spark grapple grenade_clock",
		("symbols_3_v1.png", 5, 4): "airstrike ally_drone barrier hood_fade comrade dynamite gas grenade laser mine riot_shield snowflake star turret jeep wheel_wrench bricks - alloy blueprint",
		("symbols_4_v1.png", 5, 4): "medbay plating robot_arm supply interceptor tesla pulse dome emp_dish armor_plate cannon ammo_belt documents recipe trophy stopwatch crossed_rifles invulnerable trench token",
		("symbols_5_v1.png", 4, 3): "st_character st_command st_garage st_headquarters st_mechanic st_merchant st_range st_recycling st_roadmap st_wardrobe st_weapons st_yard",
		("symbols_6_v1.png", 3, 3): "thermometer_flame torch helmet_stars flashbang mallet_stars battery_bolt bomb_suit shell_bounce crew_hatch",
		# v2, shiny metal with soft bevels (later sheets override earlier symbols of the same name).
		("abilities_v2.png", 4, 3): "airstrike ally_drone barrier hood_fade comrade dynamite gas grenade laser mine riot_shield wrench_spark",
		("upgrades_a_v2.png", 5, 3): "burst bullet_burst bullets_fast magazine_fast crosshair bullet_shatter scope_star bullet_vs_rocket gyro hourglass_bullet pierce torn_flag bell crew_hatch grapple",
		("upgrades_b_v2.png", 5, 3): "flame thermometer_flame torch flame_chain bolt battery_bolt bolt_arc plug_spark dizzy helmet_stars flashbang mallet_stars heart_cage medkit bomb_suit",
		("upgrades_c_v2.png", 5, 3): "vest shell_bounce sandbags boot_dodge boot_wind trajectory hood ghost_dash parachute door_dash clover_casing loot_sack safe grenade_clock grenade_up",
		("hq_garage_v2.png", 4, 3): "medbay plating robot_arm supply interceptor tesla pulse dome emp_dish armor_plate cannon ammo_belt",
		("bonus_resources_v2.png", 4, 3): "snowflake star turret jeep wheel_wrench bricks - blueprint documents recipe trophy padlock",
		("stations_v2.png", 4, 3): "st_character st_command st_garage st_headquarters st_mechanic st_merchant st_range st_recycling st_roadmap st_wardrobe st_weapons st_yard",
		("categories_v2.png", 3, 3): "cat_hero cat_ability cat_hq cat_bonus cat_weapon sender_story sender_institute sender_operations weapon_tune",
		("ammo_v2.png", 4, 2): "ammo_standard ammo_burn ammo_stun ammo_shock ammo_explosive ammo_ap ammo_ricochet ammo_cryo",
		("blueprints_v2.png", 3, 2): "bp_weapon bp_vehicle bp_hq bp_ability bp_bonus bp_building",
		("ammo_charges_v2.png", 2, 1): "ammo_cluster ammo_napalm",
		# HQ is the mobile command truck (author, 2 Oct): these replace the tent and bunker pictures.
		("hq_vehicle_v3.png", 3, 2): "cat_hq st_headquarters hq_repair medbay - -",
		("bp_hq_v2.png", 1, 1): "bp_hq",
		("vehicles_v2.png", 3, 2): "veh_buggy veh_apc veh_tank - - -",
	}
	for (sheet, cols, rows), names in symbols.items():
		grid = cells(sheet, cols, rows)
		for i, name in enumerate(names.split()):
			if name == "-":
				continue
			if name in AUTHOR_KEPT and (OUT / f"symbols/{name}.png").exists():
				continue
			save(single(grid[(i // cols, i % cols)]), f"symbols/{name}.png")
	print("icon kit:", sum(1 for _ in OUT.rglob("*.png")), "png")


if __name__ == "__main__":
	main()
