"""Remove coloured halos (red/green fringe) from GPT transparent renders.

Semi-transparent edge pixels keep garbage RGB from the generator's matte. Their colour is replaced by the
colour of the nearest solid pixel (iterative dilation), alpha is kept, so edges stay soft but clean.
Usage: uv run --with pillow --with numpy python tools/art/defringe.py file1.png [file2.png ...]
"""
import sys
import numpy as np
from PIL import Image

def defringe(path, solid=230, steps=12):
	im = np.array(Image.open(path).convert("RGBA")).astype(np.float32)
	rgb, a = im[..., :3], im[..., 3]
	known = a >= solid
	color = np.where(known[..., None], rgb, 0.0)
	weight = known.astype(np.float32)
	for _ in range(steps):
		acc = np.zeros_like(color); wsum = np.zeros_like(weight)
		for dy in (-1, 0, 1):
			for dx in (-1, 0, 1):
				acc += np.roll(np.roll(color * weight[..., None], dy, 0), dx, 1)
				wsum += np.roll(np.roll(weight, dy, 0), dx, 1)
		grow = (~known) & (wsum > 0)
		color[grow] = acc[grow] / wsum[grow][..., None]
		weight = np.where(grow, 1.0, weight); known = known | grow
	edge = (a > 0) & (a < solid)
	rgb[edge] = color[edge]
	# Very faint pixels were pure matte noise: drop them.
	a[a < 18] = 0
	out = np.dstack([rgb, a]).clip(0, 255).astype(np.uint8)
	Image.fromarray(out, "RGBA").save(path)

for p in sys.argv[1:]:
	defringe(p); print("defringed", p)
