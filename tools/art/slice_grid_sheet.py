"""Slice a generated transparent icon sheet laid out as a grid into named PNGs.

Each opaque component is assigned to the grid cell containing its centre, so items
that slightly cross a cell border stay whole. Every item is cropped to its alpha
bounds, padded by --pad of the target side and centred on a transparent canvas.

Usage:
  python tools/art/slice_grid_sheet.py sheet.png --cols 4 --rows 2 --size 1024x512 \
      --out assets/.../weapons pistol shotgun smg rifle sniper rpg mg grenade_launcher
Names go row by row; "-" skips a cell. Requires Pillow and numpy.
"""
import argparse
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


def components(alpha, min_area):
	mask = alpha > 8
	# Downsampled labelling keeps 4K sheets fast; pixels are mapped back per block.
	step = 4
	small = mask[::step, ::step]
	seen = np.zeros(small.shape, dtype=bool)
	sh, sw = small.shape
	for y, x in zip(*np.nonzero(small)):
		if seen[y, x]:
			continue
		queue = deque([(int(y), int(x))])
		seen[y, x] = True
		cells = []
		while queue:
			cy, cx = queue.popleft()
			cells.append((cy, cx))
			for ny in range(cy - 1, cy + 2):
				for nx in range(cx - 1, cx + 2):
					if 0 <= ny < sh and 0 <= nx < sw and small[ny, nx] and not seen[ny, nx]:
						seen[ny, nx] = True
						queue.append((ny, nx))
		if len(cells) * step * step < min_area:
			continue
		ys, xs = np.array(cells).T
		yield ys * step, xs * step


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("sheet")
	parser.add_argument("names", nargs="+")
	parser.add_argument("--cols", type=int, required=True)
	parser.add_argument("--rows", type=int, required=True)
	parser.add_argument("--size", default="512x512")
	parser.add_argument("--pad", type=float, default=0.06)
	parser.add_argument("--min-area", type=int, default=400)
	parser.add_argument("--out", required=True)
	args = parser.parse_args()

	im = Image.open(args.sheet).convert("RGBA")
	rgba = np.array(im)
	h, w = rgba.shape[:2]
	cw, ch = w / args.cols, h / args.rows
	masks = [np.zeros((h, w), dtype=bool) for _ in range(args.cols * args.rows)]
	for ys, xs in components(rgba[:, :, 3], args.min_area):
		col = min(args.cols - 1, int(xs.mean() / cw))
		row = min(args.rows - 1, int(ys.mean() / ch))
		x0, x1 = xs.min(), xs.max() + 4
		y0, y1 = ys.min(), ys.max() + 4
		masks[row * args.cols + col][y0:y1, x0:x1] = True

	tw, th = (int(v) for v in args.size.split("x"))
	out = Path(args.out)
	out.mkdir(parents=True, exist_ok=True)
	for index, name in enumerate(args.names):
		if name == "-":
			continue
		cell = rgba.copy()
		cell[~masks[index]] = 0
		ys, xs = np.nonzero(cell[:, :, 3] > 8)
		if len(xs) == 0:
			print("empty cell", index, name)
			continue
		crop = Image.fromarray(cell[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
		pad_x, pad_y = tw * args.pad, th * args.pad
		scale = min((tw - 2 * pad_x) / crop.width, (th - 2 * pad_y) / crop.height)
		crop = crop.resize((max(1, round(crop.width * scale)), max(1, round(crop.height * scale))), Image.LANCZOS)
		canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
		canvas.alpha_composite(crop, ((tw - crop.width) // 2, (th - crop.height) // 2))
		canvas.save(out / f"{name}.png")
		print(out / f"{name}.png")


if __name__ == "__main__":
	main()
